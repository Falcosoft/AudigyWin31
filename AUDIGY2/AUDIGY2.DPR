library Audigy2;

{ Native Win16 waveOut / waveIn / MIDI driver for Creative Audigy 2/ZS. }
{$C FIXED PRELOAD PERMANENT}
{$G+}
{$F+}
{$W+}
{$R-}
{$Q-}
{$D wave,aux,mixer,midi:Creative Audigy 2}

uses WinTypes, WinProcs, Messages, MMSystem, SysUtils, PCI,
     Aud2HW, AudTime, AudPCM, AudCfg, AudEQ, AudRev, MxTypes;

const
  WODM_GETNUMDEVS=3; WODM_GETDEVCAPS=4; WODM_OPEN=5; WODM_CLOSE=6;
  WODM_PREPARE=7; WODM_UNPREPARE=8; WODM_WRITE=9;
  WODM_PAUSE=10; WODM_RESTART=11; WODM_RESET=12; WODM_GETPOS=13;
  WODM_BREAKLOOP=20;
  WODM_GETVOLUME=16; WODM_SETVOLUME=17;
  WODM_INIT=100;
  MODM_GETNUMDEVS=1; MODM_GETDEVCAPS=2; MODM_OPEN=3; MODM_CLOSE=4;
  MODM_DATA=7; MODM_LONGDATA=8; MODM_RESET=9; MODM_INIT=100;
  MODM_GETVOLUME=10; MODM_SETVOLUME=11;
  MIDICAPS_VOLUME=$0001; MIDICAPS_LRVOLUME=$0002;
  MidiPortName='Audigy 2 MIDI Synth';
  AUD_RETRIES=$4002;
  AUD_PENDING=$4003;
  AUD_STATUS=$4001; { waveOutMessage: 0 healthy, 1 service/start failure }
  QueueMax=256;
  NotifyMax=260;
  MaxHeaderBytes=15000000; { HDA2 DRVPRC allocates this stream capacity }
  MxFMVolume=19; MxFMFader=20;
  MxControlCount=MxFMFader;
  OplFifoFrames=8192; { stereo PCM frames in the resident FIFO }
{$I OPLMABI.INC}

type
  { DDK-only record, same 14-byte Win16 layout as the existing HDA2. }
  TWaveOpenDesc=packed record
    hWave: Word;
    lpWaveFormat: PWaveFormat;
    Callback, Instance: LongInt;
  end;
  PWaveOpenDesc=^TWaveOpenDesc;
  TMidiOpen16=packed record
    Device: Word;
    Callback, Instance: LongInt;
  end;
  PMidiOpen16=^TMidiOpen16;
  PLongValue=^LongInt;
  PByteValue=^Byte;
  TOplFrame=packed record Left,Right: Integer; end;
  TOplFrames=array[0..OplFifoFrames-1] of TOplFrame;
  POplFrames=^TOplFrames;
  TOplCore=function(Command,Value: Word; Data: LongInt): Word;
  TOplBlock=array[0..127] of TOplFrame;
  TSignalWords=array[0..11999] of Integer;
  PSignalWords=^TSignalWords;
  TQueueEntry=record
    Header: PWaveHdr;
    Data: PChar;
    Size, Copied, FedBytes, StartPos, EndPos, LoopsLeft: LongInt;
    Looped: Boolean;
  end;
  TLogLine=string[159];
  TNotification=record
    Callback, Flags, Instance, Param: LongInt;
    Device, Message: Word;
  end;

type
  TOutputState=record
    Opened, Failed, StartPending, Paused, Suspended: Boolean;
    DisableOutputPaused: Boolean;
    Client: TWaveOpenDesc;
    ClientFlags, Cookie, AcceptedTotal, DoneBytes: LongInt;
    LastCursor, ProgressTick, CurrentRate, HardwareRate: LongInt;
    SourceBits, SourceChannels, SourceAlign, TimerFault: Word;
    AcceptedFrames: LongInt;
    Notes: array[0..NotifyMax-1] of TNotification;
    NoteHead, NoteTail, NoteCount, NotePeak: Word;
    RetryCount, DeliveredCount: LongInt;
    Queue: array[0..QueueMax-1] of TQueueEntry;
    Head, Tail, Count: Word;
    DrainPending: Boolean;
    SignalFrames, SignalPeak: LongInt;
    DrainEndPos, FirstSignalMS, FirstDoneMS, StreamStartTick: LongInt;
    FillCalls, PrimeShortFills: LongInt;
    RunShortFills, RunEmptyFills: LongInt;
    StreamWrites, EmptyQueueWrites, RecoveredGaps: LongInt;
    FirstRunGapMS, LastRunGapMS: LongInt;
    RunGapPending: Boolean;
  end;
  POutputState=^TOutputState;

{$I WINDEFS.INC}

var
  { Both clients are resident driver-owned allocations, never task-owned. }
  Outputs: array[0..1] of POutputState;
  OutputMemory: array[0..1] of THandle;
  OutputSelector: array[0..1] of Word;
  Output: POutputState;
  CurrentOutput: Word;
  Enabled, Busy: Boolean;
  { Two public WaveOut controls plus the private FM speaker mix. }
  Volume,HardwareVolume: array[0..2] of LongInt;
  VolumeDirty,VolumePending,HardwareVolumeValid: array[0..2] of Boolean;
  FMFader: Word;
  FMFaderDirty: Boolean;
  ResidentSelectors: array[0..7] of Word;
  ResidentCount: Word;
  TimerActive, DriverDisabled, DriverExiting, DisableInputRunning: Boolean;
  PreviousExit: Pointer;
  DebugEnabled: Boolean;
  DriverDir, IniName, LogName: string;
  LogLines: array[0..127] of TLogLine;
  LogCount, LogFirst: Word;
  LogDropped, LogFlushing, ShutdownWorkaround: Boolean;
  InputState: PInputState;
  InputMemory: THandle;
  InputSelector: Word;
  InputOpened: Boolean;
  InputCookie: LongInt;
  ActiveSettings, SavedSettings, RequestedSettings: TAudSettings;
  ConfigPending, ConfigNeedsSave, ConfigInputValid: Boolean;
  ConfigError: Word;
  MonitorPending, MonitorDirty, MonitorFault, MonitorSaving, ConfigSaving: Boolean;
  RequestedEQ: TEqProgram;
  EQChanged, RevChanged: Boolean;
  OplFIFO: POplFrames;
  OplMemory,OplOwner: THandle;
  OplSelector,OplRead,OplWrite,OplCount: Word;
  OplStarting,OplRunning,OplStopping,OplFailed: Boolean;
  OplGapCovered: LongInt;
  OplFirstFaultStage,OplFirstFaultCode: Word;
  OplFirstFaultValue: LongInt;
  OplRecoveryTried: Boolean;
  OplRefillMark,OplSilenceMark,OplRecoveryTick: LongInt;
  OplRecoveryAttempts,OplRecoveryFrames,OplRecoveryRetries: LongInt;
  OplGapPending,OplGapTried: Boolean;
  OplGapRetryTick,OplGapFaults,OplGapReprimes: LongInt;
  MidiEvents: POplEventQueue;
  MidiConfigured,MidiLaunching,MidiFault,MidiRetired,ResourcesLoaded: Boolean;
  MidiCore: TOplCore;
  MidiCoreDLL: THandle;
  MidiCoreCode,MidiCoreData: Word;
  MidiCoreReady,MidiRenderOwned,MidiHaveEvent: Boolean;
  MidiRenderEpoch,MidiEpochTick,MidiRendered,MidiSent: LongInt;
  MidiFullResetPending: Boolean;
  MidiFramesPer10MS, MidiPrimeFrames: Word;
  MidiHourFrames, MidiStarvedBytes: LongInt;
  MidiRenderEvent: TOplEvent;
  MidiBlock: TOplBlock;
  MidiRenderCalls,MidiRenderMaxMS,MidiRenderLastTick,MidiRenderMaxGap: LongInt;
  MidiEventMaxAge,MidiRenderSamples: LongInt;
  MidiCookie,MidiEpoch,MidiCallback,MidiInstance: LongInt;
  MidiHead,MidiTail,MidiHandle,MidiFlags: Word;
  MidiDiag: TOplDiag;

{$I MXSTATE.INC}

{ DriverCallback is a DDK export absent from the user's MMSystem DCU.
  Keep its original API name. This is the HDA2 Win16 import signature. }
function DriverCallback(dwCallback: LongInt; uFlags, hDevice,
  uMessage: Word; dwUser, Param1, Param2: LongInt): Boolean;
  external 'MMSYSTEM' name 'DriverCallback';

function EnsureMidiCore: Boolean; forward;
procedure ReleaseMidiCore; forward;
procedure MidiRendererLog; forward;

{$S-}
procedure CachePlaybackVolume(Device: Word; Value: LongInt); forward;

procedure SelectOutput(Device: Word);
begin
  CurrentOutput := Device;
  Output := Outputs[Device];
  AudSelectPlayback(Device);
end;

function AnyOutputActive: Boolean;
var I: Word;
begin
  Result := AudAnyStreaming;
  for I:=0 to 1 do
    if Outputs[I]<>nil then
      if Outputs[I]^.Opened then Result := True;
end;
{$S+}

{$I OPLPIPE.INC}
{$I OPLMIDI.INC}

procedure OutputsFree;
var I: Word;
begin
  for I:=0 to 1 do begin
    if OutputSelector[I]<>0 then GlobalPageUnlock(OutputSelector[I]);
    OutputSelector[I] := 0;
    if OutputMemory[I]<>0 then begin
      if Outputs[I]<>nil then GlobalUnlock(OutputMemory[I]);
      GlobalFree(OutputMemory[I]);
    end;
    Outputs[I] := nil; OutputMemory[I] := 0;
  end;
  Output := nil; CurrentOutput := 0; AudSelectPlayback(0);
end;

function OutputsAllocate: Boolean;
var I: Word;
begin
  Result := False;
  for I:=0 to 1 do begin
    OutputMemory[I] := GlobalAlloc(GMEM_MOVEABLE or GMEM_SHARE or GMEM_ZEROINIT,
                                  LongInt(SizeOf(TOutputState)));
    if OutputMemory[I]=0 then begin OutputsFree; Exit; end;
    Outputs[I] := GlobalLock(OutputMemory[I]);
    if Outputs[I]=nil then begin OutputsFree; Exit; end;
    OutputSelector[I] := HiWord(GlobalHandle(Seg(Outputs[I]^)));
    if OutputSelector[I]=0 then begin OutputsFree; Exit; end;
    if GlobalPageLock(OutputSelector[I])=0 then begin
      OutputSelector[I] := 0; OutputsFree; Exit;
    end;
    with Outputs[I]^ do begin
      Cookie := $41554431+I;
      CurrentRate := 48000;
      SourceBits := 16; SourceChannels := 2; SourceAlign := 4;
      DrainEndPos := -1; FirstSignalMS := -1; FirstDoneMS := -1;
      FirstRunGapMS := -1; LastRunGapMS := -1;
    end;
  end;
  SelectOutput(0);
  Result := True;
end;

procedure ReleaseResident;
begin
  while ResidentCount<>0 do begin
    Dec(ResidentCount);
    GlobalPageUnlock(ResidentSelectors[ResidentCount]);
  end;
end;

function LockResidentPointer(Address: Pointer): Boolean;
var S,I: Word;
begin
  Result := False;
  { Use the object's canonical selector, including for code aliases. }
  S := HiWord(GlobalHandle(Seg(Address^)));
  if S=0 then Exit;
  I := 0;
  while I<ResidentCount do begin
    if ResidentSelectors[I]=S then begin Result := True; Exit; end;
    Inc(I);
  end;
  if ResidentCount>=8 then Exit;
  if GlobalPageLock(S)=0 then Exit;
  ResidentSelectors[ResidentCount] := S; Inc(ResidentCount);
  Result := True;
end;

{$S-} { normalized huge-pointer arithmetic is also used by the timer }
function DataPointer(Data: PChar; Offset: LongInt): Pointer;
var Address: LongInt;
begin
  Address := LongInt(Ofs(Data^))+Offset;
  Result := Ptr(Word(LongInt(Seg(Data^))+
                (Address shr 16)*LongInt(SelectorInc)),Word(Address));
end;
{$S+}

{$S-} { interrupt path: no task-stack RTL check }
function NextIndex(I: Word): Word;
begin
  Result := (I+1) mod QueueMax;
end;

{$S+}
procedure FreeQueueData(I: Word);
begin
  with Output^ do begin
    { MMSYSTEM owns the prepared client block and its memory locks.
      HDA2 also keeps the caller's header/data until it is consumed.
      Never free/unlock application allocations when returning a header. }
    Queue[I].Data := nil;
  end;
end;

procedure DriverLog(const S: string); far;
begin
  if not DebugEnabled then Exit;
  if LogCount<128 then begin
    LogLines[(LogFirst+LogCount) mod 128] := S;
    Inc(LogCount);
  end else begin
    { Keep the latest diagnostics, including errors after a long game. }
    LogLines[LogFirst] := S; LogFirst := (LogFirst+1) mod 128;
    LogDropped := True;
  end;
end;

procedure FlushLog;
var F: Text;
    I: Word;
    Err: Integer;
begin
  if not DebugEnabled or LogFlushing or TimerActive or AudAnyStreaming then Exit;
  if LogCount=0 then Exit;
  LogFlushing := True;
  {$I-}
  Assign(F,LogName); Append(F); Err := IOResult;
  if Err<>0 then begin Rewrite(F); Err := IOResult; end;
  if Err=0 then begin
    if LogCount<>0 then
      for I:=0 to LogCount-1 do WriteLn(F,LogLines[(LogFirst+I) mod 128]);
    if LogDropped then WriteLn(F,'Earlier diagnostic lines were overwritten.');
    Close(F); Err := IOResult;
  end;
  {$I+}
  LogCount := 0; LogFirst := 0; LogDropped := False;
  LogFlushing := False;
end;

{ Start every driver session with a fresh diagnostic/workaround file. }
procedure ResetLogFile;
var F: Text;
    Err: Integer;
begin
  if LogFlushing or TimerActive then Exit;
  LogFlushing := True;
  LogCount := 0; LogFirst := 0; LogDropped := False;
  {$I-}
  Assign(F,LogName); Rewrite(F); Err := IOResult;
  if Err=0 then begin Close(F); Err := IOResult; end;
  {$I+}
  LogFlushing := False;
end;

{ This is the tested shutdown compatibility workaround. It deliberately
  performs the same minimal append/create/write/close operation that made
  shutdown reliable, without enabling the normal diagnostic machinery. }
procedure ApplyShutdownWorkaround;
var F: Text;
    Err: Integer;
begin
  if not ShutdownWorkaround or DebugEnabled or AudAnyStreaming then Exit;
  if LogFlushing or TimerActive then Exit;
  LogFlushing := True;
  {$I-}
  Assign(F,LogName); Append(F); Err := IOResult;
  if Err<>0 then begin Rewrite(F); Err := IOResult; end;
  if Err=0 then begin
    Write(F,'.'); Err := IOResult;
    Close(F); Err := IOResult;
  end;
  {$I+}
  LogFlushing := False;
end;

{$S-} { resident notification snapshot; no USER or RTL calls }
procedure Enqueue(Kind: Word; Header: PWaveHdr);
begin
  with Output^ do begin
    if (HiWord(ClientFlags) and 7)=0 then Exit; { CALLBACK_NULL needs no post }
    { Admission bounds Count+NoteCount to QueueMax, leaving control slots.
      No client header is dereferenced later by this notification queue. }
    if NoteCount>=NotifyMax then begin
      Failed := True; TimerFault := 3;
      Exit;
    end;
    with Notes[NoteTail] do begin
      Callback := Client.Callback; Flags := ClientFlags;
      Instance := Client.Instance; Device := Client.hWave;
      Notes[NoteTail].Message := Kind; Param := LongInt(Header);
    end;
    NoteTail := (NoteTail+1) mod NotifyMax; Inc(NoteCount);
    if NoteCount>NotePeak then NotePeak := NoteCount;
  end;
end;

{$S+}
procedure PumpNotifications;
var N: Word;
    OK: Boolean;
begin
  with Output^ do begin
    N := 0;
    { Drain every available notification, bounded by the private FIFO size.
      A failed delivery still stops here and is retried after yielding. }
    while (NoteCount<>0) and (N<NotifyMax) do begin
      with Notes[NoteHead] do begin
        if ((HiWord(Flags) and 7)=1) and
           not IsWindow(HWnd(Word(Callback))) then begin
          { The client destroyed its callback window. Retire the orphan
            rather than calling through stale client storage or waiting
            forever for a window that no longer exists. }
          DriverLog('NOTIFY: client callback window no longer exists.');
          OK := True;
        end else begin
          OK := DriverCallback(Callback,HiWord(Flags) or $0008,
                               Device,Message,Instance,Param,0);
        end;
      end;
      if not OK then begin
        Inc(RetryCount);
        { Stop at the first failure, keeping FIFO order and this record.
          The fixed DLL's next timer notification retries after yielding. }
        Break;
      end;
      NoteHead := (NoteHead+1) mod NotifyMax; Dec(NoteCount);
      Inc(DeliveredCount); Inc(N);
    end;
  end;
end;

{$S-}
procedure PumpTimerNotifications;
var N: Word;
    OK: Boolean;
begin
  with Output^ do begin
    N := 0;
    { HDA2 UNIT2.waveCallback is called from WWRITE's timer progression.
      Use the same DDK DriverCallback/DCB_NOSWITCH path here. No IsWindow,
      heap operations, formatting or file I/O occur in this routine. }
    while (NoteCount<>0) and (N<NotifyMax) do begin
      with Notes[NoteHead] do begin
        OK := DriverCallback(Callback,HiWord(Flags) or $0008,
                             Device,Message,Instance,Param,0);
      end;
      if not OK then begin Inc(RetryCount); Break; end;
      NoteHead := (NoteHead+1) mod NotifyMax; Dec(NoteCount);
      Inc(DeliveredCount); Inc(N);
    end;
  end;
end;

function ReturnHeadIRQ: Boolean;
var P: PWaveHdr;
begin
  with Output^ do begin
    Result := False;
    P := Queue[Head].Header;
    Queue[Head].Data := nil;
    if Queue[Head].EndPos>DrainEndPos then DrainEndPos := Queue[Head].EndPos;
    if DebugEnabled and (FirstDoneMS<0) then
      FirstDoneMS := timeGetTime-StreamStartTick;
    DoneBytes := DoneBytes+Queue[Head].FedBytes;
    Queue[Head].Header := nil;
    Head := NextIndex(Head); Dec(Count);
    P^.dwFlags := (P^.dwFlags and not LongInt(WHDR_INQUEUE)) or WHDR_DONE;
    Enqueue(WOM_DONE,P);
    Result := True;
  end;
end;
{$S+}

procedure LogNumber(const LabelText: string; Value: LongInt);
var N: string[16];
begin
  Str(Value,N); DriverLog(LabelText+N);
end;

procedure ReportFormat;
begin
  with Output^ do begin
    LogNumber('FORMAT: rate=',CurrentRate);
    LogNumber('FORMAT: bits=',SourceBits);
    LogNumber('FORMAT: channels=',SourceChannels);
    LogNumber('CALLBACK: flags=',ClientFlags);
  end;
end;

procedure ReportNotifications;
begin
  with Output^ do begin
    DriverLog('NOTIFY: delivered='+IntToStr(DeliveredCount)+
              ' retries='+IntToStr(RetryCount)+
              ' pending='+IntToStr(NoteCount)+' peak='+IntToStr(NotePeak));
  end;
end;

{$S-} { also called by resident timer startup }
procedure ResetGapStats;
begin
  with Output^ do begin
    FillCalls := 0;
    PrimeShortFills := 0;
    RunShortFills := 0; RunEmptyFills := 0;
    StreamWrites := 0; EmptyQueueWrites := 0; RecoveredGaps := 0;
    FirstRunGapMS := -1; LastRunGapMS := -1;
    RunGapPending := False;
  end;
end;

{$S+}
procedure ReportGapStats;
begin
  with Output^ do begin
    DriverLog('SUPPLY: calls='+IntToStr(FillCalls)+
              ' prime_short='+IntToStr(PrimeShortFills));
    DriverLog('SUPPLY: run_short='+IntToStr(RunShortFills)+
              ' run_empty='+IntToStr(RunEmptyFills));
    DriverLog('QUEUE: stream_writes='+IntToStr(StreamWrites)+
              ' empty_queue_writes='+IntToStr(EmptyQueueWrites)+
              ' recovered_gaps='+IntToStr(RecoveredGaps));
    DriverLog('GAP: first_ms='+IntToStr(FirstRunGapMS)+
              ' last_ms='+IntToStr(LastRunGapMS));
  end;
end;

procedure ReturnHead;
var P: PWaveHdr;
begin
  with Output^ do begin
    P := Queue[Head].Header;
    FreeQueueData(Head);
    if Queue[Head].EndPos>DrainEndPos then DrainEndPos := Queue[Head].EndPos;
    if DebugEnabled and (FirstDoneMS<0) then
      FirstDoneMS := timeGetTime-StreamStartTick;
    DoneBytes := DoneBytes+Queue[Head].FedBytes;
    Queue[Head].Header := nil;
    Head := NextIndex(Head); Dec(Count);
    P^.dwFlags := (P^.dwFlags and not LongInt(WHDR_INQUEUE)) or WHDR_DONE;
    { State is committed before callback. Busy prevents callback reentry
      into wave APIs; Win16 function callbacks must not call wave functions. }
    Enqueue(WOM_DONE,P);
  end;
end;

{$S-} { integer-only signal diagnostics on resident output, Debug1 only }
procedure MeasurePCM(Data: Pointer; Frames: Word);
var I: Word;
    L,R: LongInt;
begin
  with Output^ do begin
    for I:=0 to Frames-1 do begin
      L := PSignalWords(Data)^[I*2]; R := PSignalWords(Data)^[I*2+1];
      if (L<>0) or (R<>0) then begin
        if FirstSignalMS<0 then FirstSignalMS := timeGetTime-StreamStartTick;
        Inc(SignalFrames);
      end;
      if L<0 then L := -L;
      if R<0 then R := -R;
      if L>SignalPeak then SignalPeak := L;
      if R>SignalPeak then SignalPeak := R;
    end;
  end;
end;
{$S+}

{$S-} { interrupt path: no task-stack RTL check }
function SupplyPCM(Destination: Pointer; Bytes: Word;
                   OutputOffset: LongInt): Word; far;
var I, K, RemainingEntries, Used, Frames, SourceBytes, OutputBytes: Word;
    BoundaryFrame: array[0..3] of Byte;
    StepsLeft: Word;
    AvailableFrames, WindowFrames: LongInt;
    Source, Dest: Pointer;
begin
  with Output^ do begin
    { Like HDA2, consume the prepared application's PCM as playback needs
      it, rather than snapshotting every queued block at waveOutWrite.
      Generic MMSYSTEM preparation retains the header/data memory locks.
      No allocations or kernel copies are performed on the timer stack.
      Counters remain in ORIGINAL source bytes, regardless of expansion. }
    Result := 0;
    { The selected output's ring still recycles silence while paused. }
    if Paused then Exit;
    Used := 0; I := Head; RemainingEntries := Count;
    { Each pass must consume at least one output frame or retire one entry.
      Bound even damaged queue state; never spin on the interrupt stack. }
    StepsLeft := QueueMax+(Bytes div 4);
    while (RemainingEntries<>0) and (Used<Bytes) do begin
      if StepsLeft=0 then begin Failed := True; TimerFault := 4; Exit; end;
      Dec(StepsLeft);
      with Queue[I] do begin
        if Copied<Size then begin
          AvailableFrames := (Size-Copied) div SourceAlign;
          Source := DataPointer(Data,Copied);
          Frames := (Bytes-Used) div 4;
          if AvailableFrames<LongInt(Frames) then Frames := Word(AvailableFrames);
          WindowFrames := (65536-LongInt(Ofs(Source^))) div SourceAlign;
          if WindowFrames<LongInt(Frames) then Frames := Word(WindowFrames);
          if Frames=0 then begin
            { One frame can straddle a 64 KiB selector when the client's
              original data pointer is unaligned. Normalize each byte. }
            for K:=0 to SourceAlign-1 do
              BoundaryFrame[K] := PByteValue(DataPointer(Data,Copied+K))^;
            Source := @BoundaryFrame; Frames := 1;
          end;
          SourceBytes := Word(LongInt(Frames)*SourceAlign);
          OutputBytes := Word(LongInt(Frames)*4);
          if StartPos<0 then StartPos := OutputOffset+LongInt(Used);
          Dest := Ptr(Seg(Destination^),Word(LongInt(Ofs(Destination^))+Used));
          PCMExpand(Source,Dest,Frames,SourceBits,SourceChannels);
          if DebugEnabled then MeasurePCM(Dest,Frames);
          Inc(Copied,LongInt(SourceBytes));
          Inc(FedBytes,LongInt(SourceBytes)); Inc(Used,OutputBytes);
          if Copied=Size then begin
            if LoopsLeft<>1 then begin
              { -1 is the conventional endless loop count. Other counts
                use all 32 bits; do not truncate dwLoops to a Word. }
              if LoopsLeft<>-1 then Dec(LoopsLeft);
              Copied := 0;
            end else EndPos := OutputOffset+LongInt(Used);
          end;
        end else if (Size=0) and (EndPos<0) then begin
          StartPos := OutputOffset+LongInt(Used); EndPos := StartPos;
        end;
      end;
      { A looping packet stays queued until its final iteration drains.
        Empty packets always finish once, avoiding an interrupt-time spin. }
      if Queue[I].EndPos>=0 then begin
        I := NextIndex(I); Dec(RemainingEntries);
      end;
    end;
    { Only these bytes became PCM. The backend may retry the still-empty
      suffix at the same output offset, without consuming source twice. }
    Result := Used;
    Inc(FillCalls);
    { These are unfilled REQUEST counts, including retries of pending bytes.
      Actual expired silence is accounted once by AUD2HW's DEADLINE report. }
    if Used<Bytes then begin
      if AudIsStreaming then begin
        Inc(RunShortFills);
        if Used=0 then Inc(RunEmptyFills);
        if FirstRunGapMS<0 then
          FirstRunGapMS := timeGetTime-StreamStartTick;
        LastRunGapMS := timeGetTime-StreamStartTick;
        RunGapPending := True;
      end else begin
        Inc(PrimeShortFills);
      end;
    end;
  end;
end;

{$S+}
function CurrentBytes: LongInt;
var I, Left: Word;
begin
  with Output^ do begin
    { HDA2 WODMESSA reports LByteCount, advanced when source PCM is read
      into DMA (WWRITE/updatepos). Keep that source-consumption clock
      separate from our deliberately delayed safe-completion cursor.
      A live synth needs the consumption position to render far enough
      ahead; subtracting a whole ring here can leave it writing too late. }
    Result := DoneBytes;
    I := Head; Left := Count;
    while Left<>0 do begin
      Result := Result+Queue[I].FedBytes;
      I := NextIndex(I); Dec(Left);
    end;
  end;
end;

procedure StopEngine;
begin
  with Output^ do begin
    StartPending := False; DrainEndPos := -1;
    { HDA2 keeps its multimedia event from DRV_LOAD through DRV_FREE.
      Reset stops voices; Close lets the copied DMA tail finish. }
    AudStop;
  end;
end;

procedure ReportSignal;
begin
  with Output^ do begin
    if not DebugEnabled then Exit;
    LogNumber('SIGNAL: nonzero_frames=',SignalFrames);
    LogNumber('SIGNAL: peak_pcm=',SignalPeak);
    LogNumber('TIMING: first_nonzero_supplied_ms=',FirstSignalMS);
    LogNumber('TIMING: first_buffer_return_ms=',FirstDoneMS);
    ReportGapStats;
  end;
end;

procedure AbortQueue(const Reason: string);
begin
  with Output^ do begin
    StopEngine;
    DriverLog(Reason);
    if DebugEnabled then ReportSignal;
    if DebugEnabled or Failed or (TimerFault<>0) then AudDump;
    while Count<>0 do ReturnHead;
    Head := 0; Tail := 0;
  end;
end;

procedure SaveVolume; forward;
procedure ApplyVolume; forward;

procedure TaskMaintenance;
begin
  with Output^ do begin
    { Called with Busy set by the normal wave API entry. There is no
      worker window or private allocation attached to a queued header. }
    if not AnyOutputActive and not InputOpened then begin
      SaveVolume;
      if DebugEnabled and not AudIsStreaming then FlushLog;
    end;
    if DrainPending then begin
      DrainPending := False;
      if DebugEnabled then begin
        DriverLog('DRAIN: timer completed all queued headers.');
        ReportSignal; AudDump;
      end;
    end;
    if TimerFault<>0 then begin
      if TimerFault=2 then
        AbortQueue('FAIL: hardware cursor stalled for one second.')
      else if TimerFault=4 then
        AbortQueue('FAIL: PCM refill made no bounded progress.')
      else if TimerFault=5 then
        AbortQueue('FAIL: hardware could not start.')
      else
        AbortQueue('FAIL: stream service stopped; pending headers returned.');
      TimerFault := 0;
    end else if AudIsStreaming then begin
      { HDA2 returns a header after consuming its final source byte into
        DMA. The card owns that copy; the caller may now refill its block. }
      while Count<>0 do begin
        if Queue[Head].EndPos<0 then Break;
        ReturnHead;
      end;
      if not Paused and (Count=0) and (DrainEndPos>=0) and
         (AudPlayedThrough>=DrainEndPos) then begin
        StopEngine;
        if DebugEnabled then begin
          DriverLog('DRAIN: queue empty; completed_bytes='+IntToStr(DoneBytes));
          ReportSignal; AudDump;
        end;
      end;
    end;
  end;
end;

{$S-} { caller owns TimerActive/Busy; no task operations during startup }
procedure StartEngineIRQ;
begin
  with Output^ do begin
    if not StartPending then Exit;
    StartPending := False;
    if not Opened or Failed or Paused or (Count=0) or AudIsStreaming then Exit;
    SignalFrames := 0; SignalPeak := 0;
    FirstSignalMS := -1; FirstDoneMS := -1; DrainEndPos := -1;
    StreamStartTick := timeGetTime;
    ResetGapStats;
    AudStart;
    LastCursor := AudPosition; ProgressTick := timeGetTime;
    if Failed or not AudIsStreaming then begin
      AudStop; Failed := True;
      if TimerFault=0 then TimerFault := 5;
    end;
  end;
end;
{$S+}

{$I WAVEIN.INC}

{$S-} { interrupt callback uses the multimedia timer's stack }
{$S-}
procedure ServiceOutputIRQ;
var Cursor,Now: LongInt;
begin
  with Output^ do begin
    if StartPending then StartEngineIRQ;
    if AudIsStreaming then begin
      if not AudService then begin
        Failed := True; TimerFault := 1;
      end else begin
        Cursor := AudPosition; Now := timeGetTime;
        if Cursor<>LastCursor then begin
          LastCursor := Cursor; ProgressTick := Now;
        end else if Now-ProgressTick>=1000 then begin
          AudStop; Failed := True; TimerFault := 2;
        end;
      end;
    end;
    { Return completion even when USER dispatch is blocked, including a
      synchronous sndPlaySound caller. This follows HDA2's timer path. }
    if AudIsStreaming then begin
      while Count<>0 do begin
        if Queue[Head].EndPos<0 then Break;
        if not ReturnHeadIRQ then begin AudStop; Break; end;
      end;
      if not Paused and (Count=0) and (DrainEndPos>=0) and
         (AudPlayedThrough>=DrainEndPos) then begin
        StartPending := False; AudStop; DrainEndPos := -1;
        DrainPending := True;
      end;
    end;
    if TimerFault<>0 then begin
      AudStop;
      while Count<>0 do
        if not ReturnHeadIRQ then Break;
    end;
    PumpTimerNotifications;
  end;
end;
{$S+}

{$I OPLREND.INC}

{$S-} { separate helper above must not re-enable checks on the timer entry }
procedure TickProc(TimerID,Msg: Word; User,DW1,DW2: LongInt); export;
var I: Word;
    SavedBusy: Boolean;
begin
  if not Enabled or DriverExiting then Exit;
  if (TimerID=0) or (TimerID<>AudTimerID) or TimerActive then Exit;
  if Busy then Exit;
  TimerActive := True;
  SavedBusy := Busy; Busy := True;
  ApplyConfigIRQ;
  if MonitorPending then begin
    MonitorFault := not AudMonitorConfigure(ActiveSettings.Source,ActiveSettings.MonitorSource,
      ActiveSettings.InputLevel,
      ActiveSettings.SourceLevel,ActiveSettings.MonitorOn,ActiveSettings.MonitorVolume);
    MonitorPending := False;
  end;
  { Match HDA2's working cached software-volume path: WODM_SETVOLUME
    never performs device I/O on the caller/MMTASK stack.  Serialize
    Audigy's indexed DSP writes here, before any client callback. }
  ApplyVolume; { cached per-device gains; hardware writes only when changed }
  { Like HDA2, queued writes are consumed by the resident timer. Startup
    runs only after the wave entry releases Busy; no USER kick is needed. }
  if InputOpened then InputService;
  { Give the FM DMA refill its slot before WaveOut client callbacks.
    Rendering new FM samples still runs after WaveOut. }
  OplServiceIRQ;
  for I:=0 to 1 do begin
    SelectOutput(I);
    ServiceOutputIRQ;
  end;
  MidiRenderIRQ;
  SelectOutput(0);
  InputPumpTimer;
  Busy := SavedBusy; TimerActive := False;
end;
{$S+}

function LockResident: Boolean;
begin
  Result := False;
  if ResidentCount<>0 then begin Result := True; Exit; end;
  { SysUtils and System share the runtime code segment in the supplied
    Delphi 1 MAP; lock it too for integer arithmetic helper routines. }
  if not LockResidentPointer(@Output) or
     not LockResidentPointer(@TickProc) or
     not LockResidentPointer(@AudService) or
     not LockResidentPointer(@AudStart) or
     not LockResidentPointer(@PCMExpand) or
     not LockResidentPointer(@AudTimerID) or
     not LockResidentPointer(@IntToStr) then begin
    ReleaseResident; Exit;
  end;
  Result := True;
end;

function StartDriverTimer: Boolean;
begin
  Result := False;
  if AudTimerID<>0 then begin Result := True; Exit; end;
  if (GetWinFlags and WF_ENHANCED)=0 then Exit;
  if not LockResident then begin
    DriverLog('FAIL: could not page-lock timer code/data.'); FlushLog; Exit;
  end;
  { Install at load, before wave opens; re-install after DRV_ENABLE only
    if DRV_DISABLE cancelled it. No per-open event or task window. }
  if not AudTimerStart(0,HInstance) then begin
    DriverLog('FAIL: driver-lifetime multimedia event could not start.');
    ReleaseResident; FlushLog; Exit;
  end;
  DriverLog('DRIVER: resident multimedia timer installed.'); FlushLog;
  Result := True;
end;

function DisableDriver: Boolean;
var SavedBusy: Boolean;
    I: Word;
begin
  SavedBusy := Busy; Busy := True;
  Enabled := False;
  if not DriverDisabled then begin
    DriverDisabled := True;
    DisableInputRunning := False;
    MidiFullResetPending := True;
    MidiInvalidate;
    OplDisable;
    for I:=0 to 1 do begin
      SelectOutput(I);
      with Output^ do begin
        DisableOutputPaused := False;
        if AudIsStreaming then begin
          DisableOutputPaused := AudPause;
          if not DisableOutputPaused then begin
            AudStop; Failed := True; TimerFault := 1;
          end;
        end;
      end;
    end;
    SelectOutput(0);
    if InputOpened and (InputState<>nil) then begin
      DisableInputRunning := InputState^.Running;
      AudCaptureStop;
    end;
  end;
  AudTimerStop(0);
  Result := AudTimerID=0;
  { Cancellation failure must NOT re-enable callback processing. }
  Busy := SavedBusy;
end;

function EnableDriver: Boolean;
var SavedBusy: Boolean;
    I: Word;
begin
  Result := False;
  if DriverExiting or not AudIsOpen or (InputState=nil) then Exit;
  SavedBusy := Busy; Busy := True;
  { A retained ID after failed cancellation is not a successful restart. }
  if DriverDisabled and (AudTimerID<>0) then AudTimerStop(0);
  if DriverDisabled and (AudTimerID<>0) then begin Busy := SavedBusy; Exit; end;
  if not StartDriverTimer then begin Busy := SavedBusy; Exit; end;
  for I:=0 to 1 do begin
    SelectOutput(I);
    with Output^ do begin
      { Restore the ring on enable even for a software-paused output. }
      if DisableOutputPaused and Opened and not Failed then begin
        if not AudResume then begin AudStop; Failed := True; TimerFault := 1; end;
        LastCursor := AudPosition; ProgressTick := timeGetTime;
      end;
      DisableOutputPaused := False;
    end;
  end;
  SelectOutput(0);
  if DisableInputRunning and InputOpened and (InputState<>nil) then begin
    if InputState^.Running and (InputState^.Fault=0) then begin
      { The ADC restarts its ring at zero. Preserve the public position,
        partially filled client buffers and notification queue. }
      InputState^.Produced := 0; InputState^.Consumed := 0;
      InputState^.LastPos := 0; InputState^.Pending := True;
    end;
  end;
  DisableInputRunning := False;
  DriverDisabled := False; Enabled := True;
  Busy := SavedBusy; Result := True;
end;

{$S-} { WEP/ExitProc: bounded cleanup, no logging, GUI, heap or client callbacks }
procedure DriverExit; far;
begin
  ExitProc := PreviousExit;
  DriverExiting := True; Enabled := False; Busy := True;
  { Fallback if DRV_FREE was not reached, or its cancellation failed.
    Do not invoke full cleanup or release memory while a timer may remain. }
  AudCaptureStop; AudStopAll;
  AudTimerStop(0);
end;
{$S+}

function CleanupDevice: Boolean;
var SavedBusy: Boolean;
    I,D: Word;
begin
  Result := False;
  Enabled := False; DriverDisabled := True;
  SavedBusy := Busy; Busy := True;
  MidiRetired := True; MidiCookie := 0;
  MidiInvalidate;
  { Stop input without accessing client-owned headers during final teardown. }
  if InputOpened then AudCaptureStop;
  OplDisable;
  { Stop DMA first, as HDA2 does, before timer cancellation or teardown. }
  AudStopAll;
  DriverLog('CLEANUP: DMA stopped; cancelling multimedia timer.');
  if AudTimerID<>0 then AudTimerStop(0);
  if AudTimerID<>0 then begin
    DriverLog('CLEANUP: timer cancellation failed; DLL-exit retry pending.');
    FlushLog;
    Busy := SavedBusy; Exit;
  end;
  for D:=0 to 1 do begin
    SelectOutput(D);
    with Output^ do begin
      StartPending := False; DrainEndPos := -1;
      AudStop; HardwareRate := 0; DrainPending := False;
      I := Head;
      while Count<>0 do begin
        FreeQueueData(I); Queue[I].Header := nil;
        I := NextIndex(I); Dec(Count);
      end;
      Head := 0; Tail := 0;
      NoteHead := 0; NoteTail := 0; NoteCount := 0;
      Opened := False; Paused := False; Suspended := False;
      TimerFault := 0; Failed := False;
      AcceptedTotal := 0; AcceptedFrames := 0; DoneBytes := 0;
    end;
  end;
  SelectOutput(0);
  AudClose; FillChar(HardwareVolumeValid,SizeOf(HardwareVolumeValid),0);
  SaveVolume;
  ReleaseResident;
  InputFree;
  OutputsFree;
  OplReleaseFIFO;
  ReleaseMidiCore;
  DriverLog('CLEANUP: hardware and queue references released.');
  Busy := SavedBusy; Result := True;
end;

function ReadConfig(var Base: LongInt; var Index: Word): Boolean;
var B,FN: array[0..255] of Char;
    V: LongInt;
    Err: Integer;
begin
  Result := False; StrPCopy(FN,IniName);
  GetPrivateProfileString('AUDIGY2','PhysicalBase','$08000000',
                           B,SizeOf(B),FN);
  Val(StrPas(B),Base,Err);
  if Err<>0 then Exit;
  GetPrivateProfileString('AUDIGY2','CardIndex','0',B,SizeOf(B),FN);
  Val(StrPas(B),V,Err);
  if (Err<>0) or (V<0) or (V>255) then Exit;
  Index := Word(V); Result := True;
end;

function ConfigNumber(Key: PChar; DefaultValue,LowValue,HighValue: Word): Word;
var B: array[0..31] of Char;
    FN: array[0..255] of Char;
    V: LongInt;
    Err: Integer;
begin
  StrPCopy(FN,IniName);
  GetPrivateProfileString('AUDIGY2',Key,'',B,SizeOf(B),FN);
  Val(StrPas(B),V,Err);
  if Err<>0 then V := DefaultValue;
  if V<LowValue then V := LowValue;
  if V>HighValue then V := HighValue;
  Result := Word(V);
end;

function ReadAud2Gain: Word;
var B: array[0..31] of Char;
    FN: array[0..255] of Char;
    Steps: Word;
begin
  Result := 0; StrPCopy(FN,IniName);
  if GetPrivateProfileString('AUDIGY2','Aud2Gain','0',B,SizeOf(B),FN)>=
     SizeOf(B)-1 then Exit;
  if AudGainParse(StrPas(B),Steps) then Result := Steps else Result := 0;
end;

procedure LoadTiming;
begin
  AudBufferHalfMS := ConfigNumber('HalfBufferMS',AudBufferDefaultMS,
                                   AudBufferMinMS,AudBufferMaxMS);
  AudRefillSliceMS := ConfigNumber('RefillSliceMS',AudSliceDefaultMS,
                                    AudSliceMinMS,AudSliceMaxMS);
  Aud2GainSteps := ReadAud2Gain;
  FMFader := ConfigNumber('FrontRearFM',50,0,100);
  FMFaderDirty := False;
  AudTimerInterval := ConfigNumber('TimerIntervalMS',5,1,20);
  AudClockMargin := ConfigNumber('TimerResolutionMS',1,1,10);
end;

procedure VolumeKey(Device: Word; Key: PChar);
begin
  case Device of
    0: StrPCopy(Key,'PCM');
    1: StrPCopy(Key,'PCM2');
  else StrPCopy(Key,'FM');
  end;
end;

procedure LoadVolume;
var B: array[0..31] of Char;
    FN: array[0..255] of Char;
    Key: array[0..7] of Char;
    I: Word;
    V: LongInt;
    Err: Integer;
begin
  StrPCopy(FN,IniName);
  GetPrivateProfileString('AUDIGY2','Debug','0',B,SizeOf(B),FN);
  Val(StrPas(B),V,Err);
  DebugEnabled := (Err=0) and (V<>0);
  GetPrivateProfileString('AUDIGY2','ShutdownWorkaround','1',B,SizeOf(B),FN);
  Val(StrPas(B),V,Err);
  if (Err<>0) or ((V<>0) and (V<>1)) then V := 1;
  ShutdownWorkaround := V=1;
  for I:=0 to 2 do begin
    VolumeKey(I,Key);
    GetPrivateProfileString('Volume',Key,'$FFFFFFFF',B,SizeOf(B),FN);
    Val(StrPas(B),V,Err);
    if Err=0 then Volume[I] := V;
  end;
end;

{$S-} { cached publication only; safe during synchronized mixer queries }
procedure CachePlaybackVolume(Device: Word; Value: LongInt);
begin
  Volume[Device] := Value;
  VolumeDirty[Device] := True; VolumePending[Device] := True;
end;

procedure ApplyVolume;
var I: Word;
    Fader: Word;
    Value: LongInt;
begin
  if not AudIsOpen then Exit;
  for I:=0 to 2 do begin
    Value := Volume[I];
    if VolumePending[I] or not HardwareVolumeValid[I] or
       (HardwareVolume[I]<>Value) then begin
      case I of
        0: Fader := ActiveSettings.Fader1;
        1: Fader := ActiveSettings.Fader2;
      else Fader := FMFader;
      end;
      AudSetVolume(I,LoWord(Value),HiWord(Value),Fader);
      HardwareVolume[I] := Value; HardwareVolumeValid[I] := True;
      VolumePending[I] := False;
    end;
  end;
end;
{$S+}

procedure SaveVolume;
var B: array[0..15] of Char;
    FN: array[0..255] of Char;
    Key: array[0..7] of Char;
    I,F: Word;
    Value: LongInt;
begin
  if TimerActive or AudAnyStreaming or OplRunning or OplStarting then Exit;
  StrPCopy(FN,IniName);
  for I:=0 to 2 do if VolumeDirty[I] then begin
    Value := Volume[I]; StrPCopy(B,'$'+IntToHex(Value,8));
    VolumeKey(I,Key);
    if WritePrivateProfileString('Volume',Key,B,FN) then
      if Volume[I]=Value then VolumeDirty[I] := False;
  end;
  if FMFaderDirty then begin
    F := FMFader; StrPCopy(B,IntToStr(F));
    if WritePrivateProfileString('AUDIGY2','FrontRearFM',B,FN) then
      if FMFader=F then FMFaderDirty := False;
  end;
end;

procedure MxNotify; forward;

{$I CFGSTATE.INC}

function InitializeDevice: Boolean;
var Base: LongInt;
    Index: Word;
begin
  Result := False;
  if (GetWinFlags and WF_ENHANCED)=0 then Exit;
  if not ReadConfig(Base,Index) then begin
    DriverLog('FAIL: invalid AUDIGY2.INI setting.'); FlushLog; Exit;
  end;
  { Own the mappings/DSP from DRV_LOAD, as HDA2 does, before client tasks
    open wave handles. No client task creates persistent card resources. }
  DriverLog('HARDWARE: initializing once at DRV_LOAD.');
  if DebugEnabled and not AudIsStreaming then FlushLog;
  if not AudOpen(Base,Index,DriverLog,SupplyPCM,OplFillPCM) then begin
    FlushLog; Exit;
  end;
  if (OplFIFO<>nil) and not AudOplAvailable then OplReleaseFIFO;
  EqBuild(ActiveSettings.EQ,RequestedEQ);
  AudEqApply(ActiveSettings.EQ.Enabled,RequestedEQ);
  with ActiveSettings.Rev do AudRevApply(Enabled,Preset,Level);
  AudBassApply(ActiveSettings.BassOn,ActiveSettings.BassHz);
  FillChar(HardwareVolumeValid,SizeOf(HardwareVolumeValid),0);
  { Volume changes are committed by the resident timer.  This keeps all
    indexed DSP access away from a wave client's task/callback stack. }
  FillChar(VolumePending,SizeOf(VolumePending),1);
  Result := True;
end;

function OpenWave(User,Param1,Param2: LongInt): LongInt;
var D: PWaveOpenDesc;
    F: PPCMWaveFormat;
    ExpectedAlign: Word;
begin
  with Output^ do begin
    Result := MMSYSERR_INVALPARAM;
    if (Param1=0) or IsBadReadPtr(Pointer(Param1),SizeOf(TWaveOpenDesc)) then Exit;
    D := PWaveOpenDesc(Param1);
    if (D^.lpWaveFormat=nil) or
       IsBadReadPtr(D^.lpWaveFormat,SizeOf(TPCMWaveFormat)) then Exit;
    F := PPCMWaveFormat(D^.lpWaveFormat);
    Result := WAVERR_BADFORMAT;
    if (F^.wf.wFormatTag<>WAVE_FORMAT_PCM) or
       not PCMFormatValid(F^.wf.nSamplesPerSec,F^.wBitsPerSample,
                         F^.wf.nChannels) then Exit;
    { Like HDA2, accept legacy PCM callers with stale redundant fields.
      Derive packed PCM alignment from the actual bits/channels ourselves. }
    ExpectedAlign := PCMFrameBytes(F^.wBitsPerSample,F^.wf.nChannels);
    if (Param2 and WAVE_FORMAT_QUERY)<>0 then begin Result := 0; Exit; end;
    Result := MMSYSERR_ALLOCATED;
    if Opened or (NoteCount>QueueMax-4) then Exit;
    Result := MMSYSERR_INVALPARAM;
    if (User=0) or IsBadWritePtr(Pointer(User),4) then Exit;
    Result := MMSYSERR_NOTENABLED;
    if (GetWinFlags and WF_ENHANCED)=0 then Exit;
    { The event and resident code are driver-owned. A wave
      open, including the exit sound, must not create a task-owned timer. }
    if AudTimerID=0 then begin
      DriverLog('FAIL: driver-lifetime timer is unavailable.'); FlushLog; Exit;
    end;
    if DebugEnabled then DriverLog('OPEN: WaveOut device '+IntToStr(CurrentOutput)+'.');
    { Like HDA2, wave opens reuse the driver-owned DSP/PTB/selectors.
      Configuration changes take effect after unloading/restarting Windows. }
    if not AudIsOpen then begin
      DriverLog('FAIL: persistent hardware is unavailable.'); FlushLog; Exit;
    end;
    CurrentRate := F^.wf.nSamplesPerSec;
    SourceBits := F^.wBitsPerSample; SourceChannels := F^.wf.nChannels;
    SourceAlign := ExpectedAlign;
    if CurrentRate<>HardwareRate then begin
      { A changed clock/loop geometry cannot share the preceding DMA tail.
        Same-rate opens keep that tail, as HDA2's persistent stream does. }
      StopEngine;
      if not AudSetRate(CurrentRate) then begin
        { A playback-rate failure must not destroy an independent capture. }
        AudStop; HardwareRate := 0; HardwareVolumeValid[CurrentOutput] := False;
        FlushLog; Exit;
      end;
      HardwareRate := CurrentRate;
    end;
    VolumePending[CurrentOutput] := True;
    if DebugEnabled then DriverLog('OPEN: persistent hardware reused.');
    TimerFault := 0; DrainPending := False;
    Client := D^; ClientFlags := Param2;
    if DebugEnabled then ReportFormat;
    Head := 0; Tail := 0; Count := 0;
    AcceptedTotal := 0; AcceptedFrames := 0; DoneBytes := 0; Failed := False;
    StartPending := False; Paused := False; Suspended := False; Opened := True;
    PLongValue(User)^ := LongInt(@Cookie);
    Enqueue(WOM_OPEN,nil);
    if DebugEnabled and not AudIsStreaming then FlushLog;
    ApplyShutdownWorkaround;
    Result := 0;
  end;
end;

function WriteWave(Param1,Param2: LongInt): LongInt;
var P: PWaveHdr;
    I,N: Word;
begin
  with Output^ do begin
    Result := MMSYSERR_INVALPARAM;
    if (Param1=0) or (Param2<SizeOf(TWaveHdr)) then Exit;
    if IsBadWritePtr(Pointer(Param1),SizeOf(TWaveHdr)) then Exit;
    P := PWaveHdr(Param1);
    Result := WAVERR_UNPREPARED;
    if (P^.dwFlags and WHDR_PREPARED)=0 then Exit;
    Result := WAVERR_STILLPLAYING;
    if (P^.dwFlags and WHDR_INQUEUE)<>0 then Exit;
    I := Head; N := Count;
    while N<>0 do begin
      if Queue[I].Header=P then Exit;
      I := NextIndex(I); Dec(N);
    end;
    { WODMESSA accepts the loop flags independently. HDA2's active
      checkqueue path repeats only a packet carrying BOTH flags. Match
      that behavior without rejecting otherwise playable packets. }
    Result := MMSYSERR_INVALPARAM;
    if (P^.dwBufferLength<0) or (P^.dwBufferLength>MaxHeaderBytes) or
       ((P^.dwBufferLength mod SourceAlign)<>0) then Exit;
    { Match HDA2's 15 MB stream capacity, including huge prepared PCM
      packets. Validate the full range before publishing its pointer. }
    if P^.dwBufferLength<>0 then begin
      if P^.lpData=nil then Exit;
      if IsBadHugeReadPtr(P^.lpData,P^.dwBufferLength) then begin
        DriverLog('WRITE rejected: invalid huge PCM data range.');
        Exit;
      end;
    end;
    if AcceptedFrames>$1F000000-(P^.dwBufferLength div SourceAlign) then Exit;
    Result := MMSYSERR_NOMEM;
    if Count+NoteCount>=QueueMax then Exit;
    Result := MMSYSERR_ERROR;
    if Failed then Exit;
    if AudIsStreaming then begin
      Inc(StreamWrites);
      if Count=0 then Inc(EmptyQueueWrites);
      if RunGapPending then begin
        Inc(RecoveredGaps);
        RunGapPending := False;
      end;
    end;
    Result := MMSYSERR_NOMEM;
    { MMSYSTEM has prepared/locked this application block. Keep its real
      pointer as HDA2 does, so queued software-synth buffers are not frozen
      into an early snapshot. The application retains ownership. }
    I := Tail;
    with Queue[I] do begin
      Header := P; Data := P^.lpData; Size := P^.dwBufferLength;
      Copied := 0; FedBytes := 0; StartPos := -1; EndPos := -1;
      Looped := (P^.dwFlags and (WHDR_BEGINLOOP or WHDR_ENDLOOP))=
                               (WHDR_BEGINLOOP or WHDR_ENDLOOP);
      LoopsLeft := 1;
      if Looped and (Size<>0) and (P^.dwLoops<>0) then
        LoopsLeft := P^.dwLoops;
    end;
    if DebugEnabled and not AudIsStreaming then begin
      DriverLog('WRITE: bytes='+IntToStr(P^.dwBufferLength));
      DriverLog('WRITE: flags=$'+IntToHex(P^.dwFlags,8));
      DriverLog('WRITE: loops=$'+IntToHex(P^.dwLoops,8));
      FlushLog; { Before startup: no running DMA deadline is delayed. }
    end;
    if DebugEnabled and Queue[I].Looped then
      DriverLog('WRITE: single-buffer loop accepted.');
    Tail := NextIndex(I); Inc(Count);
    AcceptedTotal := AcceptedTotal+P^.dwBufferLength;
    AcceptedFrames := AcceptedFrames+P^.dwBufferLength div SourceAlign;
    P^.dwFlags := (P^.dwFlags and not LongInt(WHDR_DONE)) or WHDR_INQUEUE;
    Result := 0;
    if not AudIsStreaming and not Paused then StartPending := True;
    { No posted kick is required: the multimedia event already exists.
      A full task queue cannot orphan an accepted playback start. }
  end;
end;

function DispatchWave(Message: Word; User,Param1,Param2: LongInt): LongInt;
var N,I: Word;
    P: PMMTime;
    Bytes,BPS: LongInt;
begin
  with Output^ do begin
    Result := MMSYSERR_NOTSUPPORTED;
    TaskMaintenance;
    if DebugEnabled then case Message of
      WODM_CLOSE: LogNumber('CLOSE device=',CurrentOutput);
      WODM_RESET: LogNumber('RESET device=',CurrentOutput);
      WODM_PAUSE: LogNumber('PAUSE device=',CurrentOutput);
      WODM_RESTART: LogNumber('RESTART device=',CurrentOutput);
    end;
    if Message=WODM_OPEN then Result := OpenWave(User,Param1,Param2)
    else if not Opened or (User<>LongInt(@Cookie)) then
      Result := MMSYSERR_INVALHANDLE
    else case Message of
      WODM_WRITE: begin
        Result := WriteWave(Param1,Param2);
        if Result<>0 then begin
          DriverLog('WRITE rejected by driver.');
          FlushLog;
        end;
      end;
      WODM_CLOSE: begin
        Result := WAVERR_STILLPLAYING;
        if Count=0 then begin
          StartPending := False;
          { All caller data is already copied into resident DMA. Close
            returns immediately like HDA2, while the timer drains the tail
            with silence. It must keep servicing even with Opened=False. }
          if not AudIsStreaming and not InputOpened then SaveVolume;
          Opened := False; Paused := False; Suspended := False;
          { Keep callback/device snapshots until CLOSE can be delivered,
            even when the caller's message queue is currently full. }
          Enqueue(WOM_CLOSE,nil);
          if DebugEnabled then begin
            DriverLog('CLOSE: accepted; hardware retained.');
            ReportNotifications;
            if not AudIsStreaming then FlushLog;
          end;
          Result := 0;
        end;
      end;
      WODM_PAUSE: begin
        Result := 0;
        StartPending := False;
        Paused := True;
      end;
      WODM_RESTART: begin
        Result := 0;
        if Paused then begin
          Paused := False;
          if (Count<>0) and not AudIsStreaming then StartPending := True;
        end;
      end;
      WODM_RESET: begin
        AbortQueue('RESET: stopping and returning pending headers.');
        TimerFault := 0; Failed := False;
        AcceptedTotal := 0; AcceptedFrames := 0; DoneBytes := 0;
        Paused := False; Suspended := False;
        if DebugEnabled then begin ReportNotifications; FlushLog; end;
        Result := 0;
      end;
      WODM_BREAKLOOP: begin
        { Finish the current submitted iteration; audio already in the DMA
          ring remains subject to the existing buffered playback latency. }
        N := Count; I := Head;
        while N<>0 do begin
          { A BreakLoop immediately after Write can precede the first tick.
            HDA2 also applies it to the queued head before PCM is consumed. }
          if Queue[I].Looped and
             ((Queue[I].StartPos>=0) or (I=Head)) then begin
            Queue[I].LoopsLeft := 1; Break;
          end;
          I := NextIndex(I); Dec(N);
        end;
        DriverLog('BREAKLOOP: requested.'); Result := 0;
      end;
      WODM_GETPOS: begin
        Result := MMSYSERR_INVALPARAM;
        if (Param1<>0) and (Param2>=SizeOf(TMMTime)) then
          if not IsBadWritePtr(Pointer(Param1),SizeOf(TMMTime)) then begin
            P := PMMTime(Param1);
            Bytes := CurrentBytes; BPS := CurrentRate*SourceAlign;
            case P^.wType of
              TIME_MS: P^.ms := (Bytes div BPS)*1000+
                               ((Bytes mod BPS)*1000) div BPS;
              TIME_SAMPLES: P^.sample := Bytes div SourceAlign;
            else
              P^.wType := TIME_BYTES; P^.cb := CurrentBytes;
            end;
            Result := 0;
          end;
      end;
      AUD_STATUS: if Failed then Result := 1 else Result := 0;
      AUD_RETRIES: Result := RetryCount;
      AUD_PENDING: Result := NoteCount;
      { Generic MMSYSTEM prepare/unprepare handles locking and flags.
        Return NOTSUPPORTED for its driver-specific hooks. }
      WODM_PREPARE,WODM_UNPREPARE: Result := MMSYSERR_NOTSUPPORTED;
    end;
    PumpNotifications;
  end;
end;

function WodMessage(Device,Message: Word; User,Param1,
                    Param2: LongInt): LongInt; export;
var Caps: TWaveOutCaps;
    N,I: Word;
    P: PMMTime;
    Bytes, BPS: LongInt;
begin
  Result := MMSYSERR_NOTSUPPORTED;
  if Message=WODM_INIT then begin Result := 0; Exit; end;
  if Message=WODM_GETNUMDEVS then begin Result := 2; Exit; end;
  if Device>1 then begin Result := MMSYSERR_BADDEVICEID; Exit; end;
  if Outputs[Device]=nil then begin Result := MMSYSERR_NOTENABLED; Exit; end;
  if not Enabled and (Message<>WODM_RESET) and (Message<>WODM_CLOSE) then
    begin Result := MMSYSERR_NOTENABLED; Exit; end;
  { Volume queries may be issued re-entrantly by a player's synchronized
    slider. They only read cached state and must never pump its callbacks. }
  if Message=WODM_GETVOLUME then begin
    Result := MMSYSERR_INVALPARAM;
    if (Param1<>0) and not IsBadWritePtr(Pointer(Param1),4) then begin
      PLongValue(Param1)^ := Volume[Device]; Result := 0;
    end;
    Exit;
  end;
  { Match HDA2's working cached software-volume path.  This entry only
    publishes the new value; the resident timer applies it to Audigy's DSP. }
  if Message=WODM_SETVOLUME then begin
    CachePlaybackVolume(Device,Param1);
    if not AnyOutputActive and not InputOpened then SaveVolume;
    Result := 0; Exit;
  end;
  if Busy then begin Result := MMSYSERR_ALLOCATED; Exit; end;
  if Message=WODM_GETDEVCAPS then begin
    Result := MMSYSERR_INVALPARAM;
    if (Param1=0) or (Param2<=0) then Exit;
    N := SizeOf(Caps); if Param2<LongInt(N) then N := Word(Param2);
    if IsBadWritePtr(Pointer(Param1),N) then Exit;
    FillChar(Caps,SizeOf(Caps),0);
    Caps.wMid := 0; Caps.wPid := 0; Caps.vDriverVersion := AudDriverVersion;
    if Device=0 then StrPCopy(Caps.szPname,'Creative Audigy 2 Playback')
    else StrPCopy(Caps.szPname,'2nd Creative Audigy 2 Playback');
    { All Win3.1 standard 11.025/22.05/44.1k mono/stereo 8/16-bit bits.
      Other rates in 8000..48000 are accepted by FORMAT_QUERY. }
    Caps.dwFormats := $00000FFF; Caps.wChannels := 2;
    Caps.dwSupport := WAVECAPS_VOLUME or WAVECAPS_LRVOLUME;
    Move(Caps,Pointer(Param1)^,N);
    Result := 0; Exit;
  end;
  Busy := True;
  SelectOutput(Device);
  try
    Result := DispatchWave(Message,User,Param1,Param2);
  finally
    SelectOutput(0);
    Busy := False;
  end;
end;

{$I AUXMON.INC}

{$I MXDRIVER.INC}

function DriverProc(Identifier: LongInt; DriverID: THandle;
                    Message: Word; Param1,Param2: LongInt): LongInt; export;
begin
  Result := 0;
  case Message of
    1: begin { DRV_LOAD: persistent resources, independent of wave/AUX clients. }
      if ResourcesLoaded then begin Result := 1; Exit; end;
      Busy := True; LoadVolume; LoadTiming; ConfigLoad; ResetLogFile;
      DriverLog('VERSION: '+AudDriverVersionText+'; dual WaveOut; independent volume.');
      ConfigureMidiTiming;
      if ActiveSettings.MidiSynth<>SynthNone then
        DriverLog('MIDI: synth rate='+IntToStr(ActiveSettings.MidiRate)+' Hz.');
      if DebugEnabled then DriverLog('DEBUG: enabled; playback calls write diagnostics.');
      Enabled := OutputsAllocate;
      AudOplEnabled := False;
      MidiRetired := False;
      MidiConfigured := False;
      case ActiveSettings.MidiSynth of
        SynthOPL3: MidiConfigured := FileExists(DriverDir+'OPLCORE.DLL');
        SynthSoundFont: begin
          MidiConfigured := FileExists(DriverDir+'SFCORE.DLL');
          if not MidiConfigured then DriverLog('SF2: SFCORE.DLL missing.');
        end;
      end;
      if Enabled and MidiConfigured then begin
        AudOplEnabled := OplAllocateFIFO;
        if not AudOplEnabled then DriverLog('OPL PCM: optional FIFO allocation failed.');
      end;
      if Enabled then Enabled := InitializeDevice;
      if Enabled then Enabled := InputAllocate;
      if Enabled and (ActiveSettings.MidiSynth=SynthSoundFont) and (MidiEvents<>nil) then begin
        DriverLog('SF2: initializing during DRV_LOAD.');
        if not EnsureMidiCore then begin
          MidiConfigured := False; AudOplEnabled := False; OplReleaseFIFO;
          DriverLog('SF2: synth unavailable for this session.');
        end;
      end;
      if Enabled then Enabled := StartDriverTimer;
      if Enabled then begin ResourcesLoaded := True; Result := 1; end
      else begin
        AudClose; FillChar(HardwareVolumeValid,SizeOf(HardwareVolumeValid),0);
        InputFree; OutputsFree;
        OplReleaseFIFO;
        ReleaseMidiCore;
        FlushLog;
      end;
      Busy := False;
    end;
    2: begin { DRV_ENABLE: also handles a return from Windows-disabled state. }
      if EnableDriver then Result := 1;
    end;
    3,4: Result := 1; { DRV_OPEN/CLOSE }
    5: begin { Cancel earlier than DRV_FREE; keep resources for re-enable. }
      if DisableDriver then DriverLog('DRIVER: disabled; multimedia timer stopped.')
      else DriverLog('DRIVER: disabled; timer cancellation will be retried.');
      Result := 1;
    end;
    6: begin { DRV_FREE: cancel/stop/release even after client task exit. }
      DriverLog('DRIVER: DRV_FREE requested.');
      if ResourcesLoaded then
        if CleanupDevice then begin ResourcesLoaded := False; SaveMonitor; end;
      { Windows IGNORES this result: zero cannot veto DLL unloading.
        Failed cancellation leaves the driver disabled; WEP retries it. }
      Enabled := False;
      DriverLog('DRIVER: DRV_FREE completed.'); Result := 1;
    end;
    7: begin { HDA2's standard Control Panel setup entry point. }
      if not TimerActive and not Busy then
        if AudConfigure(HWnd(Word(Param1)),ActiveSettings,SavedSettings,
                        ConfigSubmit,ConfigPoll,ConfigCancel) then Result := 1;
      Exit; { merely viewing/cancelling setup must not flush a debug file }
    end;
    8: begin Result := 1; Exit; end; { DRV_QUERYCONFIGURE }
    9,10: Result := 1; { DRV_INSTALL/REMOVE }
  else
    if Message=11 then begin
      DriverLog('DRIVER: DRV_EXITSESSION.');
    end;
    Result := DefDriverProc(Identifier,DriverID,Message,Param1,Param2);
  end;
  if DebugEnabled and not TimerActive then FlushLog;
end;

exports
  DriverProc, WodMessage, WidMessage, AuxMessage, TickProc,
  ModMessage name 'MODMESSAGE',
  mxdMessage name 'MXDMESSAGE';

var B: array[0..255] of Char;
begin
  FillChar(Outputs,SizeOf(Outputs),0);
  FillChar(OutputMemory,SizeOf(OutputMemory),0);
  FillChar(OutputSelector,SizeOf(OutputSelector),0);
  Output := nil; CurrentOutput := 0;
  OplFIFO := nil; OplMemory := 0; OplSelector := 0; OplOwner := 0;
  OplRead := 0; OplWrite := 0; OplCount := 0;
  OplGapCovered := 0;
  OplFirstFaultStage := 0; OplFirstFaultCode := 0; OplFirstFaultValue := 0;
  OplRecoveryTried := False;
  OplRefillMark := 0; OplSilenceMark := 0; OplRecoveryTick := 0;
  OplRecoveryAttempts := 0; OplRecoveryFrames := 0;
  OplRecoveryRetries := 0;
  OplGapPending := False; OplGapTried := False; OplGapRetryTick := 0;
  OplGapFaults := 0; OplGapReprimes := 0;
  OplStarting := False; OplRunning := False; OplStopping := False; OplFailed := False;
  MidiEvents := nil; MidiCookie := 0; MidiEpoch := 0;
  MidiFullResetPending := True;
  @MidiCore := nil; MidiCoreDLL := 0;
  MidiCoreCode := 0; MidiCoreData := 0; MidiCoreReady := False;
  MidiRenderOwned := False; MidiHaveEvent := False;
  MidiRenderEpoch := -1; MidiEpochTick := 0; MidiRendered := 0; MidiSent := 0;
  MidiRenderCalls := 0; MidiRenderMaxMS := 0; MidiRenderLastTick := 0;
  MidiRenderMaxGap := 0; MidiEventMaxAge := 0; MidiRenderSamples := 0;
  MidiConfigured := False; MidiLaunching := False; MidiFault := False;
  MidiRetired := False; ResourcesLoaded := False;
  MidiCallback := 0; MidiInstance := 0; MidiHandle := 0; MidiFlags := 0;
  MidiHead := 0; MidiTail := 0;
  FillChar(MidiDiag,SizeOf(MidiDiag),0);
  LogFlushing := False; ShutdownWorkaround := True;
  FillChar(MxClients,SizeOf(MxClients),0); FillChar(MxSeen,SizeOf(MxSeen),0);
  MxObserved := False; MxNotifying := False; MxOwnsConfig := False;
  MxSerial := 0; MxSaveTick := 0;
  InputState := nil; InputMemory := 0; InputSelector := 0;
  InputOpened := False; InputCookie := $41494E31;
  ConfigPending := False; ConfigNeedsSave := False; ConfigInputValid := True;
  ConfigError := 0;
  MonitorPending := False; MonitorDirty := False; MonitorFault := False;
  MonitorSaving := False; ConfigSaving := False;
  Enabled := True; Busy := False; FillChar(Volume,SizeOf(Volume),$FF);
  ResidentCount := 0; TimerActive := False;
  DriverDisabled := False; DriverExiting := False; DisableInputRunning := False;
  FillChar(VolumeDirty,SizeOf(VolumeDirty),0);
  FillChar(VolumePending,SizeOf(VolumePending),0);
  FillChar(HardwareVolume,SizeOf(HardwareVolume),0);
  FillChar(HardwareVolumeValid,SizeOf(HardwareVolumeValid),0);
  DebugEnabled := False;
  LogCount := 0; LogFirst := 0; LogDropped := False;
  GetModuleFileName(HInstance,B,SizeOf(B));
  DriverDir := ExtractFilePath(StrPas(B));
  GetWindowsDirectory(B,SizeOf(B));
  IniName := StrPas(B);
  if IniName[Length(IniName)]<>'\' then IniName := IniName+'\';
  LogName := IniName+'AUDIGY2.LOG';
  IniName := IniName+'AUDIGY2.INI';
  { Install last, so timer cancellation precedes existing RTL exit handlers. }
  PreviousExit := ExitProc; ExitProc := @DriverExit;
end.
