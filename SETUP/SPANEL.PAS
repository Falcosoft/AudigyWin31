unit SPanel;

{$F+}
{$W+}
{$B-}
interface
procedure RunSetup;

implementation
uses WinTypes, WinProcs, Messages, SysUtils, ShellAPI, SFiles, SMemory, SInstall,
     SWinMem, SProgman, SPci;

const SetupClass='AudigyStandaloneSetup';
      UnknownBaseText: string[9]='$????????';
      IDCard=100;
      IDBase=101;
      IDXMS=102;
      IDConfirm=103;
      IDReadme=104;
      WarningRed=$000000A0;
      WarningWhite=$00FFFFFF;
var Wnd,CardBox,BaseEdit,XMSEdit,ConfirmBox,InstallButton,Status: HWnd;
    HardwareBanner: HWnd;
    HardwareBrush: HBrush;
    Paths: TSetupPaths;
    MemoryInfo: TMemoryInfo;
    Cards: array[0..1] of Word;
    CardCount: Word;
    HardwareStatus,PreferredCard: Word;
    DetectedWindowsMB: LongInt;
    WindowsMemoryKnown: Boolean;
    ExtraHeight: Integer;
    BannerSpace: Integer;
    LastBaseText: string;
    BaseReadOK: Boolean;
    AutoBase: Boolean;
    Created,Installing,Updating: Boolean;

procedure Text(Window: HWnd; const S: string);
var B: array[0..255] of Char;
begin
  StrPCopy(B,S); SetWindowText(Window,B);
end;

function Value(Window: HWnd): string;
var B: array[0..255] of Char;
begin
  GetWindowText(Window,B,SizeOf(B)); Result := StrPas(B);
end;

procedure Notice(const S: string; Flags: Word);
var B: array[0..255] of Char;
begin
  StrPCopy(B,S); MessageBox(Wnd,B,'Audigy Setup',Flags);
end;

function Control(ClassName,Caption: PChar; Style: LongInt;
                 X,Y,W,H: Integer; ID: Word): HWnd;
begin
  Result := CreateWindow(ClassName,Caption,WS_CHILD or WS_VISIBLE or Style,
                         X,Y,W,H,Wnd,ID,HInstance,nil);
  if Result=0 then Created := False;
end;

function Card: Word;
var Index: LongInt;
begin
  Result := 0; Index := SendMessage(CardBox,CB_GETCURSEL,0,0);
  if (Index>=0) and (Index<CardCount) then Result := Cards[Word(Index)];
end;

function MemoryMB(var MB: LongInt): Boolean;
var Error: Integer;
begin
  if WindowsMemoryKnown then begin
    MB := DetectedWindowsMB; Result := True;
  end else begin
    Result := False; MB := 0; if XMSEdit=0 then Exit;
    Val(Value(XMSEdit),MB,Error);
    Result := (Error=0) and (MB>=1) and (MB<=2046);
  end;
end;

function Numbers(var Base,XMS: LongInt): Boolean;
var Error: Integer;
begin
  Result := False; Val(Value(BaseEdit),Base,Error);
  if Error<>0 then Exit;
  Result := MemoryMB(XMS);
end;

function BlankText(const S: string): Boolean;
var I: Word;
begin
  Result := True;
  for I:=1 to Length(S) do
    if not (S[I] in [' ',#9]) then begin Result := False; Exit; end;
end;

function BaseIsBlank: Boolean;
begin
  Result := BlankText(Value(BaseEdit));
end;

function SuggestedText: string;
var Base,MB: LongInt;
begin
  Result := UnknownBaseText;
  if Card=0 then Exit;
  if MemoryMB(MB) then
    if SuggestBase(Paths,Card,MemoryInfo,MB,Base) then Result := '$'+IntToHex(Base,8);
end;

procedure RememberBase;
var S: string;
    Base: LongInt;
    Error: Integer;
begin
  S := Value(BaseEdit); Val(S,Base,Error);
  if (Error=0) and ValidBase(Base) then LastBaseText := '$'+IntToHex(Base,8);
end;

procedure Refresh;
var Base,XMS,Proposal: LongInt;
    S: string;
    Good: Boolean;
begin
  if Updating or Installing or not Created then Exit;
  Good := False;
  if CardCount=0 then S := 'No driver found beside SETUP.EXE.'
  else if not BaseReadOK then S := 'Cannot read the existing driver settings.'
  else if not Numbers(Base,XMS) then begin
    S := 'Enter valid memory settings (see Readme).';
    if MemoryMB(XMS) and (Value(BaseEdit)=UnknownBaseText) then
      S := 'No suitable address found (see Readme).';
  end
  else begin
    Good := CheckBase(Paths,Card,MemoryInfo,Base,XMS,S);
    if not Good then begin
      S := 'Check the memory settings (see Readme).';
      if SuggestBase(Paths,Card,MemoryInfo,XMS,Proposal) then begin
        if MemoryInfo.Method=0 then S := 'Unverified suggestion: $'+IntToHex(Proposal,8)
        else S := 'Suggested PhysicalBase: $'+IntToHex(Proposal,8);
      end;
    end;
  end;
  if Good then begin
    if MemoryInfo.Method=0 then S := 'Installed RAM unknown; verify this address.'
    else if SendMessage(ConfirmBox,BM_GETCHECK,0,0)=0 then
      S := 'Confirm the settings to continue.'
    else S := 'Ready to install.';
  end;
  Text(Status,S);
  EnableWindow(InstallButton,Good and (SendMessage(ConfirmBox,BM_GETCHECK,0,0)<>0));
end;

procedure RestoreBlankBase;
var WasUpdating: Boolean;
    Base,MB: LongInt;
    Error: Integer;
    Reason: string;
begin
  if (BaseEdit=0) or not BaseIsBlank then Exit;
  if MemoryMB(MB) then begin
    Val(LastBaseText,Base,Error);
    if (Error<>0) or not CheckBase(Paths,Card,MemoryInfo,Base,MB,Reason) then
      LastBaseText := SuggestedText;
  end else if BlankText(LastBaseText) then LastBaseText := UnknownBaseText;
  WasUpdating := Updating; Updating := True;
  Text(BaseEdit,LastBaseText);
  Updating := WasUpdating;
  SendMessage(ConfirmBox,BM_SETCHECK,0,0); Refresh;
end;

procedure SelectCard;
var S: string;
begin
  if Card=0 then begin Refresh; Exit; end;
  Updating := True;
  SendMessage(ConfirmBox,BM_SETCHECK,0,0);
  BaseReadOK := CurrentBase(Paths,Card,S);
  AutoBase := BlankText(S);
  if AutoBase then S := SuggestedText;
  LastBaseText := S; Text(BaseEdit,S);
  Updating := False; Refresh;
end;

procedure OpenReadme;
var Name,Folder: array[0..255] of Char;
    Code: THandle;
begin
  if not FileExists(Paths.Source+'README.TXT') then begin
    Notice('README.TXT was not found beside SETUP.EXE.',MB_OK or MB_ICONEXCLAMATION);
    Exit;
  end;
  StrPCopy(Name,Paths.Source+'README.TXT'); StrPCopy(Folder,Paths.Source);
  Code := ShellExecute(Wnd,'open',Name,nil,Folder,SW_SHOWNORMAL);
  if Code<=32 then Notice('Cannot open README.TXT.',MB_OK or MB_ICONEXCLAMATION);
end;

procedure BuildControls;
var D: HWnd;
    I,Selection: Word;
    B: array[0..63] of Char;
    S: string;
begin
  Created := True; Updating := True; LastBaseText := UnknownBaseText;
  D := Control('STATIC','Install driver:',0,12,14,100,20,0);
  CardBox := Control('COMBOBOX','',CBS_DROPDOWNLIST or WS_VSCROLL or WS_TABSTOP,
                     116,10,430,90,IDCard);
  CardCount := 0; Selection := 0;
  for I:=1 to 2 do
    if FileExists(Paths.Source+DriverStem(I)+'.DLL') then begin
      if I=PreferredCard then Selection := CardCount;
      Cards[CardCount] := I; Inc(CardCount);
      S := 'Creative Audigy '+IntToStr(I);
      if I=2 then S := S+' / ZS';
      StrPCopy(B,S); SendMessage(CardBox,CB_ADDSTRING,0,LongInt(@B));
    end;
  if CardCount<>0 then SendMessage(CardBox,CB_SETCURSEL,Selection,0);
  if BannerSpace<>0 then begin
    HardwareBanner := Control('STATIC','',SS_LEFT,12,42,534,40,0);
    if HardwareStatus=ProbeNone then
      Text(HardwareBanner,'No supported Audigy card detected. '+
           'The driver will not load if a compatible card cannot be detected.')
    else
      Text(HardwareBanner,'Could not verify Audigy hardware.');
  end;
  D := Control('STATIC','',0,12,44+BannerSpace,534,20,0);
  Text(D,'Destination: '+Paths.System);
  D := Control('STATIC','',0,12,76+BannerSpace,534,20,0);
  S := 'Detected Physical RAM: ';
  if MemoryInfo.Method=0 then S := S+'Unknown'
  else if MemoryInfo.Top=$7FFFFFFF then S := S+'2048 MB or more'
  else S := S+IntToStr(MemoryInfo.Top div $100000)+' MB';
  Text(D,S);
  if WindowsMemoryKnown then begin
    D := Control('STATIC','',0,12,112+BannerSpace,534,20,0);
    Text(D,'Physical RAM available to Windows: '+IntToStr(DetectedWindowsMB)+' MB');
    XMSEdit := 0;
  end else begin
    D := Control('STATIC',
      'Your current XMS limit, as configured in CONFIG.SYS (MB)',
      0,12,112+BannerSpace,534,20,0);
    XMSEdit := Control('EDIT','',WS_BORDER or WS_TABSTOP or ES_AUTOHSCROLL,
                       188,138+BannerSpace,66,23,IDXMS);
    SendMessage(XMSEdit,EM_LIMITTEXT,4,0);
  end;
  D := Control('STATIC','PhysicalBase:',0,12,146+ExtraHeight,172,20,0);
  BaseEdit := Control('EDIT','$????????',WS_BORDER or WS_TABSTOP or ES_AUTOHSCROLL,
                      188,142+ExtraHeight,140,23,IDBase);
  SendMessage(BaseEdit,EM_LIMITTEXT,10,0);
  ConfirmBox := Control('BUTTON','I confirm the memory settings are correct.',
    BS_AUTOCHECKBOX or WS_TABSTOP,12,176+ExtraHeight,534,24,IDConfirm);
  Status := Control('STATIC','',0,12,208+ExtraHeight,534,20,0);
  D := Control('BUTTON','Readme',WS_TABSTOP,12,242+ExtraHeight,95,27,IDReadme);
  InstallButton := Control('BUTTON','Install',BS_DEFPUSHBUTTON or WS_TABSTOP,
                            346,242+ExtraHeight,95,27,IDOK);
  D := Control('BUTTON','Cancel',WS_TABSTOP,451,242+ExtraHeight,95,27,IDCANCEL);
  Updating := False; SelectCard;
end;

procedure Install;
var Base,XMS: LongInt;
    S: string;
    Success,IconOK: Boolean;
begin
  if Installing or (Card=0) then Exit;
  if not BaseReadOK then begin Refresh; Exit; end;
  RestoreBlankBase;
  if not Numbers(Base,XMS) then Exit;
  if not CheckBase(Paths,Card,MemoryInfo,Base,XMS,S) then begin
    Notice(S,MB_OK or MB_ICONEXCLAMATION); Exit;
  end;
  if SendMessage(ConfirmBox,BM_GETCHECK,0,0)=0 then Exit;
  Installing := True; EnableWindow(Wnd,False);
  try
    try
      Success := InstallCard(Paths,Card,Base,S);
      if Success then begin
        IconOK := False;
        try
          IconOK := InstallMixerIcon(Paths.System);
        except
          { Optional shell integration must not turn an installed driver into a failure. }
          IconOK := False;
        end;
        if not IconOK then
          S := S+' Shortcut not created. Run AUDMIXER.EXE from the Windows SYSTEM folder.';
      end;
    except
      Success := False;
      S := 'Setup could not finish. Check files and backups before restarting Windows.';
    end;
  finally
    EnableWindow(Wnd,True); Installing := False;
  end;
  if Success then begin
    Notice(S,MB_OK or MB_ICONINFORMATION); DestroyWindow(Wnd);
  end else begin Notice(S,MB_OK or MB_ICONEXCLAMATION); Refresh; end;
end;

function SetupProc(Window: HWnd; Message,WParam: Word; LParam: LongInt): LongInt;
  export;
begin
  Result := 0;
  case Message of
    WM_CREATE: begin Wnd := Window; BuildControls; end;
    WM_CTLCOLOR:
      if (HardwareBrush<>0) and (HardwareBanner<>0) and
         (LoWord(LParam)=HardwareBanner) then begin
        SetTextColor(HDC(WParam),WarningWhite);
        SetBkColor(HDC(WParam),WarningRed);
        Result := LongInt(HardwareBrush);
      end else Result := DefWindowProc(Window,Message,WParam,LParam);
    WM_COMMAND: begin
      if WParam=IDCard then begin
        if HiWord(LParam)=CBN_SELCHANGE then SelectCard;
      end else if (WParam=IDBase) or (WParam=IDXMS) then begin
        if not Updating then begin
          if HiWord(LParam)=EN_CHANGE then begin
            SendMessage(ConfirmBox,BM_SETCHECK,0,0);
            if WParam=IDBase then begin AutoBase := False; RememberBase; end;
            if (WParam=IDXMS) and AutoBase then SelectCard else Refresh;
          end else if (WParam=IDBase) and (HiWord(LParam)=EN_KILLFOCUS) then
            RestoreBlankBase;
        end;
      end else if WParam=IDConfirm then Refresh
      else if WParam=IDReadme then OpenReadme
      else if WParam=IDOK then Install
      else if (WParam=IDCANCEL) and not Installing then DestroyWindow(Window);
    end;
    WM_CLOSE: if not Installing then DestroyWindow(Window);
    WM_QUERYENDSESSION: if not Installing then Result := 1;
    WM_DESTROY: begin Wnd := 0; PostQuitMessage(0); end;
  else Result := DefWindowProc(Window,Message,WParam,LParam);
  end;
end;

procedure RunSetup;
var WC: TWndClass;
    ProcInstance: TFarProc;
    Msg: TMsg;
begin
  if HPrevInst<>0 then begin
    MessageBox(0,'Setup is already running. Close it before starting another copy.',
                'Audigy Setup',MB_OK or MB_ICONEXCLAMATION); Exit;
  end;
  if not FindPaths(Paths) then begin
    MessageBox(0,'Cannot locate the Windows or Setup directory.',
                'Audigy Setup',MB_OK or MB_ICONEXCLAMATION); Exit;
  end;
  DetectMemory(MemoryInfo);
  WindowsMemoryKnown := WindowsMemoryMB(DetectedWindowsMB);
  HardwareStatus := ProbeAudigy(Paths,PreferredCard);
  BannerSpace := 0; if HardwareStatus<>ProbeFound then BannerSpace := 48;
  ExtraHeight := BannerSpace; if not WindowsMemoryKnown then Inc(ExtraHeight,30);
  FillChar(WC,SizeOf(WC),0);
  ProcInstance := MakeProcInstance(@SetupProc,HInstance);
  if not Assigned(ProcInstance) then Exit;
  WC.lpfnWndProc := ProcInstance; WC.hInstance := HInstance;
  WC.hIcon := LoadIcon(HInstance,'MAINICON'); WC.hCursor := LoadCursor(0,IDC_ARROW);
  WC.hbrBackground := COLOR_BTNFACE+1; WC.lpszClassName := SetupClass;
  if not RegisterClass(WC) then begin FreeProcInstance(ProcInstance); Exit; end;
  if BannerSpace<>0 then HardwareBrush := CreateSolidBrush(WarningRed);
  Wnd := CreateWindow(SetupClass,'Audigy audio driver Setup 2.0',
    WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX,
    24,12,568,308+ExtraHeight,0,0,HInstance,nil);
  if Wnd<>0 then begin
    if not Created then begin
      Notice('Cannot create Setup controls.',MB_OK or MB_ICONEXCLAMATION);
      DestroyWindow(Wnd);
    end else begin ShowWindow(Wnd,SW_SHOWNORMAL); UpdateWindow(Wnd); end;
    while GetMessage(Msg,0,0,0) do
      if (Wnd=0) or not IsDialogMessage(Wnd,Msg) then begin
        TranslateMessage(Msg); DispatchMessage(Msg);
      end;
  end;
  UnregisterClass(SetupClass,HInstance); FreeProcInstance(ProcInstance);
  if HardwareBrush<>0 then DeleteObject(HardwareBrush);
end;

end.
