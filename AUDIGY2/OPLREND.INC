{ OPL3 and fixed-point SoundFont use Audigy's existing multimedia timer.
  No USER messages, worker task, heap, file I/O or floating point here. }
const
  MidiMaxSamples=1024;
  MidiMaxEvents=128;
  MidiMaxWorkMS=4;

procedure ConfigureMidiTiming;
begin
  AudSetSynthRate(ActiveSettings.MidiRate);
  MidiFramesPer10MS := ActiveSettings.MidiRate div 100;
  { Keep the 3584-frame default prefill duration at either rate. }
  MidiPrimeFrames := Word((3584*LongInt(MidiFramesPer10MS)+440) div 441);
  MidiHourFrames := LongInt(MidiFramesPer10MS)*360000;
  MidiStarvedBytes := LongInt(MidiFramesPer10MS)*40;
end;

procedure ReleaseMidiCore;
var Loaded: Boolean;
begin
  Loaded := MidiCoreReady;
  MidiCoreReady := False;
  if Loaded and (ActiveSettings.MidiSynth=SynthSoundFont) then begin
    DriverLog('SF2: releasing SoundFont.');
    MidiCore(6,0,0);
    DriverLog('SF2: SoundFont released.');
  end;
  if MidiCoreData<>0 then GlobalPageUnlock(MidiCoreData);
  if MidiCoreCode<>0 then GlobalPageUnlock(MidiCoreCode);
  MidiCoreData := 0; MidiCoreCode := 0;
  @MidiCore := nil;
  if MidiCoreDLL>=32 then FreeLibrary(MidiCoreDLL);
  MidiCoreDLL := 0;
end;

function SoundFontPath(var Name: string): Boolean;
begin
  Name := ActiveSettings.SoundFont;
  Result := False;
  if Name='' then Exit;
  if (Pos(':',Name)=0) and (Name[1]<>'\') then begin
    if Length(DriverDir)+Length(Name)>255 then Exit;
    Name := DriverDir+Name;
  end;
  Result := True;
end;

function LockMidiCore(Entry: Pointer): Boolean;
var Code,Data: Word;
begin
  Result := False;
  Code := HiWord(GlobalHandle(Seg(Entry^)));
  Data := MidiCore(7,0,0);
  Data := HiWord(GlobalHandle(Data));
  if (Code=0) or (Data=0) then Exit;
  if GlobalPageLock(Code)=0 then Exit;
  MidiCoreCode := Code;
  if GlobalPageLock(Data)=0 then Exit;
  MidiCoreData := Data;
  Result := True;
end;

function EnsureMidiCore: Boolean;
var Path: array[0..255] of Char;
    Entry: Pointer;
    FileName,FontName: string;
    EntryName: PChar;
    ABI,LoadStatus: Word;
    SoundFont: Boolean;
begin
  Result := MidiCoreReady;
  if Result or MidiLaunching or TimerActive then Exit;
  if Length(DriverDir)>SizeOf(Path)-13 then Exit;
  SoundFont := ActiveSettings.MidiSynth=SynthSoundFont;
  if SoundFont then begin
    if (GetWinFlags and $0400)=0 then begin { WF_80x87, used for bank setup only }
      DriverLog('SF2: SoundFont loading requires an x87.'); Exit;
    end;
    FileName := 'SFCORE.DLL'; EntryName := 'SFCORE'; ABI := $5342;
    if not SoundFontPath(FontName) then begin
      DriverLog('SF2: SoundFont path is too long.'); Exit;
    end;
  end else begin
    FileName := 'OPLCORE.DLL'; EntryName := 'OPLCORE'; ABI := $A302;
  end;
  MidiLaunching := True;
  try
    StrPCopy(Path,DriverDir+FileName);
    MidiCoreDLL := LoadLibrary(Path);
    if MidiCoreDLL<32 then begin
      if SoundFont then DriverLog('SF2: could not load SFCORE.DLL.');
      MidiCoreDLL := 0; Exit;
    end;
    Entry := GetProcAddress(MidiCoreDLL,EntryName);
    @MidiCore := Entry;
    if not Assigned(MidiCore) then begin ReleaseMidiCore; Exit; end;
    if MidiCore(0,0,0)<>ABI then begin
      if SoundFont then DriverLog('SF2: incompatible SFCORE.DLL.');
      ReleaseMidiCore; Exit;
    end;
    if not LockMidiCore(Entry) then begin
      if SoundFont then DriverLog('SF2: could not page-lock the core.');
      ReleaseMidiCore; Exit;
    end;
    { Earlier cores use 44.1 kHz and return zero for command 8. }
    if (MidiCore(8,ActiveSettings.MidiRate,0)<>1) and
       (ActiveSettings.MidiRate<>MidiRateDefault) then begin
      DriverLog('MIDI: '+FileName+' does not support 48000 Hz.');
      ReleaseMidiCore; FlushLog; Exit;
    end;
    if SoundFont then begin
      if MidiCore(9,ActiveSettings.SoundFontHeadroomDB,0)=1 then
        DriverLog('SF2: headroom='+IntToStr(ActiveSettings.SoundFontHeadroomDB)+' dB.')
      else DriverLog('SF2: this core does not support adjustable headroom.');
      StrPCopy(Path,FontName);
      DriverLog('SF2: loading '+FontName);
      FlushLog;
      LoadStatus := MidiCore(1,ActiveSettings.SoundFontVoices,LongInt(@Path[0]));
      if LoadStatus<>1 then begin
        DriverLog('SF2: load failed, status='+IntToStr(LoadStatus));
        ReleaseMidiCore; Exit;
      end;
      DriverLog('SF2: ready, voices='+IntToStr(ActiveSettings.SoundFontVoices)+
        ' samples=16-bit PCM, render=fixed-point IRQ');
    end else if MidiCore(1,0,0)=0 then begin ReleaseMidiCore; Exit; end;
    MidiCoreReady := True; Result := True;
  finally
    MidiLaunching := False;
  end;
end;

procedure MidiRendererLog;
begin
  if TimerActive then Exit;
  DriverLog('OPL TIMER: calls='+IntToStr(MidiRenderCalls)+
    ' samples='+IntToStr(MidiRenderSamples)+' maxwork_ms='+IntToStr(MidiRenderMaxMS)+
    ' maxgap_ms='+IntToStr(MidiRenderMaxGap));
  DriverLog('OPL MIDI: peak='+IntToStr(MidiDiag.PeakQueue)+
    ' full='+IntToStr(MidiDiag.FullRejects)+
    ' long_busy='+IntToStr(MidiDiag.BusyRejects)+
    ' queued_busy='+IntToStr(MidiDiag.AcceptedBusy)+
    ' maxage_ms='+IntToStr(MidiEventMaxAge));
  DriverLog('OPL DMA: silence_frames='+
    IntToStr(MidiDiag.SilentTotal+AudOplSilentBytes div 4)+
    ' skipped='+IntToStr(MidiDiag.SkipFIFO+MidiDiag.SkipWorker));
  if DebugEnabled then begin
    DriverLog('OPL MIDI BUSY: playback2_open='+IntToStr(MidiDiag.AcceptedBusyWave2));
    if OplFirstFaultStage=0 then DriverLog('OPL FAULT: none captured')
    else DriverLog('OPL FAULT: first stage='+IntToStr(OplFirstFaultStage)+
      ' code='+IntToStr(OplFirstFaultCode)+' value='+IntToStr(OplFirstFaultValue));
    DriverLog('OPL RECOVERY: attempts='+IntToStr(OplRecoveryAttempts)+
      ' retries='+IntToStr(OplRecoveryRetries)+
      ' last_starved_frames='+IntToStr(OplRecoveryFrames));
    DriverLog('OPL GAP: faults='+IntToStr(OplGapFaults)+
      ' reprimes='+IntToStr(OplGapReprimes)+
      ' dma_starts='+IntToStr(MidiDiag.DMAStarts));
  end;
end;

{$S-}
function MidiTickFrame(Tick: LongInt): LongInt;
var Delta: LongInt;
begin
  Delta := Tick-MidiEpochTick;
  if Delta>21600000 then Delta := 21600000;
  Result := 0;
  if Delta>0 then Result := (Delta div 10)*MidiFramesPer10MS+
                             (Delta mod 10)*MidiFramesPer10MS div 10;
end;

procedure MidiRenderFaultIRQ;
begin
  MidiFault := True; MidiFullResetPending := True; MidiInvalidate;
  MidiRenderOwned := False; MidiHaveEvent := False;
end;

procedure MidiNextEventIRQ;
begin
  if MidiHaveEvent or (MidiHead=MidiTail) then Exit;
  MidiRenderEvent := MidiEvents^[MidiHead];
  MidiHead := (MidiHead+1) and (OplEventSlots-1);
  MidiHaveEvent := True;
end;

function MidiApplyIRQ: Boolean;
var Data,Age: LongInt;
begin
  Age := timeGetTime-MidiRenderEvent.Tick;
  if Age>MidiEventMaxAge then MidiEventMaxAge := Age;
  if MidiRenderEvent.Size=0 then begin
    Data := LongInt(MidiRenderEvent.Data[0]) or
            (LongInt(MidiRenderEvent.Data[1]) shl 8) or
            (LongInt(MidiRenderEvent.Data[2]) shl 16);
    Result := MidiCore($8002,0,Data)<>0;
  end else begin
    Result := MidiCore($8003,MidiRenderEvent.Size,LongInt(@MidiRenderEvent.Data[0]))<>0;
    { Earlier synth cores can decline the optional Master Volume packet. }
    if MidiRenderEvent.Size=8 then Result := True;
  end;
  MidiHaveEvent := False;
  if not Result then MidiRenderFaultIRQ;
end;

function MidiSpanIRQ(Frames: Word; var Budget: Word): Word;
var Last,UntilFrame: LongInt;
    N: Word;
begin
  Result := 0; Last := MidiRendered+Frames;
  while MidiRendered<Last do begin
    MidiNextEventIRQ;
    UntilFrame := Last;
    if MidiHaveEvent then begin
      UntilFrame := MidiTickFrame(MidiRenderEvent.Tick);
      if UntilFrame<=MidiRendered then begin
        if Budget=0 then Exit;
        Dec(Budget);
        if not MidiApplyIRQ then Exit;
      end;
      if UntilFrame>Last then UntilFrame := Last;
    end;
    if UntilFrame>MidiRendered then begin
      N := Word(UntilFrame-MidiRendered);
      if MidiCore($8004,N,LongInt(@MidiBlock[Result]))=0 then begin
        MidiRenderFaultIRQ; Exit;
      end;
      Inc(Result,N); Inc(MidiRendered,N); Inc(MidiRenderSamples,N);
    end;
  end;
end;

procedure MidiPublishIRQ(Frames: Word);
var First: Word;
begin
  First := OplFifoFrames-OplWrite;
  if First>Frames then First := Frames;
  Move(MidiBlock[0],OplFIFO^[OplWrite],First*4);
  if First<Frames then Move(MidiBlock[First],OplFIFO^[0],(Frames-First)*4);
  OplWrite := (OplWrite+Frames) and (OplFifoFrames-1);
  Inc(OplCount,Frames); Inc(MidiSent,Frames);
  if not OplRunning and not OplStarting and (OplCount>=MidiPrimeFrames) then
    OplStarting := True;
end;

procedure MidiRenderPassIRQ(StartTick: LongInt);
var Horizon,Gap: LongInt;
    Budget,Remaining,N,Made: Word;
    FullReset: Boolean;
begin
  if not MidiConfigured or not MidiCoreReady or (MidiEvents=nil) then Exit;
  if MidiCookie=0 then begin MidiRenderLastTick := 0; Exit; end;
  if MidiFault or MidiRetired or OplFailed then Exit;
  if MidiRenderEpoch<>MidiEpoch then begin
    { OplServiceIRQ has stopped the previous epoch before this routine. }
    if OplRunning or OplStarting or OplStopping then Exit;
    { Opening a handle starts clean. MODM_RESET on an open handle silences
      voices without resetting the channel settings or MIDI Master Volume. }
    FullReset := MidiFullResetPending;
    if not FullReset then FullReset := MidiCore($8006,0,0)=0; { older core }
    if FullReset then
      if MidiCore($8005,0,0)=0 then begin MidiRenderFaultIRQ; Exit; end;
    MidiFullResetPending := False;
    MidiRenderEpoch := MidiEpoch; MidiRenderOwned := False; MidiHaveEvent := False;
    OplRecoveryTried := False;
    OplGapPending := False; OplGapTried := False;
    MidiRendered := 0; MidiSent := 0;
    OplRead := 0; OplWrite := 0; OplCount := 0; OplGapCovered := 0;
    MidiRenderLastTick := 0;
  end;
  if MidiRenderLastTick<>0 then begin
    Gap := StartTick-MidiRenderLastTick;
    if Gap>MidiRenderMaxGap then MidiRenderMaxGap := Gap;
  end;
  MidiRenderLastTick := StartTick;
  if not MidiRenderOwned then begin
    MidiNextEventIRQ;
    if not MidiHaveEvent then Exit;
    MidiEpochTick := MidiRenderEvent.Tick;
    MidiRenderOwned := True; OplOwner := HInstance;
  end;
  if OplRunning then begin
    Gap := OplTrimExpired;
    if Gap>0 then begin
      Inc(OplGapCovered,Gap); Inc(MidiDiag.SkipWorker,Gap); Inc(MidiSent,Gap);
    end;
  end;
  Budget := MidiMaxEvents; Remaining := MidiMaxSamples;
  Horizon := MidiTickFrame(timeGetTime);
  if OplGapPending then begin
    { Advance through missed audio using the normal bounded catch-up path.
      MIDI events still update the synth while this audio is discarded. }
    if Horizon>MidiSent then begin
      Inc(MidiDiag.SkipWorker,Horizon-MidiSent);
      MidiSent := Horizon;
    end;
    if not OplGapTried or (StartTick-OplGapRetryTick>=OplRetryMS) then begin
      OplGapPending := False; OplGapTried := True; OplGapRetryTick := StartTick;
      Inc(OplGapReprimes);
    end;
  end;
  while Remaining<>0 do begin
    if timeGetTime-StartTick>=MidiMaxWorkMS then Exit;
    Gap := MidiSent-MidiRendered;
    if Gap<=0 then begin
      Gap := Horizon-MidiRendered;
      if Gap>LongInt(OplFifoFrames-OplCount) then Gap := OplFifoFrames-OplCount;
    end;
    if Gap<=0 then Break;
    N := 128;
    if Gap<LongInt(N) then N := Word(Gap);
    if N>Remaining then N := Remaining;
    Made := MidiSpanIRQ(N,Budget);
    if MidiFault or (Made=0) then Exit;
    if MidiRendered>MidiSent then MidiPublishIRQ(Made);
    Dec(Remaining,Made);
  end;
  if not OplRunning and not OplStarting and (OplCount>=MidiPrimeFrames) then
    OplStarting := True;
  if MidiSent>=MidiHourFrames then begin
    Inc(MidiEpochTick,3600000);
    Dec(MidiRendered,MidiHourFrames); Dec(MidiSent,MidiHourFrames);
  end;
end;

procedure MidiRenderIRQ;
var StartTick,Elapsed: LongInt;
begin
  if not MidiCoreReady or (MidiCookie=0) then Exit;
  StartTick := timeGetTime; Inc(MidiRenderCalls);
  MidiRenderPassIRQ(StartTick);
  Elapsed := timeGetTime-StartTick;
  if Elapsed>MidiRenderMaxMS then MidiRenderMaxMS := Elapsed;
end;
{$S+}
