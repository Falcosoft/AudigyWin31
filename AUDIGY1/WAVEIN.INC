{ Standard Windows 3.1 WaveIn entry point. No private capture exports.
  Prepared client memory is owned/locked by MMSYSTEM, as for waveOut.
  All IRQ-reachable helpers are resident, bounded and stack-check free. }

procedure InputFree;
begin
  if InputSelector<>0 then GlobalPageUnlock(InputSelector);
  InputSelector := 0;
  if InputMemory<>0 then begin
    if InputState<>nil then GlobalUnlock(InputMemory);
    GlobalFree(InputMemory);
  end;
  InputState := nil; InputMemory := 0; InputOpened := False;
end;

function InputAllocate: Boolean;
begin
  Result := False;
  if InputState<>nil then begin Result := True; Exit; end;
  InputMemory := GlobalAlloc(GMEM_MOVEABLE or GMEM_SHARE or GMEM_ZEROINIT,
                            SizeOf(TInputState));
  if InputMemory=0 then Exit;
  InputState := GlobalLock(InputMemory);
  if InputState<>nil then begin
    InputSelector := HiWord(GlobalHandle(Seg(InputState^)));
    if InputSelector<>0 then begin
      if GlobalPageLock(InputSelector)<>0 then begin Result := True; Exit; end;
      InputSelector := 0;
    end;
  end;
  InputFree;
end;

function InputConfig: Boolean;
begin
  Result := ConfigInputValid;
  if not Result then begin
    DriverLog('INPUT: invalid INI input settings; correct them in Configure.'); Exit;
  end;
  InputState^.Source := ActiveSettings.Source;
  InputState^.Level := ActiveSettings.InputLevel;
  AudInputSourceLevel := ActiveSettings.SourceLevel;
end;

{$S-}
procedure ApplyConfigIRQ;
begin
  if not ConfigPending then Exit;
  if InputOpened or (RequestedSettings.MonitorOn<>0) or
     (ActiveSettings.MonitorOn<>0) then begin
    if not AudMonitorConfigure(RequestedSettings.Source,RequestedSettings.MonitorSource,
      RequestedSettings.InputLevel,
      RequestedSettings.SourceLevel,RequestedSettings.MonitorOn,
      RequestedSettings.MonitorVolume) then begin
      ConfigError := 2; ConfigNeedsSave := False; ConfigPending := False; Exit;
    end;
    if InputOpened then begin
      InputState^.Source := RequestedSettings.Source;
      InputState^.Level := RequestedSettings.InputLevel;
    end;
  end;
  if RequestedSettings.Fader1<>ActiveSettings.Fader1 then VolumePending[0] := True;
  if RequestedSettings.Fader2<>ActiveSettings.Fader2 then VolumePending[1] := True;
  { Restart-only fields deliberately remain the driver's load-time values. }
  if EQChanged then
    AudEqApply(RequestedSettings.EQ.Enabled,RequestedEQ);
  ActiveSettings.EQ := RequestedSettings.EQ;
  if RevChanged then with RequestedSettings.Rev do AudRevApply(Enabled,Preset,Level);
  ActiveSettings.Rev := RequestedSettings.Rev;
  if (RequestedSettings.BassOn<>ActiveSettings.BassOn) or
     (RequestedSettings.BassHz<>ActiveSettings.BassHz) then
    AudBassApply(RequestedSettings.BassOn,RequestedSettings.BassHz);
  ActiveSettings.BassOn := RequestedSettings.BassOn;
  ActiveSettings.BassHz := RequestedSettings.BassHz;
  ActiveSettings.Source := RequestedSettings.Source;
  ActiveSettings.InputLevel := RequestedSettings.InputLevel;
  ActiveSettings.SourceLevel := RequestedSettings.SourceLevel;
  ActiveSettings.Fader1 := RequestedSettings.Fader1;
  ActiveSettings.Fader2 := RequestedSettings.Fader2;
  ActiveSettings.DebugMode := RequestedSettings.DebugMode;
  ActiveSettings.ShutdownMode := RequestedSettings.ShutdownMode;
  ActiveSettings.MonitorOn := RequestedSettings.MonitorOn;
  ActiveSettings.MonitorVolume := RequestedSettings.MonitorVolume;
  ActiveSettings.MonitorSource := RequestedSettings.MonitorSource;
  MonitorPending := False; MonitorFault := False;
  AudInputSourceLevel := ActiveSettings.SourceLevel;
  DebugEnabled := ActiveSettings.DebugMode<>0;
  ShutdownWorkaround := ActiveSettings.ShutdownMode<>0;
  ConfigInputValid := True; ConfigError := 0; ConfigPending := False;
end;
{$S+}

{$S-}
procedure InputEnqueue(Kind: Word; Header: PWaveHdr);
begin
  if (HiWord(InputState^.Flags) and 7)=0 then Exit;
  with InputState^ do begin
    { Count+NoteCount admission reserves four control notification slots. }
    if NoteCount>=NotifyMax then begin Fault := 5; Exit; end;
    with Notes[NoteTail] do begin
      Callback := InputState^.Client.Callback;
      Flags := InputState^.Flags; Instance := InputState^.Client.Instance;
      Device := InputState^.Client.hWave;
      Message := Kind; Param := LongInt(Header);
    end;
    NoteTail := (NoteTail+1) mod NotifyMax; Inc(NoteCount);
  end;
end;

procedure InputReturnHead;
var P: PWaveHdr;
begin
  with InputState^ do begin
    P := Buffers[Head].Header;
    P^.dwBytesRecorded := Buffers[Head].Used-(Buffers[Head].Used mod Align);
    P^.dwFlags := (P^.dwFlags and not LongInt(WHDR_INQUEUE)) or WHDR_DONE;
    Buffers[Head].Header := nil; Buffers[Head].Data := nil;
    Head := NextIndex(Head); Dec(Count);
  end;
  InputEnqueue(WIM_DATA,P);
end;

procedure InputFailure(Code: Word);
begin
  AudCaptureStop;
  InputState^.Running := False; InputState^.Pending := False;
  InputState^.Fault := Code;
  while InputState^.Count<>0 do InputReturnHead;
end;

procedure InputPumpTimer;
var N: Word;
    OK: Boolean;
begin
  if InputState=nil then Exit;
  N := 0;
  while (InputState^.NoteCount<>0) and (N<NotifyMax) do begin
    with InputState^.Notes[InputState^.NoteHead] do
      OK := DriverCallback(Callback,HiWord(Flags) or $0008,
                           Device,Message,Instance,Param,0);
    if not OK then Exit;
    InputState^.NoteHead := (InputState^.NoteHead+1) mod NotifyMax;
    Dec(InputState^.NoteCount); Inc(N);
  end;
end;

function InputObserve: Boolean;
var P,D,Now,Gap,Limit: LongInt;
begin
  Result := False;
  P := AudCapturePosition; Now := timeGetTime;
  with InputState^ do begin
    Gap := Now-LastTick;
    Limit := (LongInt(AudCaptureBytes)-InputGuard)*1000 div BytesPerSec-2;
    if (Gap<0) or (Gap>=Limit) then begin InputFailure(1); Exit; end;
    if Gap>MaxGap then MaxGap := Word(Gap);
    if (P<0) or (P>=AudCaptureBytes) then begin InputFailure(2); Exit; end;
    P := P-(P mod Align);
    D := P-LastPos;
    if D<0 then Inc(D,LongInt(AudCaptureBytes));
    Inc(Produced,D); Inc(Position,D);
    LastPos := P; LastTick := Now;
    if D<>0 then ProgressTick := Now
    else if Now-ProgressTick>=1000 then begin InputFailure(4); Exit; end;
    if Produced-Consumed>=AudCaptureBytes-InputGuard then begin
      InputFailure(3); Exit;
    end;
  end;
  Result := True;
end;

procedure InputTransfer(FinalCopy: Boolean);
var Available,N,Offset,Oldest,Rebase: LongInt;
    SourcePtr,DestPtr: Pointer;
    Steps: Word;
begin
  { A tiny header can straddle a selector, requiring two copies. }
  Steps := QueueMax*2+32;
  with InputState^ do begin
    while Count<>0 do begin
      if Steps=0 then begin InputFailure(6); Exit; end;
      Dec(Steps);
      if Buffers[Head].Used=Buffers[Head].Size then InputReturnHead
      else begin
        Available := Produced-Consumed;
        if not FinalCopy then Dec(Available,InputGuard);
        if Available<=0 then Break;
        Offset := Consumed mod AudCaptureBytes;
        N := Available;
        if N>2048 then N := 2048;
        if N>AudCaptureBytes-Offset then N := AudCaptureBytes-Offset;
        if N>Buffers[Head].Size-Buffers[Head].Used then
          N := Buffers[Head].Size-Buffers[Head].Used;
        DestPtr := DataPointer(Buffers[Head].Data,Buffers[Head].Used);
        if N>$10000-LongInt(Ofs(DestPtr^)) then
          N := $10000-LongInt(Ofs(DestPtr^));
        SourcePtr := AudCaptureData(Word(Offset));
        Oldest := Consumed;
        Move(SourcePtr^,DestPtr^,Word(N));
        { Validate before publishing completion or trusting the copied data. }
        if not FinalCopy then begin
          if not InputObserve then Exit;
          if Produced-Oldest>=AudCaptureBytes-InputGuard then begin
            InputFailure(3); Exit;
          end;
        end;
        Inc(Buffers[Head].Used,N); Inc(Consumed,N); Inc(DeliveredBytes,N);
        if Buffers[Head].Used=Buffers[Head].Size then InputReturnHead;
      end;
    end;
    { The Win16 contract explicitly discards samples while no buffers exist. }
    if Count=0 then begin
      Inc(DroppedBytes,Produced-Consumed); Consumed := Produced;
    end;
    { Keep DMA offsets bounded without resetting the public recording clock. }
    if Consumed>$20000000 then begin
      Rebase := (Consumed div AudCaptureBytes)*AudCaptureBytes;
      Dec(Produced,Rebase); Dec(Consumed,Rebase);
    end;
  end;
end;

procedure InputService;
begin
  if not InputOpened or not InputState^.Running then Exit;
  if InputState^.Pending then begin
    InputState^.Pending := False;
    AudCaptureStart;
    InputState^.LastTick := timeGetTime;
    InputState^.ProgressTick := InputState^.LastTick;
    { ADCIDX may briefly retain the preceding stream's index. As in the
      successful test, first observe it on the NEXT multimedia event. }
    Exit;
  end;
  if InputObserve then InputTransfer(False);
end;

procedure InputStopStream;
var WasRunning: Boolean;
begin
  WasRunning := InputState^.Running;
  if not WasRunning then Exit;
  if not InputState^.Pending then begin
    { Snapshot the last cursor before disabling the ADC. Then the remaining
      guard tail is stable and can be returned without an artificial delay. }
    if InputObserve then begin
      AudCaptureStop; InputTransfer(True);
    end;
  end else AudCaptureStop;
  InputState^.Running := False; InputState^.Pending := False;
  { Stop returns ONLY the current buffer. Later empty buffers stay queued.
    A repeated Stop while already stopped must not return another header. }
  if InputState^.Count<>0 then InputReturnHead;
end;
{$S+}

procedure InputPump;
var N: Word;
    OK: Boolean;
begin
  if InputState=nil then Exit;
  N := 0;
  while (InputState^.NoteCount<>0) and (N<NotifyMax) do begin
    with InputState^.Notes[InputState^.NoteHead] do begin
      if ((HiWord(Flags) and 7)=1) and not IsWindow(HWnd(Word(Callback))) then
        OK := True
      else OK := DriverCallback(Callback,HiWord(Flags) or $0008,
                                Device,Message,Instance,Param,0);
    end;
    if not OK then Exit;
    InputState^.NoteHead := (InputState^.NoteHead+1) mod NotifyMax;
    Dec(InputState^.NoteCount); Inc(N);
  end;
end;

procedure InputReport;
begin
  if not DebugEnabled or (InputState=nil) then Exit;
  with InputState^ do begin
    DriverLog('INPUT: rate='+IntToStr(Rate)+' channels='+IntToStr(Channels));
    DriverLog('INPUT: delivered='+IntToStr(DeliveredBytes)+
              ' discarded='+IntToStr(DroppedBytes));
    DriverLog('INPUT: fault='+IntToStr(Fault)+' maxgap_ms='+IntToStr(MaxGap));
  end;
end;

function InputOpen(User,Param1,Param2: LongInt): LongInt;
var D: PWaveOpenDesc;
    F: PPCMWaveFormat;
begin
  Result := MMSYSERR_INVALPARAM;
  if (Param1=0) or IsBadReadPtr(Pointer(Param1),SizeOf(TWaveOpenDesc)) then Exit;
  D := PWaveOpenDesc(Param1);
  if (D^.lpWaveFormat=nil) or
     IsBadReadPtr(D^.lpWaveFormat,SizeOf(TPCMWaveFormat)) then Exit;
  F := PPCMWaveFormat(D^.lpWaveFormat);
  Result := WAVERR_BADFORMAT;
  if (F^.wf.wFormatTag<>WAVE_FORMAT_PCM) or (F^.wBitsPerSample<>16) or
     ((F^.wf.nChannels<>1) and (F^.wf.nChannels<>2)) or
     not AudCaptureRateValid(F^.wf.nSamplesPerSec) then Exit;
  { Query has no allocation, codec, session or callback side effects. }
  if (Param2 and WAVE_FORMAT_QUERY)<>0 then begin Result := 0; Exit; end;
  Result := MMSYSERR_ALLOCATED;
  if InputOpened then Exit; { one input client; output owns a separate engine }
  if InputState=nil then begin Result := MMSYSERR_NOMEM; Exit; end;
  if InputState^.NoteCount>QueueMax-4 then Exit;
  Result := MMSYSERR_INVALPARAM;
  if (User=0) or IsBadWritePtr(Pointer(User),4) then Exit;
  Result := MMSYSERR_NOTENABLED;
  if not AudIsOpen or (AudTimerID=0) then Exit;
  if not InputConfig then begin Result := MMSYSERR_INVALPARAM; Exit; end;
  if not AudCaptureSetFormat(F^.wf.nSamplesPerSec,F^.wf.nChannels) or
     not AudCapturePrepare(InputState^.Source,InputState^.Level) then begin
    Result := MMSYSERR_ERROR; FlushLog; Exit;
  end;
  with InputState^ do begin
    Client := D^; Flags := Param2;
    Rate := F^.wf.nSamplesPerSec; Bits := 16; Channels := F^.wf.nChannels;
    Align := Channels*2; BytesPerSec := Rate*LongInt(Align);
    Position := 0; Produced := 0; Consumed := 0;
    LastPos := 0; LastTick := 0; ProgressTick := 0;
    DeliveredBytes := 0; DroppedBytes := 0; Fault := 0; MaxGap := 0;
    Head := 0; Tail := 0; Count := 0; Running := False; Pending := False;
  end;
  InputOpened := True; PLongValue(User)^ := LongInt(@InputCookie);
  InputEnqueue(WIM_OPEN,nil);
  DriverLog('INPUT OPEN: standard WaveIn; hardware retained.');
  InputReport; FlushLog; Result := 0;
end;

function InputAdd(Param1,Param2: LongInt): LongInt;
var P: PWaveHdr;
    I,N: Word;
begin
  Result := MMSYSERR_INVALPARAM;
  if (Param1=0) or (Param2<SizeOf(TWaveHdr)) then Exit;
  if IsBadWritePtr(Pointer(Param1),SizeOf(TWaveHdr)) then Exit;
  P := PWaveHdr(Param1);
  Result := WAVERR_UNPREPARED;
  if (P^.dwFlags and WHDR_PREPARED)=0 then Exit;
  Result := WAVERR_STILLPLAYING;
  if (P^.dwFlags and WHDR_INQUEUE)<>0 then Exit;
  I := InputState^.Head; N := InputState^.Count;
  while N<>0 do begin
    if InputState^.Buffers[I].Header=P then Exit;
    I := NextIndex(I); Dec(N);
  end;
  Result := MMSYSERR_INVALPARAM;
  { Unlike playback's historical staging limit, recording is streamed
    directly into the prepared block. Allow normal huge client blocks;
    leave room for normalization of a nonzero starting selector offset. }
  if (P^.dwBufferLength<0) or (P^.dwBufferLength>$7FFEFFFF) or
     ((P^.dwBufferLength mod InputState^.Align)<>0) then Exit;
  if P^.dwBufferLength<>0 then begin
    if P^.lpData=nil then Exit;
    if IsBadHugeWritePtr(P^.lpData,P^.dwBufferLength) then Exit;
  end;
  Result := MMSYSERR_ERROR;
  if InputState^.Fault<>0 then Exit;
  Result := MMSYSERR_NOMEM;
  if InputState^.Count+InputState^.NoteCount>=QueueMax then Exit;
  { Account for previously bufferless input BEFORE admitting this header;
    newly added storage must not receive old samples from that gap. }
  if InputState^.Running and not InputState^.Pending then begin
    if not InputObserve then begin Result := MMSYSERR_ERROR; Exit; end;
    InputTransfer(False);
    if InputState^.Fault<>0 then begin Result := MMSYSERR_ERROR; Exit; end;
  end;
  with InputState^ do begin
    I := Tail;
    Buffers[I].Header := P; Buffers[I].Data := P^.lpData;
    Buffers[I].Size := P^.dwBufferLength; Buffers[I].Used := 0;
    P^.dwBytesRecorded := 0;
    P^.dwFlags := (P^.dwFlags and not LongInt(WHDR_DONE)) or WHDR_INQUEUE;
    Tail := NextIndex(Tail); Inc(Count);
  end;
  Result := 0;
end;

function InputMS(Bytes,BPS: LongInt): LongInt;
var Whole,Remainder: LongInt;
begin
  { Position is a DWORD bit pattern held in Delphi 1's signed LongInt.
    Do not make TIME_MS negative after only 2 GiB of captured audio. }
  Whole := (Bytes and $7FFFFFFF) div BPS;
  Remainder := (Bytes and $7FFFFFFF) mod BPS;
  if Bytes<0 then begin
    Inc(Whole,$7FFFFFFF div BPS);
    Inc(Remainder,($7FFFFFFF mod BPS)+1);
  end;
  Result := Whole*1000+(Remainder*1000) div BPS;
end;

function WidMessage(Device,Message: Word; User,Param1,
                    Param2: LongInt): LongInt; export;
var Caps: TWaveInCaps;
    N: Word;
    P: PMMTime;
    Bytes,BPS: LongInt;
begin
  Result := MMSYSERR_NOTSUPPORTED;
  if Message=WIDM_INIT then begin Result := 0; Exit; end;
  if Message=WIDM_GETNUMDEVS then begin Result := 1; Exit; end;
  if Device<>0 then begin Result := MMSYSERR_BADDEVICEID; Exit; end;
  if not Enabled and (Message<>WIDM_RESET) and (Message<>WIDM_CLOSE) then
    begin Result := MMSYSERR_NOTENABLED; Exit; end;
  if Message=WIDM_GETDEVCAPS then begin
    Result := MMSYSERR_INVALPARAM;
    if (Param1=0) or (Param2<=0) then Exit;
    N := SizeOf(Caps); if Param2<LongInt(N) then N := Word(Param2);
    if IsBadWritePtr(Pointer(Param1),N) then Exit;
    FillChar(Caps,SizeOf(Caps),0);
    Caps.wMid := 0; Caps.wPid := 0; Caps.vDriverVersion := AudDriverVersion;
    StrPCopy(Caps.szPname,'Creative Audigy 1 Recording');
    Caps.dwFormats := $00000CCC; Caps.wChannels := 2;
    Move(Caps,Pointer(Param1)^,N); Result := 0; Exit;
  end;
  if Busy or TimerActive then begin Result := MMSYSERR_ALLOCATED; Exit; end;
  Busy := True;
  if Message=WIDM_OPEN then Result := InputOpen(User,Param1,Param2)
  else if not InputOpened or (User<>LongInt(@InputCookie)) then
    Result := MMSYSERR_INVALHANDLE
  else case Message of
    WIDM_ADDBUFFER: Result := InputAdd(Param1,Param2);
    WIDM_START: begin
      Result := MMSYSERR_ERROR;
      if InputState^.Fault=0 then begin
        if not InputState^.Running then begin
          InputState^.Produced := 0; InputState^.Consumed := 0;
          InputState^.LastPos := 0;
          InputState^.Pending := True; InputState^.Running := True;
          DriverLog('INPUT START: deferred to resident multimedia timer.');
        end;
        Result := 0;
      end;
    end;
    WIDM_STOP: begin
      InputStopStream; InputReport; FlushLog; Result := 0;
    end;
    WIDM_RESET: begin
      { Reset, unlike Stop, returns EVERY queued header, even unused ones. }
      InputStopStream;
      while InputState^.Count<>0 do InputReturnHead;
      InputState^.Head := 0; InputState^.Tail := 0;
      InputReport;
      InputState^.Position := 0; InputState^.Produced := 0;
      InputState^.Consumed := 0; InputState^.Fault := 0;
      FlushLog; Result := 0;
    end;
    WIDM_CLOSE: begin
      Result := WAVERR_STILLPLAYING;
      if InputState^.Count=0 then begin
        InputStopStream; AudCaptureClose; InputOpened := False;
        InputEnqueue(WIM_CLOSE,nil);
        DriverLog('INPUT CLOSE: standard WaveIn; timer/mapping retained.');
        InputReport; FlushLog; Result := 0;
      end;
    end;
    WIDM_GETPOS: begin
      Result := MMSYSERR_INVALPARAM;
      if (Param1<>0) and (Param2>=SizeOf(TMMTime)) then
        if not IsBadWritePtr(Pointer(Param1),SizeOf(TMMTime)) then begin
          if InputState^.Running and not InputState^.Pending then begin
            if InputObserve then InputTransfer(False);
          end;
          P := PMMTime(Param1);
          Bytes := InputState^.Position; BPS := InputState^.BytesPerSec;
          case P^.wType of
            TIME_MS: P^.ms := InputMS(Bytes,BPS);
            TIME_SAMPLES: begin
              P^.sample := (Bytes and $7FFFFFFF) div InputState^.Align;
              if Bytes<0 then
                Inc(P^.sample,($7FFFFFFF div InputState^.Align)+1);
            end;
          else
            P^.wType := TIME_BYTES; P^.cb := Bytes;
          end;
          Result := 0;
        end;
    end;
    { Leave generic MMSYSTEM preparation to lock/mark client memory, just
      like the confirmed waveOut implementation. Do not fake PREPARED. }
    WIDM_PREPARE,WIDM_UNPREPARE: Result := MMSYSERR_NOTSUPPORTED;
  end;
  InputPump;
  Busy := False;
end;
