{ Driver-owned FIFO. MIDI production and DMA consumption share the existing
  Audigy timer. No allocation or USER calls in IRQ. }

const OplRetryMS=500;

procedure OplReleaseFIFO;
begin
  if OplSelector<>0 then GlobalPageUnlock(OplSelector);
  OplSelector := 0;
  if OplMemory<>0 then begin
    if OplFIFO<>nil then GlobalUnlock(OplMemory);
    GlobalFree(OplMemory);
  end;
  OplFIFO := nil; OplMemory := 0; MidiEvents := nil;
end;

function OplAllocateFIFO: Boolean;
var Bytes: LongInt;
begin
  Result := False;
  Bytes := LongInt(OplFifoFrames)*4+SizeOf(TOplEventQueue);
  OplMemory := GlobalAlloc(GMEM_MOVEABLE or GMEM_SHARE,Bytes);
  if OplMemory=0 then Exit;
  OplFIFO := GlobalLock(OplMemory);
  if OplFIFO<>nil then begin
    if LongInt(Ofs(OplFIFO^))+Bytes>65536 then begin OplReleaseFIFO; Exit; end;
    OplSelector := HiWord(GlobalHandle(Seg(OplFIFO^)));
    if OplSelector<>0 then
      if GlobalPageLock(OplSelector)<>0 then begin
        MidiEvents :=
          Ptr(Seg(OplFIFO^),Word(LongInt(Ofs(OplFIFO^))+LongInt(OplFifoFrames)*4));
        Result := True; Exit;
      end;
  end;
  OplSelector := 0;
  OplReleaseFIFO;
end;

{$S-}
function OplTrimExpired: LongInt;
var Drop: Word;
begin
  Result := 0;
  if not MidiConfigured or not OplRunning then Exit;
  Result := AudOplSilentBytes div 4-OplGapCovered;
  if Result<=0 then begin Result := 0; Exit; end;
  if Result<LongInt(OplCount) then Drop := Word(Result) else Drop := OplCount;
  if Drop<>0 then begin
    { The DMA fence advanced past these samples before they could be copied. }
    OplRead := (OplRead+Drop) and (OplFifoFrames-1);
    Dec(OplCount,Drop);
    Inc(OplGapCovered,Drop); Inc(MidiDiag.SkipFIFO,Drop);
    Dec(Result,Drop);
  end;
end;

function OplFillPCM(Destination: Pointer; Bytes: Word;
                   OutputOffset: LongInt): Word; far;
var Frames, First: Word;
    Dest2: Pointer;
begin
  Result := 0;
  OplTrimExpired;
  Frames := Bytes div 4;
  if Frames>OplCount then Frames := OplCount;
  if (Frames=0) or (OplFIFO=nil) then Exit;
  First := OplFifoFrames-OplRead;
  if First>Frames then First := Frames;
  PCMExpand(@OplFIFO^[OplRead],Destination,First,16,2);
  if First<Frames then begin
    Dest2 := Ptr(Seg(Destination^),Ofs(Destination^)+First*4);
    PCMExpand(@OplFIFO^[0],Dest2,Frames-First,16,2);
  end;
  OplRead := (OplRead+Frames) and (OplFifoFrames-1);
  Dec(OplCount,Frames);
  Result := Frames*4;
end;

procedure OplLatchFaultIRQ(Stage: Word);
begin
  if not DebugEnabled or not MidiConfigured or (OplFirstFaultStage<>0) then Exit;
  AudOplFault(OplFirstFaultCode,OplFirstFaultValue);
  OplFirstFaultStage := Stage; { publish last; do not clear on MIDI reset/open }
end;

procedure OplCheckStarvationIRQ;
var Refills, SilentBytes, Gap, Now: LongInt;
begin
  if not MidiConfigured or (MidiCookie=0) then Exit;
  if MidiRetired or MidiFault or (MidiRenderEpoch<>MidiEpoch) then Exit;
  Refills := AudRefillCount;
  SilentBytes := AudOplSilentBytes;
  if Refills<>OplRefillMark then begin
    OplRefillMark := Refills; OplSilenceMark := SilentBytes;
    Exit;
  end;
  if SilentBytes-OplSilenceMark<MidiStarvedBytes then Exit;
  { Allow another restart if the freshly primed ring starves again.
    Rate-limit retries even when there has been no successful refill. }
  Now := timeGetTime;
  if OplRecoveryTried then begin
    if Now-OplRecoveryTick<OplRetryMS then Exit;
    Inc(OplRecoveryRetries);
  end;
  OplRecoveryTick := Now; OplRecoveryTried := True;
  Inc(OplRecoveryAttempts);
  OplRecoveryFrames := (SilentBytes-OplSilenceMark) div 4;
  { Account for expired samples before stopping this ring. Keep any valid
    queued PCM and let the renderer catch up on the original MIDI timeline. }
  Gap := OplTrimExpired;
  if Gap>0 then begin
    Inc(MidiDiag.SkipWorker,Gap); Inc(MidiSent,Gap);
  end;
  OplGapCovered := 0;
  { The caller selected FM. Normal MIDI priming will request the next start. }
  AudStop;
  OplRunning := False;
end;

procedure OplServiceIRQ;
var Code: Word;
    Value: LongInt;
begin
  if not OplRunning and not OplStarting and not OplStopping then Exit;
  AudSelectPlayback(AudOplPlayback);
  if OplStopping then begin
    AudStop;
    if MidiConfigured then Inc(MidiDiag.DMAStops);
    OplStopping := False; OplRunning := False; OplStarting := False;
    OplCount := 0; OplOwner := 0; OplGapPending := False;
  end else begin
    if OplStarting then begin
      OplStarting := False;
      { PrimeStream resets the hardware silence count. Keep the old total. }
      if MidiConfigured then Inc(MidiDiag.SilentTotal,AudOplSilentBytes div 4);
      AudStart;
      OplRefillMark := 0; OplSilenceMark := 0;
      OplRunning := AudIsStreaming; OplFailed := not OplRunning;
      if OplFailed then OplLatchFaultIRQ(1);
      if MidiConfigured and OplRunning then Inc(MidiDiag.DMAStarts);
    end else if OplRunning then
      if not AudService then begin
        OplRunning := False; OplFailed := True;
        OplLatchFaultIRQ(2);
        AudOplFault(Code,Value);
        if (Code=2) and (Value>0) and MidiConfigured and (MidiCookie<>0) and
           MidiRenderOwned and (MidiRenderEpoch=MidiEpoch) and
           not MidiFault and not MidiRetired then begin
          { The old DMA cursor is ambiguous and the backend stopped the voices.
            Keep the MIDI epoch and synth state; drop PCM from the old ring. }
          Inc(OplGapFaults);
          Inc(MidiDiag.SkipFIFO,OplCount);
          OplRead := 0; OplWrite := 0; OplCount := 0; OplGapCovered := 0;
          OplGapPending := True; OplFailed := False;
        end;
      end else OplCheckStarvationIRQ;
  end;
  AudSelectPlayback(CurrentOutput);
end;

{ Only used while the caller has disabled/serialized the resident timer. }
procedure OplDisable;
begin
  if OplRunning then begin
    AudSelectPlayback(AudOplPlayback); AudStop;
    AudSelectPlayback(CurrentOutput);
  end;
  OplRunning := False; OplStarting := False; OplStopping := False;
  OplCount := 0; OplOwner := 0; OplGapPending := False;
end;
{$S+}
