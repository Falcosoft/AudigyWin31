{ Task-only MIDI options. The parent applies the accepted settings. }
const
  MidiClass='Audigy1MidiSettings';
  MidiWidth=450; MidiHeight=244;
  IDMidiSynth=101; IDMidiRate=102; IDFontPath=103;
  IDFontBrowse=104; IDFontVoices=105; IDWaveAux=106; IDFontHeadroom=107;

type
  { Windows 3.1 OPENFILENAME uses 16-bit handles and 32-bit pointers. }
  TMidiOpenFileName=packed record
    StructSize: LongInt;
    Owner: HWnd;
    Instance: THandle;
    Filter, CustomFilter: PChar;
    MaxCustomFilter, FilterIndex: LongInt;
    FileName: PChar;
    MaxFile: LongInt;
    FileTitle: PChar;
    MaxFileTitle: LongInt;
    InitialDir, Title: PChar;
    Flags: LongInt;
    FileOffset, ExtensionOffset: Word;
    DefaultExt: PChar;
    CustData: LongInt;
    Hook: Pointer;
    TemplateName: PChar;
  end;

var
  MidiWindow, MidiSynthBox, MidiRateBox, MidiRateLabel: HWnd;
  FontEdit, FontBrowse, FontVoicesEdit, FontLabel, FontVoicesLabel, WaveAuxBox: HWnd;
  FontHeadroomLabel, FontHeadroomEdit: HWnd;
  MidiControlsOK: Boolean;

function MidiOpenFile(var OFN: TMidiOpenFileName): Boolean;
  external 'COMMDLG' name 'GETOPENFILENAME';

function AddMidiControl(ClassName,Caption: PChar; Style: LongInt;
                        X,Y,W,H: Integer; ID: Word): HWnd;
begin
  Result := CreateWindow(ClassName,Caption,WS_CHILD or WS_VISIBLE or Style,
                         X,Y,W,H,MidiWindow,ID,HInstance,nil);
  if Result=0 then MidiControlsOK := False;
end;

procedure AddMidiChoice(Box: HWnd; Caption: PChar);
begin
  if SendMessage(Box,CB_ADDSTRING,0,LongInt(Caption))<0 then MidiControlsOK := False;
end;

procedure EnableMidiControls;
var Mode: LongInt;
    SF2: Boolean;
begin
  Mode := SendMessage(MidiSynthBox,CB_GETCURSEL,0,0);
  SF2 := Mode=SynthSoundFont;
  EnableWindow(MidiRateLabel,Mode>SynthNone);
  EnableWindow(MidiRateBox,Mode>SynthNone);
  EnableWindow(FontLabel,SF2);
  EnableWindow(FontEdit,SF2);
  EnableWindow(FontBrowse,SF2);
  EnableWindow(FontVoicesLabel,SF2);
  EnableWindow(FontVoicesEdit,SF2);
  EnableWindow(FontHeadroomLabel,SF2);
  EnableWindow(FontHeadroomEdit,SF2);
end;

procedure CreateMidiControls;
var Dummy: HWnd;
begin
  MidiControlsOK := True;
  Dummy := AddMidiControl('STATIC','MIDI synth',0,14,20,142,20,0);
  MidiSynthBox := AddMidiControl('COMBOBOX','',CBS_DROPDOWNLIST or WS_TABSTOP,
                                 161,16,170,92,IDMidiSynth);
  { Combo indices match the INI mode values. }
  AddMidiChoice(MidiSynthBox,'None');
  AddMidiChoice(MidiSynthBox,'OPL3 Synth');
  AddMidiChoice(MidiSynthBox,'SF2 Synth');
  MidiRateLabel := AddMidiControl('STATIC','Synth sample rate',0,14,52,142,20,0);
  MidiRateBox := AddMidiControl('COMBOBOX','',CBS_DROPDOWNLIST or WS_TABSTOP,
                                161,48,170,72,IDMidiRate);
  AddMidiChoice(MidiRateBox,'44.1 kHz');
  AddMidiChoice(MidiRateBox,'48 kHz');
  FontLabel := AddMidiControl('STATIC','SoundFont file',0,14,84,142,20,0);
  FontEdit := AddMidiControl('EDIT','',WS_BORDER or ES_AUTOHSCROLL or WS_TABSTOP,
                             161,80,184,22,IDFontPath);
  SendMessage(FontEdit,EM_LIMITTEXT,255,0);
  FontBrowse := AddMidiControl('BUTTON','Browse...',WS_TABSTOP,350,78,78,26,IDFontBrowse);
  FontVoicesLabel := AddMidiControl('STATIC','SF2 voices (32..128)',0,14,116,145,20,0);
  FontVoicesEdit := AddMidiControl('EDIT','',WS_BORDER or ES_AUTOHSCROLL or WS_TABSTOP,
                                   161,112,72,22,IDFontVoices);
  SendMessage(FontVoicesEdit,EM_LIMITTEXT,3,0);
  FontHeadroomLabel := AddMidiControl('STATIC','SF2 headroom (dB)',0,244,116,125,20,0);
  FontHeadroomEdit := AddMidiControl('EDIT','',WS_BORDER or ES_AUTOHSCROLL or WS_TABSTOP,
                                     374,112,54,22,IDFontHeadroom);
  SendMessage(FontHeadroomEdit,EM_LIMITTEXT,2,0);
  WaveAuxBox := AddMidiControl('BUTTON','Playback 2 AUX volume (WinGroove)',
                               BS_AUTOCHECKBOX or WS_TABSTOP,14,143,300,22,IDWaveAux);
  Dummy := AddMidiControl('BUTTON','OK',BS_DEFPUSHBUTTON or WS_TABSTOP,250,180,82,26,IDOK);
  Dummy := AddMidiControl('BUTTON','Cancel',WS_TABSTOP,346,180,82,26,IDCANCEL);
  SendMessage(MidiSynthBox,CB_SETCURSEL,MidiDraft.MidiSynth,0);
  SendMessage(MidiRateBox,CB_SETCURSEL,Ord(MidiDraft.MidiRate=MidiRateNative),0);
  SetText(FontEdit,MidiDraft.SoundFont);
  SetNumber(FontVoicesEdit,MidiDraft.SoundFontVoices);
  SetNumber(FontHeadroomEdit,MidiDraft.SoundFontHeadroomDB);
  SendMessage(WaveAuxBox,BM_SETCHECK,MidiDraft.Playback2Aux,0);
  EnableMidiControls;
end;

procedure BrowseSoundFont;
const
  FileFlags=$0000180C; { OFN_FILEMUSTEXIST, PATHMUSTEXIST, NOCHANGEDIR, HIDEREADONLY }
var OFN: TMidiOpenFileName;
    Path, Dir: array[0..255] of Char;
    N: Integer;
begin
  GetWindowText(FontEdit,Path,SizeOf(Path));
  FillChar(OFN,SizeOf(OFN),0);
  OFN.StructSize := SizeOf(OFN);
  OFN.Owner := MidiWindow;
  OFN.Filter := 'SoundFont files (*.SF2)'#0'*.SF2'#0#0;
  OFN.FilterIndex := 1;
  OFN.FileName := Path;
  OFN.MaxFile := SizeOf(Path);
  OFN.Title := 'Select SoundFont';
  OFN.Flags := FileFlags;
  OFN.DefaultExt := 'SF2';
  N := GetModuleFileName(HInstance,Dir,SizeOf(Dir));
  if (N>0) and (N<SizeOf(Dir)) then begin
    while (N>0) and (Dir[N-1]<>'\') do Dec(N);
    if N>0 then begin Dir[N] := #0; OFN.InitialDir := Dir; end;
  end;
  if MidiOpenFile(OFN) then SetWindowText(FontEdit,Path);
end;

procedure AcceptMidiSettings;
var Mode, Rate: LongInt;
    Voices, Headroom: Word;
    Path: array[0..255] of Char;
begin
  Mode := SendMessage(MidiSynthBox,CB_GETCURSEL,0,0);
  Rate := SendMessage(MidiRateBox,CB_GETCURSEL,0,0);
  if (Mode<0) or (Mode>SynthSoundFont) or (Rate<0) or (Rate>1) then Exit;
  if Mode=SynthSoundFont then begin
    if not ReadWord(FontVoicesEdit,SFMinVoices,SFMaxVoices,Voices) then begin
      MessageBox(MidiWindow,'Enter a voice limit from 32 to 128.',
                 'MIDI Settings',MB_OK or MB_ICONEXCLAMATION);
      Exit;
    end;
    if not ReadWord(FontHeadroomEdit,0,SFMaxHeadroomDB,Headroom) then begin
      MessageBox(MidiWindow,'Enter SF2 headroom from 0 to 24 dB.',
                 'MIDI Settings',MB_OK or MB_ICONEXCLAMATION);
      Exit;
    end;
    GetWindowText(FontEdit,Path,SizeOf(Path));
    MidiDraft.SoundFont := StrPas(Path);
    if MidiDraft.SoundFont='' then MidiDraft.SoundFont := DefaultSoundFont;
    MidiDraft.SoundFontVoices := Voices;
    MidiDraft.SoundFontHeadroomDB := Headroom;
  end;
  MidiDraft.MidiSynth := Word(Mode);
  if Rate=1 then MidiDraft.MidiRate := MidiRateNative
  else MidiDraft.MidiRate := MidiRateDefault;
  MidiDraft.Playback2Aux := Word(SendMessage(WaveAuxBox,BM_GETCHECK,0,0));
  DestroyWindow(MidiWindow);
end;

function MidiWndProc(Window: HWnd; Message,WParam: Word;
                    LParam: LongInt): LongInt; export;
begin
  Result := 0;
  case Message of
    WM_CREATE: begin MidiWindow := Window; CreateMidiControls; end;
    WM_USER: Result := $534B0000+IDOK; { DM_GETDEFID for IsDialogMessage }
    WM_COMMAND:
      case WParam of
        IDOK: AcceptMidiSettings;
        IDCANCEL: DestroyWindow(Window);
        IDFontBrowse: BrowseSoundFont;
        IDMidiSynth: if HiWord(LParam)=CBN_SELCHANGE then EnableMidiControls;
      end;
    WM_CLOSE: DestroyWindow(Window);
    WM_QUERYENDSESSION: Result := 1;
    WM_ENDSESSION: if WParam<>0 then DestroyWindow(Window);
    WM_DESTROY: MidiWindow := 0;
  else
    Result := DefWindowProc(Window,Message,WParam,LParam);
  end;
end;

procedure MidiDialog(Owner: HWnd);
var WC: TWndClass;
    ProcInstance: TFarProc;
    Msg: TMsg;
    Bounds: TRect;
    X,Y: Integer;
    GotQuit: Boolean;
begin
  if MidiWindow<>0 then Exit;
  FillChar(WC,SizeOf(WC),0);
  ProcInstance := MakeProcInstance(@MidiWndProc,HInstance);
  if not Assigned(ProcInstance) then Exit;
  WC.lpfnWndProc := ProcInstance; WC.hInstance := HInstance;
  WC.hCursor := LoadCursor(0,IDC_ARROW); WC.hbrBackground := COLOR_BTNFACE+1;
  WC.lpszClassName := MidiClass;
  if not RegisterClass(WC) then begin FreeProcInstance(ProcInstance); Exit; end;
  GetWindowRect(Owner,Bounds);
  X := Bounds.Left+(Bounds.Right-Bounds.Left-MidiWidth) div 2;
  Y := Bounds.Top+(Bounds.Bottom-Bounds.Top-MidiHeight) div 2;
  if X<0 then X := 0;
  if Y<0 then Y := 0;
  MidiWindow := CreateWindow(MidiClass,'MIDI Settings',
    WS_POPUP or WS_CAPTION or WS_SYSMENU or WS_DLGFRAME,
    X,Y,MidiWidth,MidiHeight,Owner,0,HInstance,nil);
  GotQuit := False;
  if MidiWindow<>0 then begin
    if not MidiControlsOK then DestroyWindow(MidiWindow)
    else begin
      EnableWindow(Owner,False);
      ShowWindow(MidiWindow,SW_SHOWNORMAL); UpdateWindow(MidiWindow);
      SetFocus(MidiSynthBox);
      while MidiWindow<>0 do begin
        if not GetMessage(Msg,0,0,0) then begin
          GotQuit := True;
          DestroyWindow(MidiWindow);
          Break;
        end;
        if not IsDialogMessage(MidiWindow,Msg) then begin
          TranslateMessage(Msg); DispatchMessage(Msg);
        end;
      end;
      if IsWindow(Owner) then begin
        EnableWindow(Owner,True); SetActiveWindow(Owner); SetFocus(MidiSettingsButton);
      end;
    end;
  end;
  UnregisterClass(MidiClass,HInstance); FreeProcInstance(ProcInstance);
  if GotQuit then PostQuitMessage(Msg.wParam);
end;
