unit RevUI;
{ Task-only, native USER controls. No hardware or multimedia timer access. }
{$F+}
interface
uses WinTypes, AudRev;
type
  TRevSubmit=function(const E: TRevSettings): Word;
  TRevPoll=function(var Active: TRevSettings): Word;
function RevDialog(Owner: HWnd; var E: TRevSettings;
                  Submit: TRevSubmit; Poll: TRevPoll): Boolean;
implementation
uses WinProcs, Messages, SysUtils;
const RevClass='Audigy2RevWindow';
      IDRevApply=3;
      { Display order differs from persistent IDs: keep old INI meanings. }
      PresetOrder: array[0..3] of Word = (0,3,2,1);
var Wnd,CheckBox,LevelEdit,PresetBox: HWnd;
    OKButton,CancelButton,ApplyButton: HWnd;
    Current,LastApplied: TRevSettings;
    Accepted,Created: Boolean;
    Pending,CloseOnSuccess,CloseRequested: Boolean;
    SubmitRequest: TRevSubmit;
    PollRequest: TRevPoll;

function Control(ClassName,Text: PChar; Style: LongInt;
                 X,Y,W,H: Integer; ID: Word): HWnd;
begin
  Result := CreateWindow(ClassName,Text,WS_CHILD or WS_VISIBLE or Style,
                         X,Y,W,H,Wnd,ID,HInstance,nil);
  if Result=0 then Created := False;
end;
procedure Refresh;
var B: array[0..31] of Char;
    I: Word;
begin
  SendMessage(CheckBox,BM_SETCHECK,Current.Enabled,0);
  StrPCopy(B,IntToStr(Current.Level)); SetWindowText(LevelEdit,B);
  for I:=0 to 3 do
    if PresetOrder[I]=Current.Preset then
      SendMessage(PresetBox,CB_SETCURSEL,I,0);
end;
procedure AddPreset(const Name: string);
var B: array[0..31] of Char;
begin
  StrPCopy(B,Name);
  SendMessage(PresetBox,CB_ADDSTRING,0,LongInt(@B));
end;
procedure CreateControls;
var Dummy: HWnd;
begin
  Created := True;
  CheckBox := Control('BUTTON','Enable reverb',BS_AUTOCHECKBOX or WS_TABSTOP,
                       14,12,200,22,10);
  Dummy := Control('STATIC','Preset',0,14,50,80,20,0);
  PresetBox := Control('COMBOBOX','',CBS_DROPDOWNLIST or WS_VSCROLL or WS_TABSTOP,
                       100,46,270,110,12);
  AddPreset('Room'); AddPreset('Chamber'); AddPreset('Plate'); AddPreset('Hall');
  Dummy := Control('STATIC','Level (0..100)',0,14,84,130,20,0);
  LevelEdit := Control('EDIT','50',WS_BORDER or WS_TABSTOP,150,80,70,22,11);
  SendMessage(LevelEdit,EM_LIMITTEXT,3,0);
  OKButton := Control('BUTTON','OK',BS_DEFPUSHBUTTON or WS_TABSTOP,100,124,90,26,IDOK);
  CancelButton := Control('BUTTON','Cancel',WS_TABSTOP,200,124,90,26,IDCANCEL);
  ApplyButton := Control('BUTTON','Apply',WS_TABSTOP,300,124,90,26,IDRevApply);
  Refresh;
end;
procedure EnableControls(Enable: Boolean);
begin
  EnableWindow(CheckBox,Enable); EnableWindow(LevelEdit,Enable);
  EnableWindow(PresetBox,Enable); EnableWindow(OKButton,Enable);
  EnableWindow(CancelButton,Enable); EnableWindow(ApplyButton,Enable);
end;
procedure StartApply(CloseWhenDone: Boolean);
var N,Code: Integer;
    B: array[0..15] of Char;
begin
  if Pending then Exit;
  Current.Enabled := Word(SendMessage(CheckBox,BM_GETCHECK,0,0));
  GetWindowText(LevelEdit,B,SizeOf(B)); Val(StrPas(B),N,Code);
  if (Code<>0) or (N<0) or (N>100) then begin
    MessageBox(Wnd,'Level must be 0 to 100.','Reverb',MB_OK); Exit;
  end;
  Current.Level := N;
  N := SendMessage(PresetBox,CB_GETCURSEL,0,0);
  if (N<0) or (N>3) then Exit;
  Current.Preset := PresetOrder[N];
  if SubmitRequest(Current)<>0 then Exit;
  Pending := True; CloseOnSuccess := CloseWhenDone; CloseRequested := False;
  EnableControls(False);
end;
procedure CheckApply;
var Status: Word;
    Active: TRevSettings;
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
function RevProc(Window: HWnd; Message,WParam: Word; LParam: LongInt): LongInt; export;
begin
  Result := 0;
  case Message of
    WM_CREATE: begin Wnd := Window; CreateControls; end;
    WM_COMMAND: begin
      if Pending then Exit;
      if WParam=IDOK then StartApply(True)
      else if WParam=IDRevApply then StartApply(False)
      else if WParam=IDCANCEL then DestroyWindow(Window);
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
function RevDialog(Owner: HWnd; var E: TRevSettings;
                  Submit: TRevSubmit; Poll: TRevPoll): Boolean;
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
  ProcInstance := MakeProcInstance(@RevProc,HInstance);
  if not Assigned(ProcInstance) then Exit;
  WC.lpfnWndProc := ProcInstance; WC.hInstance := HInstance;
  WC.hCursor := LoadCursor(0,IDC_ARROW); WC.hbrBackground := COLOR_BTNFACE+1;
  WC.lpszClassName := RevClass;
  if not RegisterClass(WC) then begin FreeProcInstance(ProcInstance); Exit; end;
  Wnd := CreateWindow(RevClass,'Audigy 2 - Reverb',WS_POPUP or WS_CAPTION or
    WS_SYSMENU or WS_DLGFRAME,50,70,420,194,Owner,0,HInstance,nil);
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
  UnregisterClass(RevClass,HInstance); FreeProcInstance(ProcInstance);
  E := LastApplied; Result := Accepted and not GotQuit;
  SubmitRequest := nil; PollRequest := nil;
  if GotQuit then PostQuitMessage(QuitCode);
end;
end.
