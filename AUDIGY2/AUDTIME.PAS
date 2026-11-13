unit AudTime;

{ Native Win16 multimedia timer; callback exported by Audigy2.dll itself.}
{$C FIXED PRELOAD PERMANENT}
interface
uses WinTypes, WinProcs, MMSystem;

const
  WM_AUDTICK = $0400+100;
var
  AudTimerInterval, AudClockMargin: Word;

function AudTimerStart(Window: HWnd; DriverModule: THandle): Boolean;
procedure AudTimerStop(Window: HWnd);
function AudTimerID: Word;

implementation

var
  Callback: TTimeCallBack;
  Timer, Resolution: Word;
  PeriodActive: Boolean;

{$S-} { also called on Delphi's small DLL-exit stack }
procedure AudTimerStop(Window: HWnd);
var Err: Word;
begin
  if Timer<>0 then begin
    Err := timeKillEvent(Timer);
    if Err<>0 then Exit; { Retain the ID for retry; this cannot veto DLL unload. }
    Timer := 0;
  end;
  if PeriodActive then begin
    Err := timeEndPeriod(Resolution);
    PeriodActive := False;
  end;
  { Direct callback only: no USER message queue to drain. }
end;
{$S+}

function AudTimerStart(Window: HWnd; DriverModule: THandle): Boolean;
var Caps: TTimeCaps;
begin
  Result := False;
  AudTimerStop(Window);
  if Timer<>0 then Exit;
  if timeGetDevCaps(@Caps,SizeOf(Caps))<>0 then Exit;
  Resolution := AudClockMargin;
  if Resolution<Caps.wPeriodMin then Resolution := Caps.wPeriodMin;
  if (Resolution>10) or (Resolution>Caps.wPeriodMax) or
     (AudTimerInterval>Caps.wPeriodMax) then Exit;
  AudClockMargin := Resolution;
  if AudTimerInterval<Resolution then AudTimerInterval := Resolution;
  @Callback := GetProcAddress(DriverModule,'TickProc');
  if not Assigned(Callback) then Exit;
  if timeBeginPeriod(Resolution)<>0 then Exit;
  PeriodActive := True;
  Timer := timeSetEvent(AudTimerInterval,Resolution,Callback,LongInt(Window),TIME_PERIODIC);
  if Timer=0 then begin AudTimerStop(Window); Exit; end;
  Result := True;
end;

{$S-} { timer callback reads this resident scalar }
function AudTimerID: Word;
begin
  Result := Timer;
end;
{$S+}

begin
  AudTimerInterval := 5; AudClockMargin := 1;
  Callback := nil; Timer := 0;
  Resolution := 0; PeriodActive := False;
  { Audigy2's ExitProc handler retries cancellation before RTL termination. }
end.
