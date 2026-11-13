unit AudCfg;

{ Native Win16 configuration window used by DRV_CONFIGURE.
  GUI code is task-only; no VCL/DFM, extra DLL or multimedia timer. }
{$F+}
{$W+}
{$R-}
{$Q-}

interface
uses WinTypes, WinProcs, Messages, AudEQ, AudRev;

const
  AudDriverVersion=$0200;
  AudDriverVersionText='2.0';
  SynthNone=0; SynthOPL3=1; SynthSoundFont=2;
  SFMinVoices=32; SFDefaultVoices=64; SFMaxVoices=128;
  SFDefaultHeadroomDB=3; SFMaxHeadroomDB=24;
  DefaultSoundFont='4GMGSMT.SF2';
  MidiRateDefault=44100; MidiRateNative=48000;

type
  TAudSettings=record
    PhysicalBase: LongInt;
    CardIndex, HalfMS, SliceMS, TimerMS, ResolutionMS: Word;
    GainSteps: Word; { 0..48 quarter dB; requires Windows restart }
    MidiSynth, MidiRate, SoundFontVoices, SoundFontHeadroomDB, Playback2Aux: Word;
    SoundFont: string;
    Source, InputLevel, SourceLevel, Fader1, Fader2, DebugMode, ShutdownMode: Word;
    MonitorOn, MonitorVolume, MonitorSource: Word;
    BassOn, BassHz: Word;
    EQ: TEqSettings;
    Rev: TRevSettings;
  end;
  TAudSubmit=function(const Settings: TAudSettings): Word;
  TAudPoll=function(var Active,Saved: TAudSettings): Word;
  TAudCancel=function: Boolean;

function AudSettingsValid(const C: TAudSettings): Boolean;
function AudGainParse(const Value: string; var Steps: Word): Boolean;
function AudGainText(Steps: Word): string;
function AudMonitorPercent(V: Word): Word;
function AudMonitorValue(Percent: Word): Word;
function AudRestartNeeded(const A,B: TAudSettings): Boolean;
function AudSettingsEqual(const A,B: TAudSettings): Boolean;
function AudSourceName(Source: Word): string;
function AudSourceNumber(const Name: string; var Source: Word): Boolean;
function AudConfigure(Owner: HWnd; const Active,Saved: TAudSettings;
                      Submit: TAudSubmit; Poll: TAudPoll;
                      Cancel: TAudCancel): Boolean;

implementation
uses SysUtils, MMSystem, EqUI, RevUI, Aud2HW;

const
  ConfigClass='Audigy2Config';
  ConfigWidth=620; ConfigHeight=448;
  IDApply=3;
  IDSource=101; IDLevel=102; IDSourceLevel=103; IDRear=104;
  IDDebug=105; IDShutdown=106;
  IDMonitor=107; IDMonitorLevel=108;
  IDEqualizer=109;
  IDReverb=110;
  IDFader2=111;
  IDBass=112; IDBassHz=113;
  IDPhysical=201; IDCard=202; IDHalf=203; IDSlice=204;
  IDTimer=205; IDResolution=206;
  IDGain=208;
  IDMidiSettings=207;

var
  ConfigWindow, SourceBox, LevelEdit, SourceEdit, FaderEdit1,FaderEdit2: HWnd;
  DebugBox, ShutdownBox, PhysicalEdit, CardEdit: HWnd;
  HalfEdit, SliceEdit, TimerEdit, ResolutionEdit: HWnd;
  GainEdit: HWnd;
  MidiSettingsButton: HWnd;
  OKButton, CancelButton, ApplyButton: HWnd;
  MonitorBox, MonitorEdit: HWnd;
  EqualizerButton: HWnd;
  ReverbButton: HWnd;
  BassBox, BassSlider, BassLabel: HWnd;
  EqDraft: TEqSettings;
  RevDraft: TRevSettings;
  InitialActive, LastSaved, Draft, MidiDraft: TAudSettings;
  SubmitRequest: TAudSubmit;
  PollRequest: TAudPoll;
  CancelRequest: TAudCancel;
  Loading, Waiting, CloseAfterApply, ControlsOK: Boolean;
  MonitorEdited: Boolean;
  RequestTick: LongInt;
  LastApplyStatus: Word;

function AudSettingsValid(const C: TAudSettings): Boolean;
begin
  Result := (C.PhysicalBase>=$100000) and
    (C.PhysicalBase<=$7FFFFFFF-$40000) and ((C.PhysicalBase and $FFF)=0) and
    (C.CardIndex<=255) and (C.HalfMS>=10) and (C.HalfMS<=60) and
    (C.SliceMS>=5) and (C.SliceMS<=30) and
    (C.TimerMS>=1) and (C.TimerMS<=20) and
    (C.ResolutionMS>=1) and (C.ResolutionMS<=10) and
    (C.GainSteps<=48) and
    (C.MidiSynth<=SynthSoundFont) and (C.Playback2Aux<=1) and
    ((C.MidiRate=MidiRateDefault) or (C.MidiRate=MidiRateNative)) and
    (C.SoundFontVoices>=SFMinVoices) and (C.SoundFontVoices<=SFMaxVoices) and
    (C.SoundFont<>'') and (C.SoundFontHeadroomDB<=SFMaxHeadroomDB) and
    (C.Source<=6) and (C.InputLevel<=100) and (C.SourceLevel<=100) and
    (C.Fader1<=100) and (C.Fader2<=100) and
    (C.DebugMode<=1) and (C.ShutdownMode<=1) and
    (C.MonitorOn<=1) and (C.MonitorSource<=5) and
    (C.BassOn<=1) and (C.BassHz>=AudBassMinHz) and (C.BassHz<=AudBassMaxHz) and
    (C.BassHz mod AudBassStepHz=0) and EqValid(C.EQ) and RevValid(C.Rev);
end;

function AudMonitorPercent(V: Word): Word;
begin
  Result := Word((LongInt(V)*100+32767) div 65535);
end;

function AudMonitorValue(Percent: Word): Word;
begin
  Result := Word((LongInt(Percent)*65535+50) div 100);
end;

function AudRestartNeeded(const A,B: TAudSettings): Boolean;
begin
  Result := (A.PhysicalBase<>B.PhysicalBase) or (A.CardIndex<>B.CardIndex) or
    (A.HalfMS<>B.HalfMS) or (A.SliceMS<>B.SliceMS) or
    (A.TimerMS<>B.TimerMS) or (A.ResolutionMS<>B.ResolutionMS) or
    (A.GainSteps<>B.GainSteps) or
    (A.MidiSynth<>B.MidiSynth) or (A.Playback2Aux<>B.Playback2Aux) or
    (A.MidiRate<>B.MidiRate) or
    (A.SoundFont<>B.SoundFont) or (A.SoundFontVoices<>B.SoundFontVoices) or
    (A.SoundFontHeadroomDB<>B.SoundFontHeadroomDB);
end;

function AudSettingsEqual(const A,B: TAudSettings): Boolean;
begin
  Result := not AudRestartNeeded(A,B) and (A.Source=B.Source) and
    (A.InputLevel=B.InputLevel) and (A.SourceLevel=B.SourceLevel) and
    (A.Fader1=B.Fader1) and (A.Fader2=B.Fader2) and (A.DebugMode=B.DebugMode) and
    (A.ShutdownMode=B.ShutdownMode) and (A.MonitorOn=B.MonitorOn) and
    (A.MonitorVolume=B.MonitorVolume) and (A.MonitorSource=B.MonitorSource) and
    (A.BassOn=B.BassOn) and (A.BassHz=B.BassHz) and
    EqSame(A.EQ,B.EQ) and RevSame(A.Rev,B.Rev);
end;

function AudSourceName(Source: Word): string;
begin
  case Source of
    0: Result := 'LineIn';
    1: Result := 'Mic';
    2: Result := 'CD';
    3: Result := 'Aux';
    4: Result := 'CDDigital';
    5: Result := 'SPDIF';
    6: Result := 'Wave';
  else
    Result := '';
  end;
end;

function AudSourceNumber(const Name: string; var Source: Word): Boolean;
var S: string;
begin
  Result := True; S := UpperCase(Name);
  if (S='LINEIN') or (S='LINE-IN') then Source := 0
  else if (S='MIC') or (S='MICROPHONE') then Source := 1
  else if (S='CD') or (S='CDANALOG') then Source := 2
  else if S='AUX' then Source := 3
  else if (S='CDDIGITAL') or (S='CDSPDIF') then Source := 4
  else if (S='SPDIF') or (S='OPTICAL') then Source := 5
  else if S='WAVE' then Source := 6
  else Result := False;
end;

{$I AUD2GAIN.INC}

procedure SetText(Window: HWnd; const S: string);
var B: array[0..255] of Char;
begin
  StrPCopy(B,S); SetWindowText(Window,B);
end;

procedure SetNumber(Window: HWnd; V: LongInt);
begin
  SetText(Window,IntToStr(V));
end;

procedure ConfigNotice(const S: string);
var B: array[0..255] of Char;
begin
  StrPCopy(B,S);
  MessageBox(ConfigWindow,B,'Audigy 2 configuration',MB_OK or MB_ICONEXCLAMATION);
end;

function ReadNumber(Window: HWnd; LowValue,HighValue: LongInt;
                    var Value: LongInt): Boolean;
var B: array[0..63] of Char;
    Err: Integer;
begin
  GetWindowText(Window,B,SizeOf(B));
  Val(StrPas(B),Value,Err);
  Result := (Err=0) and (Value>=LowValue) and (Value<=HighValue);
  if not Result then begin
    SetFocus(Window); SendMessage(Window,EM_SETSEL,0,LongInt($7FFF0000));
  end;
end;

function ReadWord(Window: HWnd; LowValue,HighValue: Word;
                  var Value: Word): Boolean;
var V: LongInt;
begin
  Result := ReadNumber(Window,LongInt(LowValue),LongInt(HighValue),V);
  if Result then Value := Word(V);
end;

procedure SourceEnabled;
var N: LongInt;
begin
  N := SendMessage(SourceBox,CB_GETCURSEL,0,0);
  EnableWindow(SourceEdit,not Waiting and ((N=0) or (N=2) or (N=3)));
  if N=6 then SendMessage(MonitorBox,BM_SETCHECK,0,0);
  EnableWindow(MonitorBox,not Waiting and (N<>6));
  EnableWindow(MonitorEdit,not Waiting and (N<>6));
end;

procedure BassEnabled;
begin
  EnableWindow(BassSlider,not Waiting and (SendMessage(BassBox,BM_GETCHECK,0,0)=1));
end;

procedure SetBassPosition(N: Integer);
begin
  if N<0 then N := 0;
  if N>AudBassSteps then N := AudBassSteps;
  SetScrollPos(BassSlider,SB_CTL,N,True);
  SetText(BassLabel,IntToStr(AudBassMinHz+AudBassStepHz*N)+' Hz');
end;

procedure EnableControls(Enable: Boolean);
begin
  EnableWindow(SourceBox,Enable); EnableWindow(LevelEdit,Enable);
  EnableWindow(FaderEdit1,Enable); EnableWindow(FaderEdit2,Enable);
  EnableWindow(DebugBox,Enable);
  EnableWindow(ShutdownBox,Enable); EnableWindow(PhysicalEdit,Enable);
  EnableWindow(MonitorBox,Enable); EnableWindow(MonitorEdit,Enable);
  EnableWindow(CardEdit,Enable); EnableWindow(HalfEdit,Enable);
  EnableWindow(SliceEdit,Enable); EnableWindow(TimerEdit,Enable);
  EnableWindow(ResolutionEdit,Enable);
  EnableWindow(GainEdit,Enable);
  EnableWindow(MidiSettingsButton,Enable);
  EnableWindow(OKButton,Enable); EnableWindow(ApplyButton,Enable);
  EnableWindow(EqualizerButton,Enable);
  EnableWindow(ReverbButton,Enable);
  EnableWindow(BassBox,Enable); BassEnabled;
  SourceEnabled;
end;

procedure FinishApply;
var Status: Word;
begin
  if not Waiting then Exit;
  Status := PollRequest(InitialActive,LastSaved);
  if Status=0 then begin
    if timeGetTime-RequestTick>=3000 then begin
      if CancelRequest then begin
        { If the timer won the race, Poll saves its already-applied settings. }
        Status := PollRequest(InitialActive,LastSaved);
        if Status=0 then Status := 4;
      end else Exit;
    end else Exit;
  end;
  Waiting := False; EnableControls(True);
  LastApplyStatus := Status;
  if Status=1 then begin
    MonitorEdited := False;
    if CloseAfterApply then DestroyWindow(ConfigWindow);
  end else begin
    CloseAfterApply := False;
    if Status=2 then
      ConfigNotice('The input route could not be changed. No settings were saved.')
    else if Status=3 then
      ConfigNotice('INI write failed. Live changes are active; '+
                   'some keys may be saved. Retry Apply.')
    else ConfigNotice('The request was cancelled or the driver timer did not respond.');
  end;
end;

function ReadDraft: Boolean;
var V: LongInt;
    GainText: array[0..31] of Char;
begin
  Result := False; Draft := LastSaved;
  Draft.EQ := EqDraft;
  Draft.Rev := RevDraft;
  Draft.BassOn := Word(SendMessage(BassBox,BM_GETCHECK,0,0));
  Draft.BassHz := AudBassMinHz+AudBassStepHz*GetScrollPos(BassSlider,SB_CTL);
  V := SendMessage(SourceBox,CB_GETCURSEL,0,0);
  if (V<0) or (V>6) then Exit;
  Draft.Source := Word(V);
  if Draft.Source<6 then Draft.MonitorSource := Draft.Source;
  if not ReadWord(LevelEdit,0,100,Draft.InputLevel) then Exit;
  if not ReadWord(SourceEdit,0,100,Draft.SourceLevel) then Exit;
  if not ReadWord(FaderEdit1,0,100,Draft.Fader1) then Exit;
  if not ReadWord(FaderEdit2,0,100,Draft.Fader2) then Exit;
  Draft.DebugMode := Word(SendMessage(DebugBox,BM_GETCHECK,0,0));
  Draft.ShutdownMode := Word(SendMessage(ShutdownBox,BM_GETCHECK,0,0));
  Draft.MonitorOn := Word(SendMessage(MonitorBox,BM_GETCHECK,0,0));
  if Draft.Source=6 then Draft.MonitorOn := 0;
  if not ReadNumber(MonitorEdit,0,100,V) then Exit;
  { Preserve exact AUX 16-bit volume when its displayed percent is unchanged. }
  Draft.MonitorVolume := InitialActive.MonitorVolume;
  if V<>AudMonitorPercent(InitialActive.MonitorVolume) then
    Draft.MonitorVolume := AudMonitorValue(Word(V));
  if not ReadNumber(PhysicalEdit,$100000,$7FFFFFFF-$40000,V) then Exit;
  Draft.PhysicalBase := V;
  if not ReadWord(CardEdit,0,255,Draft.CardIndex) then Exit;
  if not ReadWord(HalfEdit,10,60,Draft.HalfMS) then Exit;
  if not ReadWord(SliceEdit,5,30,Draft.SliceMS) then Exit;
  if not ReadWord(TimerEdit,1,20,Draft.TimerMS) then Exit;
  if not ReadWord(ResolutionEdit,1,10,Draft.ResolutionMS) then Exit;
  GetWindowText(GainEdit,GainText,SizeOf(GainText));
  if not AudGainParse(StrPas(GainText),Draft.GainSteps) then begin
    SetFocus(GainEdit); SendMessage(GainEdit,EM_SETSEL,0,LongInt($7FFF0000));
    Exit;
  end;
  Draft.MidiSynth := MidiDraft.MidiSynth;
  Draft.MidiRate := MidiDraft.MidiRate;
  Draft.SoundFont := MidiDraft.SoundFont;
  Draft.SoundFontVoices := MidiDraft.SoundFontVoices;
  Draft.SoundFontHeadroomDB := MidiDraft.SoundFontHeadroomDB;
  Draft.Playback2Aux := MidiDraft.Playback2Aux;
  Result := AudSettingsValid(Draft);
end;

procedure BeginApply(CloseWhenDone: Boolean);
var Status: Word;
begin
  if Waiting then Exit;
  if not ReadDraft then begin
    ConfigNotice('Check the displayed ranges. PhysicalBase must also be 4096-byte aligned.');
    Exit;
  end;
  if AudRestartNeeded(InitialActive,Draft) and
     ((Draft.PhysicalBase<>LastSaved.PhysicalBase) or
      (Draft.CardIndex<>LastSaved.CardIndex)) then begin
    if MessageBox(ConfigWindow,
      'The complete 256 KiB RAM area must be unused by DOS/Windows. Save these values?',
      'Device / DMA change',MB_OKCANCEL or MB_ICONEXCLAMATION)<>IDOK then Exit;
  end;
  Status := SubmitRequest(Draft);
  if Status<>0 then begin
    if Status=1 then ConfigNotice('The driver is busy. Please press Apply again.')
    else ConfigNotice('The driver is unavailable or a setting is invalid. Nothing was changed.');
    Exit;
  end;
  Waiting := True; CloseAfterApply := CloseWhenDone; RequestTick := timeGetTime;
  EnableControls(False);
end;

function SubmitEQ(const E: TEqSettings): Word;
begin
  Result := 1;
  if Waiting or (ConfigWindow=0) then Exit;
  EqDraft := E; LastApplyStatus := 0;
  BeginApply(False);
  if Waiting then Result := 0 else Result := 2;
end;

function PollEQ(var Active: TEqSettings): Word;
begin
  if Waiting then FinishApply;
  Active := InitialActive.EQ;
  if Waiting then Result := 0 else Result := LastApplyStatus;
end;

function SubmitRev(const R: TRevSettings): Word;
begin
  Result := 1;
  if Waiting or (ConfigWindow=0) then Exit;
  RevDraft := R; LastApplyStatus := 0;
  BeginApply(False);
  if Waiting then Result := 0 else Result := 2;
end;

function PollRev(var Active: TRevSettings): Word;
begin
  if Waiting then FinishApply;
  Active := InitialActive.Rev;
  if Waiting then Result := 0 else Result := LastApplyStatus;
end;

function AddControl(ClassName,Caption: PChar; Style: LongInt;
                    X,Y,W,H: Integer; ID: Word): HWnd;
begin
  Result := CreateWindow(ClassName,Caption,WS_CHILD or WS_VISIBLE or Style,
                         X,Y,W,H,ConfigWindow,ID,HInstance,nil);
  if Result=0 then ControlsOK := False;
end;

function AddEdit(LabelText: PChar; X,Y: Integer; ID: Word): HWnd;
var Dummy: HWnd;
begin
  Dummy := AddControl('STATIC',LabelText,0,X,Y+3,185,20,0);
  Result := AddControl('EDIT','',WS_BORDER or ES_AUTOHSCROLL or WS_TABSTOP,
                       X+187,Y,80,22,ID);
  SendMessage(Result,EM_LIMITTEXT,20,0);
end;

{$I MIDIUI.INC}

procedure AddSource(const S: string);
var B: array[0..63] of Char;
begin
  StrPCopy(B,S);
  if SendMessage(SourceBox,CB_ADDSTRING,0,LongInt(@B))<0 then ControlsOK := False;
end;

procedure CreateControls;
var Dummy: HWnd;
    VersionLabel: array[0..63] of Char;
begin
  ControlsOK := True; Loading := True;
  Dummy := AddControl('BUTTON','Apply in this session',BS_GROUPBOX,8,8,290,355,0);
  Dummy := AddControl('BUTTON','Requires Windows restart',BS_GROUPBOX,306,8,294,355,0);
  Dummy := AddControl('STATIC','Source:',0,20,39,80,20,0);
  SourceBox := AddControl('COMBOBOX','',CBS_DROPDOWNLIST or WS_VSCROLL or WS_TABSTOP,
                          105,35,180,155,IDSource);
  AddSource('Line-In'); AddSource('Microphone'); AddSource('CD (analog)');
  AddSource('Aux'); AddSource('CD Digital (S/PDIF)'); AddSource('S/PDIF (AudigyDrive)');
  AddSource('Wave');
  LevelEdit := AddEdit('Recording level (0..100)',20,69,IDLevel);
  SourceEdit := AddEdit('Analog source level (0..100)',20,100,IDSourceLevel);
  FaderEdit1 := AddEdit('Front/Rear 1 (0..100)',20,128,IDRear);
  FaderEdit2 := AddEdit('Front/Rear 2 (0..100)',20,153,IDFader2);
  DebugBox := AddControl('BUTTON','Debug logging',BS_AUTOCHECKBOX or WS_TABSTOP,
                         20,179,260,21,IDDebug);
  ShutdownBox := AddControl('BUTTON','Shutdown workaround',BS_AUTOCHECKBOX or WS_TABSTOP,
                            20,203,260,21,IDShutdown);
  MonitorBox := AddControl('BUTTON','Monitor input',BS_AUTOCHECKBOX or WS_TABSTOP,
                           20,228,260,21,IDMonitor);
  MonitorEdit := AddEdit('Monitor level (0..100)',20,258,IDMonitorLevel);
  BassBox := AddControl('BUTTON','Bass redirection',BS_AUTOCHECKBOX or WS_TABSTOP,
                         20,296,128,22,IDBass);
  { A native horizontal scrollbar: no common-controls DLL on Win 3.1. }
  BassSlider := AddControl('SCROLLBAR','',WS_TABSTOP,152,299,82,17,IDBassHz);
  BassLabel := AddControl('STATIC','',0,241,298,48,20,0);
  SetScrollRange(BassSlider,SB_CTL,0,AudBassSteps,False);
  SetBassPosition((InitialActive.BassHz-AudBassMinHz) div AudBassStepHz);
  SendMessage(BassBox,BM_SETCHECK,InitialActive.BassOn,0);
  BassEnabled;
  EqualizerButton := AddControl('BUTTON','Equalizer...',WS_TABSTOP,
                                 20,328,125,26,IDEqualizer);
  ReverbButton := AddControl('BUTTON','Reverb...',WS_TABSTOP,
                              154,328,125,26,IDReverb);
  PhysicalEdit := AddEdit('PhysicalBase (hex $)',318,35,IDPhysical);
  CardEdit := AddEdit('CardIndex (0..255)',318,71,IDCard);
  HalfEdit := AddEdit('HalfBufferMS (10..60)',318,107,IDHalf);
  SliceEdit := AddEdit('RefillSliceMS (5..30)',318,143,IDSlice);
  TimerEdit := AddEdit('TimerIntervalMS (1..20)',318,179,IDTimer);
  ResolutionEdit := AddEdit('ResolutionMS (1..10)',318,215,IDResolution);
  MidiSettingsButton := AddControl('BUTTON','MIDI Settings...',WS_TABSTOP,
                                   318,256,150,26,IDMidiSettings);
  GainEdit := AddEdit('Aud2Gain dB (0..12)',318,298,IDGain);
  OKButton := AddControl('BUTTON','OK',BS_DEFPUSHBUTTON or WS_TABSTOP,300,381,90,26,IDOK);
  CancelButton := AddControl('BUTTON','Cancel',WS_TABSTOP,400,381,90,26,IDCANCEL);
  ApplyButton := AddControl('BUTTON','Apply',WS_TABSTOP,500,381,90,26,IDApply);
  StrPCopy(VersionLabel,'Driver version '+AudDriverVersionText);
  Dummy := AddControl('STATIC',VersionLabel,0,14,386,275,20,0);
  Loading := True;
  SendMessage(SourceBox,CB_SETCURSEL,InitialActive.Source,0);
  SetNumber(LevelEdit,InitialActive.InputLevel); SetNumber(SourceEdit,InitialActive.SourceLevel);
  SetNumber(FaderEdit1,InitialActive.Fader1);
  SetNumber(FaderEdit2,InitialActive.Fader2);
  SendMessage(DebugBox,BM_SETCHECK,InitialActive.DebugMode,0);
  SendMessage(ShutdownBox,BM_SETCHECK,InitialActive.ShutdownMode,0);
  SendMessage(MonitorBox,BM_SETCHECK,InitialActive.MonitorOn,0);
  SetNumber(MonitorEdit,AudMonitorPercent(InitialActive.MonitorVolume));
  SetText(PhysicalEdit,'$'+IntToHex(LastSaved.PhysicalBase,8));
  SetNumber(CardEdit,LastSaved.CardIndex); SetNumber(HalfEdit,LastSaved.HalfMS);
  SetNumber(SliceEdit,LastSaved.SliceMS); SetNumber(TimerEdit,LastSaved.TimerMS);
  SetNumber(ResolutionEdit,LastSaved.ResolutionMS);
  SetText(GainEdit,AudGainText(LastSaved.GainSteps));
  Loading := False; SourceEnabled;
end;

procedure RefreshMonitor;
var Active,Saved: TAudSettings;
begin
  if (ConfigWindow=0) or Waiting or MonitorEdited then Exit;
  if SendMessage(SourceBox,CB_GETCURSEL,0,0)=6 then Exit;
  if PollRequest(Active,Saved)<>1 then Exit;
  if (Active.MonitorOn=InitialActive.MonitorOn) and
     (Active.MonitorVolume=InitialActive.MonitorVolume) then Exit;
  InitialActive.MonitorOn := Active.MonitorOn;
  InitialActive.MonitorVolume := Active.MonitorVolume;
  LastSaved.MonitorOn := Saved.MonitorOn; LastSaved.MonitorVolume := Saved.MonitorVolume;
  Loading := True;
  SendMessage(MonitorBox,BM_SETCHECK,Active.MonitorOn,0);
  SetNumber(MonitorEdit,AudMonitorPercent(Active.MonitorVolume));
  Loading := False;
end;

function ConfigWndProc(Window: HWnd; Message,WParam: Word;
                       LParam: LongInt): LongInt; export;
var Status: Word;
    N: Integer;
begin
  Result := 0;
  case Message of
    WM_CREATE: begin ConfigWindow := Window; CreateControls; end;
    WM_HSCROLL: if not Waiting and (HiWord(LParam)=BassSlider) then begin
      N := GetScrollPos(BassSlider,SB_CTL);
      case WParam of
        SB_LINEUP: Dec(N); SB_LINEDOWN: Inc(N);
        SB_PAGEUP: N := N-4; SB_PAGEDOWN: N := N+4;
        SB_THUMBPOSITION,SB_THUMBTRACK: N := LoWord(LParam);
        SB_TOP: N := 0; SB_BOTTOM: N := AudBassSteps;
      end;
      SetBassPosition(N);
    end;
    WM_COMMAND: begin
      if WParam=IDOK then BeginApply(True)
      else if WParam=IDApply then BeginApply(False)
      else if WParam=IDCANCEL then SendMessage(Window,WM_CLOSE,0,0)
      else if (WParam=IDEqualizer) and not Waiting then begin
        EqDialog(Window,EqDraft,SubmitEQ,PollEQ);
      end
      else if (WParam=IDReverb) and not Waiting then begin
        RevDialog(Window,RevDraft,SubmitRev,PollRev);
      end
      else if (WParam=IDMidiSettings) and not Waiting then MidiDialog(Window)
      else if not Loading and not Waiting then begin
        if WParam=IDSource then SourceEnabled;
        if WParam=IDBass then BassEnabled;
        if ((WParam=IDMonitor) and (HiWord(LParam)=BN_CLICKED)) or
           ((WParam=IDMonitorLevel) and (HiWord(LParam)=EN_CHANGE)) then
          MonitorEdited := True;
      end;
    end;
    WM_TIMER: if WParam=1 then begin FinishApply; RefreshMonitor; end;
    WM_CLOSE: begin
      if Waiting then begin
        if not CancelRequest then Exit;
        Status := PollRequest(InitialActive,LastSaved);
        if Status=3 then ConfigNotice('INI write failed; some settings may not be saved.');
        Waiting := False;
      end;
      DestroyWindow(Window);
    end;
    WM_QUERYENDSESSION: Result := 1;
    WM_ENDSESSION: if WParam<>0 then begin
      if Waiting then CancelRequest;
      DestroyWindow(Window);
    end;
    WM_DESTROY: begin
      KillTimer(Window,1); ConfigWindow := 0;
      { Do not post WM_QUIT into the Control Panel task's message queue. }
    end;
  else
    Result := DefWindowProc(Window,Message,WParam,LParam);
  end;
end;

function AudConfigure(Owner: HWnd; const Active,Saved: TAudSettings;
                      Submit: TAudSubmit; Poll: TAudPoll;
                      Cancel: TAudCancel): Boolean;
var WC: TWndClass;
    Msg: TMsg;
    ProcInstance: TFarProc;
    OwnerDisabled, GotQuit: Boolean;
    QuitCode: Word;
    X,Y: Integer;
begin
  Result := False;
  if ConfigWindow<>0 then begin SetActiveWindow(ConfigWindow); Result := True; Exit; end;
  InitialActive := Active; LastSaved := Saved; MidiDraft := Saved;
  EqDraft := Active.EQ;
  RevDraft := Active.Rev;
  SubmitRequest := Submit; PollRequest := Poll; CancelRequest := Cancel;
  Waiting := False; Loading := False; CloseAfterApply := False;
  MonitorEdited := False;
  FillChar(WC,SizeOf(WC),0);
  ProcInstance := MakeProcInstance(@ConfigWndProc,HInstance);
  if not Assigned(ProcInstance) then Exit;
  WC.lpfnWndProc := ProcInstance; WC.hInstance := HInstance;
  WC.hCursor := LoadCursor(0,IDC_ARROW); WC.hbrBackground := COLOR_BTNFACE+1;
  WC.lpszClassName := ConfigClass;
  if not RegisterClass(WC) then begin FreeProcInstance(ProcInstance); Exit; end;
  X := (GetSystemMetrics(SM_CXSCREEN)-ConfigWidth) div 2;
  Y := (GetSystemMetrics(SM_CYSCREEN)-ConfigHeight) div 2;
  if X<0 then X := 0;
  if Y<0 then Y := 0;
  ConfigWindow := CreateWindow(ConfigClass,'Creative Audigy 2 - Configuration',
    WS_POPUP or WS_CAPTION or WS_SYSMENU or WS_DLGFRAME,
    X,Y,ConfigWidth,ConfigHeight,Owner,0,HInstance,nil);
  OwnerDisabled := False; GotQuit := False; QuitCode := 0;
  if ConfigWindow<>0 then begin
    if not ControlsOK or (SetTimer(ConfigWindow,1,100,nil)=0) then
      DestroyWindow(ConfigWindow)
    else begin
      if (Owner<>0) and IsWindowEnabled(Owner) then begin
        EnableWindow(Owner,False); OwnerDisabled := True;
      end;
      ShowWindow(ConfigWindow,SW_SHOWNORMAL); UpdateWindow(ConfigWindow);
      SetFocus(SourceBox); Result := True;
      while ConfigWindow<>0 do begin
        if not GetMessage(Msg,0,0,0) then begin
          GotQuit := True; QuitCode := Msg.wParam;
          if Waiting then CancelRequest;
          if ConfigWindow<>0 then DestroyWindow(ConfigWindow);
          Break;
        end;
        if not IsDialogMessage(ConfigWindow,Msg) then begin
          TranslateMessage(Msg); DispatchMessage(Msg);
        end;
      end;
    end;
  end;
  if OwnerDisabled and IsWindow(Owner) then begin
    EnableWindow(Owner,True); SetActiveWindow(Owner);
  end;
  UnregisterClass(ConfigClass,HInstance); FreeProcInstance(ProcInstance);
  SubmitRequest := nil; PollRequest := nil; CancelRequest := nil;
  if GotQuit then PostQuitMessage(QuitCode);
end;

begin
  ConfigWindow := 0;
  SubmitRequest := nil; PollRequest := nil; CancelRequest := nil;
end.
