unit EqUI;
{ Task-only, native USER controls. No hardware or multimedia timer access. }
{$F+}
interface
uses WinTypes, AudEQ;
type
  TEqSubmit=function(const E: TEqSettings): Word;
  TEqPoll=function(var Active: TEqSettings): Word;
function EqDialog(Owner: HWnd; var E: TEqSettings;
                  Submit: TEqSubmit; Poll: TEqPoll): Boolean;
implementation
uses WinProcs, Messages, SysUtils;
const EqClass='Audigy2EqWindow';
      IDEqApply=3;
var Wnd,CheckBox,PreEdit,PresetBox: HWnd;
    OKButton,CancelButton,ApplyButton: HWnd;
    Sliders,Labels: array[0..9] of HWnd;
    Current,LastApplied: TEqSettings;
    Accepted,Created: Boolean;
    Pending,CloseOnSuccess,CloseRequested: Boolean;
    SubmitRequest: TEqSubmit;
    PollRequest: TEqPoll;

function Control(ClassName,Text: PChar; Style: LongInt;
                 X,Y,W,H: Integer; ID: Word): HWnd;
begin
  Result := CreateWindow(ClassName,Text,WS_CHILD or WS_VISIBLE or Style,
                         X,Y,W,H,Wnd,ID,HInstance,nil);
  if Result=0 then Created := False;
end;
procedure Refresh;
var I: Word;
    B: array[0..31] of Char;
begin
  SendMessage(CheckBox,BM_SETCHECK,Current.Enabled,0);
  StrPCopy(B,IntToStr(Current.Preamp)); SetWindowText(PreEdit,B);
  for I:=0 to 9 do begin
    SetScrollPos(Sliders[I],SB_CTL,12-Current.Band[I],True);
    StrPCopy(B,IntToStr(Current.Band[I])); SetWindowText(Labels[I],B);
  end;
end;
procedure AddPreset(const Name: string);
var B: array[0..31] of Char;
begin
  StrPCopy(B,Name);
  SendMessage(PresetBox,CB_ADDSTRING,0,LongInt(@B));
end;
procedure CreateControls;
var I: Word;
    Dummy: HWnd;
begin
  Created := True;
  CheckBox := Control('BUTTON','Enable equalizer',BS_AUTOCHECKBOX or WS_TABSTOP,
                       12,10,180,22,10);
  Dummy := Control('STATIC','Preamp dB (-24..0)',0,218,13,132,20,0);
  PreEdit := Control('EDIT','0',WS_BORDER or WS_TABSTOP,352,10,48,22,11);
  SendMessage(PreEdit,EM_LIMITTEXT,3,0);
  for I:=0 to 9 do begin
    Dummy := Control('STATIC',EqCaption(I),SS_CENTER,12+I*49,43,45,20,0);
    Sliders[I] := Control('SCROLLBAR','',SBS_VERT or WS_TABSTOP,
                          24+I*49,66,20,132,100+I);
    SetScrollRange(Sliders[I],SB_CTL,0,24,False);
    Labels[I] := Control('STATIC','0',SS_CENTER,12+I*49,203,45,20,0);
  end;
  Dummy := Control('STATIC','Band gain: -12 to +12 dB. Reduce preamp when boosting.',
                    0,12,230,500,20,0);
  PresetBox := Control('COMBOBOX','',CBS_DROPDOWNLIST or WS_VSCROLL or WS_TABSTOP,
                       12,260,170,100,12);
  AddPreset('Custom'); AddPreset('Flat'); AddPreset('Bass boost');
  AddPreset('Treble boost'); AddPreset('Loudness');
  SendMessage(PresetBox,CB_SETCURSEL,0,0);
  OKButton := Control('BUTTON','OK',BS_DEFPUSHBUTTON or WS_TABSTOP,210,259,90,26,IDOK);
  CancelButton := Control('BUTTON','Cancel',WS_TABSTOP,310,259,90,26,IDCANCEL);
  ApplyButton := Control('BUTTON','Apply',WS_TABSTOP,410,259,90,26,IDEqApply);
  Refresh;
end;
procedure EnableControls(Enable: Boolean);
var I: Word;
begin
  EnableWindow(CheckBox,Enable); EnableWindow(PreEdit,Enable);
  EnableWindow(PresetBox,Enable); EnableWindow(OKButton,Enable);
  EnableWindow(CancelButton,Enable); EnableWindow(ApplyButton,Enable);
  for I:=0 to 9 do EnableWindow(Sliders[I],Enable);
end;
procedure StartApply(CloseWhenDone: Boolean);
var N,Code: Integer;
    B: array[0..15] of Char;
begin
  if Pending then Exit;
  Current.Enabled := Word(SendMessage(CheckBox,BM_GETCHECK,0,0));
  GetWindowText(PreEdit,B,SizeOf(B)); Val(StrPas(B),N,Code);
  if (Code<>0) or (N< -24) or (N>0) then begin
    MessageBox(Wnd,'Preamp must be -24 to 0 dB.','Equalizer',MB_OK); Exit;
  end;
  Current.Preamp := N;
  if SubmitRequest(Current)<>0 then Exit;
  Pending := True; CloseOnSuccess := CloseWhenDone; CloseRequested := False;
  EnableControls(False);
end;
procedure CheckApply;
var Status: Word;
    Active: TEqSettings;
begin
  if not Pending or (Wnd=0) then Exit;
  Status := PollRequest(Active);
  if (Status=0) or (Wnd=0) then Exit;
  Pending := False; LastApplied := Active;
  EnableControls(True);
  if Status=1 then begin
    Accepted := True;
    if CloseOnSuccess then begin DestroyWindow(Wnd); Exit; end;
  end;
  if CloseRequested then DestroyWindow(Wnd);
end;
function EqProc(Window: HWnd; Message,WParam: Word; LParam: LongInt): LongInt; export;
var I,N: Integer;
    B: array[0..15] of Char;
begin
  Result := 0;
  case Message of
    WM_CREATE: begin Wnd := Window; CreateControls; end;
    WM_VSCROLL: begin
      if Pending then Exit;
      for I:=0 to 9 do if Sliders[I]=HiWord(LParam) then begin
        N := GetScrollPos(Sliders[I],SB_CTL);
        case WParam of
          SB_LINEUP: Dec(N); SB_LINEDOWN: Inc(N);
          SB_PAGEUP: N := N-3; SB_PAGEDOWN: N := N+3;
          SB_THUMBPOSITION,SB_THUMBTRACK: N := LoWord(LParam);
          SB_TOP: N := 0; SB_BOTTOM: N := 24;
        end;
        if N<0 then N := 0; if N>24 then N := 24;
        Current.Band[I] := 12-N;
        SetScrollPos(Sliders[I],SB_CTL,N,True);
        StrPCopy(B,IntToStr(Current.Band[I])); SetWindowText(Labels[I],B);
      end;
    end;
    WM_COMMAND: begin
      if Pending then Exit;
      if WParam=IDOK then StartApply(True)
      else if WParam=IDEqApply then StartApply(False)
      else if WParam=IDCANCEL then DestroyWindow(Window)
      else if (WParam=12) and (HiWord(LParam)=CBN_SELCHANGE) then begin
        N := SendMessage(PresetBox,CB_GETCURSEL,0,0);
        Dec(N); if N<0 then Exit;
        FillChar(Current,SizeOf(Current),0);
        if N>0 then begin
          Current.Enabled := 1; Current.Preamp := -6;
          if (N=1) or (N=3) then begin
            Current.Band[0] := 6; Current.Band[1] := 5;
            Current.Band[2] := 3; Current.Band[3] := 1;
          end;
          if (N=2) or (N=3) then begin
            Current.Band[6] := 1; Current.Band[7] := 3;
            Current.Band[8] := 5; Current.Band[9] := 6;
          end;
        end;
        Refresh;
      end;
    end;
    WM_CLOSE: begin
      if Pending then CloseRequested := True else DestroyWindow(Window);
    end;
    WM_QUERYENDSESSION: Result := 1;
    WM_ENDSESSION: if WParam<>0 then DestroyWindow(Window);
    WM_DESTROY: Wnd := 0;
  else Result := DefWindowProc(Window,Message,WParam,LParam);
  end;
end;
function EqDialog(Owner: HWnd; var E: TEqSettings;
                  Submit: TEqSubmit; Poll: TEqPoll): Boolean;
var WC: TWndClass;
    ProcInstance: TFarProc;
    Msg: TMsg;
    Disabled,GotQuit: Boolean;
    QuitCode: Word;
begin
  Result := False; if Wnd<>0 then Exit;
  Current := E; LastApplied := E;
  SubmitRequest := Submit; PollRequest := Poll;
  Pending := False; CloseOnSuccess := False; CloseRequested := False;
  Accepted := False; GotQuit := False; QuitCode := 0;
  FillChar(WC,SizeOf(WC),0);
  ProcInstance := MakeProcInstance(@EqProc,HInstance);
  if not Assigned(ProcInstance) then Exit;
  WC.lpfnWndProc := ProcInstance; WC.hInstance := HInstance;
  WC.hCursor := LoadCursor(0,IDC_ARROW); WC.hbrBackground := COLOR_BTNFACE+1;
  WC.lpszClassName := EqClass;
  if not RegisterClass(WC) then begin FreeProcInstance(ProcInstance); Exit; end;
  Wnd := CreateWindow(EqClass,'Audigy 2 - Equalizer',WS_POPUP or WS_CAPTION or
    WS_SYSMENU or WS_DLGFRAME,30,40,530,330,Owner,0,HInstance,nil);
  Disabled := False;
  if Wnd<>0 then begin
    if not Created then DestroyWindow(Wnd)
    else begin
      if (Owner<>0) and IsWindowEnabled(Owner) then begin
        EnableWindow(Owner,False); Disabled := True;
      end;
      ShowWindow(Wnd,SW_SHOWNORMAL); UpdateWindow(Wnd);
      while Wnd<>0 do begin
        if not GetMessage(Msg,0,0,0) then begin
          GotQuit := True; QuitCode := Msg.wParam; DestroyWindow(Wnd); Break;
        end;
        if (Wnd<>0) and not IsDialogMessage(Wnd,Msg) then begin
          TranslateMessage(Msg); DispatchMessage(Msg);
        end;
        { Parent setup's existing 100ms WM_TIMER supplies wakeups and timeout.
          No additional window or multimedia timer is created here. }
        CheckApply;
      end;
    end;
  end;
  if Disabled and IsWindow(Owner) then begin
    EnableWindow(Owner,True); SetActiveWindow(Owner);
  end;
  UnregisterClass(EqClass,HInstance); FreeProcInstance(ProcInstance);
  E := LastApplied; Result := Accepted and not GotQuit;
  SubmitRequest := nil; PollRequest := nil;
  if GotQuit then PostQuitMessage(QuitCode);
end;
end.
