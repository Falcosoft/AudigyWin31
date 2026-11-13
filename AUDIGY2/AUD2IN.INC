{ Audigy 2 capture implementation inside Aud2HW's resident code segment.
  Register names and capture sequence: Linux ALSA emu10k1 emupcm.c,
  emufx.c, emumixer.c, include/sound/emu10k1.h and
  include/uapi/sound/emu10k1.h.
  See A2REF.TXT and CAPREF.TXT. Playback instructions/voice setup retained. }

{$S-} { bounded codec I/O is also used by resident source switching }
function CodecRead(Index: Byte): Word;
var Flags: Word;
begin
  asm
    pushf
    pop ax
    mov Flags,ax
    cli
  end;
  Port[IOBase+$1E] := Index;
  Result := PortW[IOBase+$1C];
  asm
    mov ax,Flags
    push ax
    popf
  end;
end;

procedure CodecWrite(Index: Byte; Value: Word);
var Flags: Word;
begin
  asm
    pushf
    pop ax
    mov Flags,ax
    cli
  end;
  Port[IOBase+$1E] := Index;
  PortW[IOBase+$1C] := Value;
  asm
    mov ax,Flags
    push ax
    popf
  end;
end;

procedure InputCodecRestore;
var I: Word;
begin
  if not CapCodecSaved then Exit;
  for I:=0 to 12 do CodecWrite(CapCodecRegs[I],CapCodecValues[I]);
  CapCodecSaved := False; CodecRouteSource := $FFFF;
end;

function InputCodecBegin: Boolean;
var I: Word;
begin
  Result := False;
  if not Ready or ((Port[IOBase+$1E] and $80)=0) then Exit;
  if CapCodecSaved then begin Result := True; Exit; end;
  if not CapCodecSaved then begin
    for I:=0 to 12 do CapCodecValues[I] := CodecRead(CapCodecRegs[I]);
    CapCodecSaved := True; CodecRouteSource := $FFFF;
  end;
  CodecWrite($26,CodecRead($26) and $8000);
  CodecWrite($02,0); CodecWrite($18,$8000);
  Result := True;
end;

function RoutePhysicalSource(Source,AnalogLevel: Word): Boolean;
var SelectedReg,V: Word;
begin
  Result := False;
  if (Source>5) or (AnalogLevel>100) then Exit;
  { Digital inputs bypass AC97; their readiness is not codec readiness. }
  if Source>=4 then begin Result := True; Exit; end;
  if not InputCodecBegin then Exit;
  { Physical monitoring and recording can share this route. Wave
    itself never selects an analog input or feeds the monitor input. }
  if CodecRouteSource<>Source then begin
    CodecWrite($0A,$8000); CodecWrite($0C,$8000);
    CodecWrite($0E,$8000); CodecWrite($10,$8000);
    CodecWrite($12,$8000); CodecWrite($14,$8000); CodecWrite($16,$8000);
    if Source=1 then begin CodecWrite($1A,0); CodecWrite($1C,0); end;
  end;
  if (Source=0) or (Source=2) or (Source=3) then begin
    SelectedReg := $10;
    if Source=2 then SelectedReg := $12;
    if Source=3 then SelectedReg := $16;
    if AnalogLevel=0 then V := $8000
    else begin
      V := 16-Word((LongInt(AnalogLevel)*16+50) div 100);
      V := (V shl 8) or V;
    end;
    CodecWrite(Byte(SelectedReg),V);
  end;
  CodecRouteSource := Source; Result := True;
end;

procedure CaptureInputs(Source: Word; var InputLeft,InputRight: Word);
begin
  InputLeft := CaptureChip.AnalogLeft; InputRight := CaptureChip.AnalogRight;
  if Source=1 then begin
    InputLeft := CaptureChip.MicLeft; InputRight := CaptureChip.MicRight;
  end else if Source=4 then begin
    InputLeft := $42; InputRight := $43; { A_EXTIN SPDIF_CD +40h }
  end else if Source=5 then begin
    InputLeft := $44; InputRight := $45; { A_EXTIN OPT_SPDIF +40h }
  end else if Source=6 then begin
    { Prior DSP frame's sum of BOTH PCM buses, BEFORE either volume stage.
      The extra one-sample delay keeps capture slots8/9 and all input paths. }
    InputLeft := $428; InputRight := $429;
  end;
end;

function AudCaptureRoute(Source,Level,AnalogLevel: Word): Boolean;
var InputLeft,InputRight: Word;
    Gain: LongInt;
begin
  Result := False;
  if not Ready or (Source>6) or
     (Level>100) or (AnalogLevel>100) then Exit;
  { Wave stays wholly inside the DSP and needs no codec ownership. }
  if Source<6 then
    if not RoutePhysicalSource(Source,AnalogLevel) then Exit;
  CaptureInputs(Source,InputLeft,InputRight);
  if CapRouteSource<>Source then begin
    { Mute only the capture DSP coefficients while changing its route.
      Do NOT touch ADCBS/ADCCR/ADCBA/index, playback voices or client queues. }
    WriteReg($40C,0,0); WriteReg($40D,0,0);
    { Same two capture instructions as the successful prepare path. }
    WriteReg($610,0,(LongInt($40C) shl 12) or InputLeft);
    WriteReg($611,0,(LongInt(CaptureChip.OutputLeft) shl 12) or $C0);
    WriteReg($612,0,(LongInt($40D) shl 12) or InputRight);
    WriteReg($613,0,(LongInt(CaptureChip.OutputRight) shl 12) or $C0);
  end;
  Gain := ($7FFFFFFF div 100)*LongInt(Level)+
          (($7FFFFFFF mod 100)*LongInt(Level)) div 100;
  WriteReg($40C,0,Gain); WriteReg($40D,0,Gain);
  CapRouteSource := Source; AudInputSourceLevel := AnalogLevel;
  Result := True;
end;

function AudMonitorConfigure(Source,MonitorSource,Level,AnalogLevel,
                             MonitorOn,MonitorVolume: Word): Boolean;
var InputLeft,InputRight: Word;
begin
  Result := False;
  if not Ready or (Source>6) or (MonitorSource>5) or
     (Level>100) or (AnalogLevel>100) or
     (MonitorOn>1) then Exit;
  if Source=6 then MonitorOn := 0; { never monitor Wave back to itself }
  { Check readiness before changing either the monitor or capture route.
    No waiting, allocation, DMA changes or task APIs in this IRQ path. }
  if MonitorOn<>0 then
    if not RoutePhysicalSource(MonitorSource,AnalogLevel) then Exit;
  if CapPrepared then begin
    if not AudCaptureRoute(Source,Level,AnalogLevel) then Exit;
  end;
  MonitorGain := 0;
  WriteReg($410,0,0); WriteReg($411,0,0);
  WriteReg($412,0,0); WriteReg($413,0,0);
  MonitorEnabled := MonitorOn<>0;
  if MonitorEnabled then begin
    CaptureInputs(MonitorSource,InputLeft,InputRight);
    { AUD1MON2: write each complete instruction, low word then high word,
      matching the working capture path. Do not rely on half-code updates. }
    WriteReg($614,0,(LongInt($410) shl 12) or InputLeft);
    WriteReg($615,0,(LongInt($420) shl 12) or $C0);
    WriteReg($616,0,(LongInt($411) shl 12) or InputRight);
    WriteReg($617,0,(LongInt($421) shl 12) or $C0);
    WriteReg($618,0,(LongInt($412) shl 12) or InputLeft);
    WriteReg($619,0,(LongInt($422) shl 12) or $C0);
    WriteReg($61A,0,(LongInt($413) shl 12) or InputRight);
    WriteReg($61B,0,(LongInt($423) shl 12) or $C0);
    MonitorGain := VolumeGain(MonitorVolume);
    WriteReg($410,0,MonitorGain); WriteReg($411,0,MonitorGain);
    WriteReg($412,0,MonitorGain); WriteReg($413,0,MonitorGain);
  end;
  if not CapPrepared then begin WriteReg($40C,0,0); WriteReg($40D,0,0); end;
  if not MonitorEnabled and (not CapPrepared or (Source=6)) then InputCodecRestore;
  Result := True;
end;

procedure AudCaptureStop;
begin
  if not Touched then Exit;
  { Stop host DMA before releasing or remapping its storage. }
  WriteReg(CaptureChip.SizeReg,0,0); { ADCBS: NONE }
  WriteReg(CaptureChip.ControlReg,0,0); { both channels disabled }
end;
{$S+}

procedure AudCaptureClose;
begin
  if CapPrepared or CapCodecSaved then AudCaptureStop;
  if Touched then begin
    { Silence the capture slots without halting the working DSP. }
    WriteReg($40C,0,0); WriteReg($40D,0,0);
    { A recording handle does not own the live monitor route. }
  end;
  if not MonitorEnabled then InputCodecRestore;
  if CapPrepared and Touched then WriteReg(CaptureChip.BaseReg,0,0);
  { End a stream, not the driver's memory ownership. In particular, never
    free/unmap aliases from the recording application's task. FreeRAM
    releases the single driver mapping only during hardware teardown. }
  CapPrepared := False;
  CapRouteSource := $FFFF;
end;

function AudCapturePrepare(Source,Level: Word): Boolean;
var InputLeft, InputRight: Word;
    Deadline: LongInt;
begin
  Result := False;
  if not Ready or (CapSel=0) or (Source>6) or (Level>100) or
     (AudInputSourceLevel>100) then Exit;
  AudCaptureClose;
  { ADCBA still addresses physical contiguous RAM, not the playback PTB.
    Its CPU alias was already created with playback at DRV_LOAD. }
  FillChar(Ptr(CapSel,0)^,AudCaptureBytes,0);
  if Source<4 then begin
    { Never hold the shared Busy gate for a codec wait during playback. }
    if AudAnyStreaming and ((Port[IOBase+$1E] and $80)=0) then begin
      Say('CAPTURE FAIL: codec not ready during playback.');
      AudCaptureClose; Exit;
    end;
    Deadline := timeGetTime;
    while (Port[IOBase+$1E] and $80)=0 do
      if timeGetTime-Deadline>=100 then begin
        Say('CAPTURE FAIL: AC97 codec not ready.');
        AudCaptureClose; Exit;
      end;
    if not InputCodecBegin then begin AudCaptureClose; Exit; end;
    Say('CAPTURE: codec ID=$'+IntToHex(CodecRead($7C),4)+
        IntToHex(CodecRead($7E),4));
  end;
  if not AudCaptureRoute(Source,Level,AudInputSourceLevel) then begin
    Say('CAPTURE FAIL: source routing unavailable.'); AudCaptureClose; Exit;
  end;
  CaptureInputs(Source,InputLeft,InputRight);
  Say('CAPTURE: source='+IntToStr(Source)+' level='+IntToStr(Level));
  if (Source=0) or (Source=2) or (Source=3) then
    Say('CAPTURE: analog source level='+IntToStr(AudInputSourceLevel));
  AudCaptureStop;
  WriteReg(CaptureChip.BaseReg,0,RAMBase+AudRAMBytes); { ADCBA: physical, not linear }
  if (ReadReg(CaptureChip.BaseReg,0)<>RAMBase+AudRAMBytes) or
     (ReadReg($610,0)<>((LongInt($40C) shl 12) or InputLeft)) or
     (ReadReg($611,0)<>((LongInt(CaptureChip.OutputLeft) shl 12) or $C0)) or
     (ReadReg($612,0)<>((LongInt($40D) shl 12) or InputRight)) or
     (ReadReg($613,0)<>((LongInt(CaptureChip.OutputRight) shl 12) or $C0)) then begin
    Say('CAPTURE FAIL: DMA/DSP readback.'); AudCaptureClose; Exit;
  end;
  CapPrepared := True;
  Say('CAPTURE: physical=$'+IntToHex(RAMBase+AudRAMBytes,8)+
      ' bytes=32768; rate='+IntToStr(CapRate)+
      ' bits=16 channels='+IntToStr(CapChannels));
  Say('CAPTURE: INTE stays zero; resident multimedia timer polls A_ADCIDX.');
  Result := True;
end;

function AudCaptureRateValid(Rate: LongInt): Boolean;
begin
  { Delphi 1 rejects the high rate constants in a CASE here. Keep the
    selector as LongInt and use comparisons, without narrowing casts. }
  Result := (Rate=8000) or (Rate=11025) or (Rate=16000) or
            (Rate=22050) or (Rate=24000) or (Rate=32000) or
            (Rate=44100) or (Rate=48000);
end;

function AudCaptureSetFormat(Rate: LongInt; Channels: Word): Boolean;
var Code: Word;
begin
  Result := False;
  if not AudCaptureRateValid(Rate) or
     ((Channels<>1) and (Channels<>2)) then Exit;
  if CapPrepared then Exit;
  { Native Audigy ADC SRC rates, NOT the SB Live! low-rate encodings.
    ALSA emupcm.c / emu10k1.h: Audigy 11.025k=7, 8k=8. }
  if Rate=48000 then Code := 0
  else if Rate=44100 then Code := 1
  else if Rate=32000 then Code := 2
  else if Rate=24000 then Code := 3
  else if Rate=22050 then Code := 4
  else if Rate=16000 then Code := 5
  else if Rate=11025 then Code := 7
  else Code := 8;
  CapRate := Rate; CapChannels := Channels;
  CapControl := $10 or LongInt(Code);
  if Channels=2 then CapControl := CapControl or $20;
  Result := True;
end;

{$S-}
procedure AudCaptureStart;
begin
  if not Ready or not CapPrepared then Exit;
  AudCaptureStop;
  { Both channels were disabled first; mono enables the left ADC only. }
  WriteReg(CaptureChip.ControlReg,0,CapControl);
  { ADCBS: 32768 bytes; this starts host capture. }
  WriteReg(CaptureChip.SizeReg,0,CaptureChip.Ring32K);
end;

function AudCapturePosition: LongInt;
begin
  Result := 0;
  if CapPrepared then Result := ReadReg(CaptureChip.IndexReg,0) and $FFFF;
end;

function AudCaptureData(Offset: Word): Pointer;
begin
  Result := Ptr(CapSel,Offset);
end;
{$S+}

procedure AudCaptureDump;
begin
  if not CapPrepared then Exit;
  Say('CAPTURE REGS: ADCCR=$'+IntToHex(ReadReg(CaptureChip.ControlReg,0),8)+
      ' ADCBA=$'+IntToHex(ReadReg(CaptureChip.BaseReg,0),8));
  Say('CAPTURE REGS: ADCBS=$'+IntToHex(ReadReg(CaptureChip.SizeReg,0),8)+
      ' A_ADCIDX=$'+IntToHex(ReadReg(CaptureChip.IndexReg,0),8));
end;
