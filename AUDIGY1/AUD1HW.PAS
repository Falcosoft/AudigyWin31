unit Aud1HW;

{ Creative Audigy 1 native Windows 3.1 playback/capture hardware backend.
  Delphi 1, 386+ instructions. Adapted from VSBHDA SBLIVE.C and ALSA.
  See SOURCES.TXT and COPYING.TXT. Deadline-based ring streaming; no card IRQ handler.
  The full reserved region is 256 KiB: existing 116 KiB playback/capture,
  12 KiB optional private PCM ring in the existing alignment gap, and
  128 KiB reverb delay memory at offset $20000.
  All CPU selector windows are smaller than 64 KiB. }

{$C FIXED PRELOAD PERMANENT}
{$G+}
{$F+}
{$R-}
{$Q-}

interface
uses AudEQ;

type
  TAudLog = procedure(const S: string);
  { Return actual output bytes copied, frame aligned, in the range 0..Bytes.
    A short result leaves the rest pending; do not write/consume that tail. }
  TAudFill = function(Destination: Pointer; Bytes: Word;
                      OutputOffset: LongInt): Word;

const
  AudRate = 48000;
  AudBassMinHz = 60;
  AudBassMaxHz = 160;
  AudBassStepHz = 5;
  AudBassSteps = (AudBassMaxHz-AudBassMinHz) div AudBassStepHz;
  AudBassDefaultHz = 100;
  AudRAMBytes = $15000; { playback mapping: unchanged }
  AudCaptureBytes = 32768; { additional RESERVED physical capture ring }
  AudMapBytes = $40000; { 256 KiB total, TRAM at physical base+$20000 }
  AudBufferMinMS = 10;
  AudBufferDefaultMS = 40;
  AudBufferMaxMS = 60;
  AudSliceMinMS = 5;
  AudSliceDefaultMS = 10;
  AudSliceMaxMS = 30;
  AudCacheGuardBytes = 512;
  { Covers the initial CCCA offset and stereo cache prefetch. }
  AudStartupFrames = 128;
  AudStartupBytes = AudStartupFrames*4;
  AudOplPlayback = 2; { never exposed as a WaveOut device }

var
  { Active ring geometry. Physical mapping stays 48 KiB maximum.
    The physical half supplies nominal fill-ahead; slices bound copy work.
    Unfilled, precleared bytes stay pending until their safe deadline. }
  AudBufferHalfMS, AudRefillSliceMS: Word;
  AudInputSourceLevel: Word; { analog Line/CD/Aux, 0..100; 50 = nominal 0 dB }
  AudOplEnabled: Boolean;

function AudOpen(PhysicalBase: LongInt; CardIndex: Word;
                 LogProc: TAudLog; FillProc,OplFillProc: TAudFill): Boolean;
{ Selection is serialized by the DLL's existing Busy/TimerActive gate. }
procedure AudSelectPlayback(Device: Word);
function AudAnyStreaming: Boolean;
procedure AudSetSynthRate(Rate: Word);
function AudOplAvailable: Boolean;
function AudOplSilentBytes: LongInt;
function AudOplWriteTotal: LongInt;
procedure AudOplFault(var Code: Word; var Value: LongInt);
procedure AudStopAll;
procedure AudStart;
procedure AudStop;
function AudPause: Boolean;
function AudResume: Boolean;
function AudSetRate(Rate: LongInt): Boolean;
procedure AudSetVolume(Device,Left,Right,Fader: Word);
procedure AudEqApply(OnOff: Word; const P: TEqProgram);
procedure AudRevApply(OnOff,Preset,Level: Word);
procedure AudBassApply(OnOff,Hz: Word);
procedure AudClose;
function AudPosition: LongInt;
procedure AudDump;
function AudIsOpen: Boolean;
function AudService: Boolean;
function AudRefillCount: LongInt;
procedure AudStreamReport;
function AudPlayedThrough: LongInt;
function AudIsStreaming: Boolean;
function AudCapturePrepare(Source,Level: Word): Boolean;
function AudCaptureRateValid(Rate: LongInt): Boolean;
function AudCaptureSetFormat(Rate: LongInt; Channels: Word): Boolean;
function AudCaptureRoute(Source,Level,AnalogLevel: Word): Boolean;
function AudMonitorConfigure(Source,MonitorSource,Level,AnalogLevel,
                             MonitorOn,MonitorVolume: Word): Boolean;
procedure AudCaptureStart;
procedure AudCaptureStop;
procedure AudCaptureClose;
function AudCapturePosition: LongInt;
function AudCaptureData(Offset: Word): Pointer;
procedure AudCaptureDump;

implementation

uses WinTypes, WinProcs, MMSystem, SysUtils, PCI, AudTime;

{$I AUD1REG.INC}

type
  TPageTable = array[0..8191] of LongInt;
  PPageTable = ^TPageTable;
  { The standard 16-bit ADC DMA engine exists on EMU10K1 and EMU10K2.
    This descriptor is Audigy1 ONLY. Future backends supply their own
    register fields AND DSP/analog-source routing. No P16V dependency. }
  TCaptureChip = record
    BaseReg, SizeReg, ControlReg, IndexReg: Word;
    Ring32K: LongInt;
    AnalogLeft, AnalogRight, MicLeft, MicRight: Word;
    OutputLeft, OutputRight: Word;
  end;
  TSilentPage = array[0..4095] of Byte;
  PSilentPage = ^TSilentPage;
  TSampleBuffer = array[0..24575] of Integer; { Integer is 16-bit in Delphi 1 }
  PSampleBuffer = ^TSampleBuffer;
  TTramChunk = array[0..8191] of LongInt;
  PTramChunk = ^TTramChunk;

type
  THWPlayback = record
  AudHalfFrames, AudFrames, AudHalfBytes, AudPCMBytes: Word;
  AudLeadBytes, AudDrainBytes, AudHalfMS: Word;
  AudSliceFrames, AudSliceBytes, AudSliceMS, AudSlicesPerHalf: Word;
  Streaming, HardwarePaused: Boolean;
  PlayRate, PlayPitch, InterpROM: LongInt;
  FetchTotal, LastFetch, CursorOrigin: LongInt;
  { Absolute output-byte offsets, NOT modulo positions. ClearTotal is the
    end of safe zeroed storage; WriteTotal is the next uncommitted byte. }
  WriteTotal, ClearTotal, SilentBytes, RetryFills, Catchups: LongInt;
  ServiceTick, Refills, MaxFillMS, MaxServiceMS, MinSlack, Misses: LongInt;
  FaultCode: Word;
  FaultValue: LongInt;
    VoiceFirst, RingOffset: Word;
    FrameBase: LongInt;
  end;
  PHWPlayback = ^THWPlayback;
var
  Playbacks: array[0..AudOplPlayback] of THWPlayback;
  Playback: PHWPlayback;
  Log: TAudLog;
  PublicSupply,OplSupply: TAudFill;
  Bus, DevFn, Revision: Byte;
  IOBase, OldCommand: Word;
  RAMBase, LinearBase: LongInt;
  TableSel, SilentSel, PCMSel, OplDMASel: Word;
  Table: PPageTable;
  Silence: PSilentPage;
  Samples: PSampleBuffer;
  Ready, Touched, Mapped, CommandChanged: Boolean;
  CapSel: Word;
  CapPrepared, CapCodecSaved: Boolean;
  CapCodecValues: array[0..12] of Word;
  CapRate: LongInt;
  CapChannels: Word;
  CapControl: LongInt;
  CapRouteSource, CodecRouteSource: Word;
  MonitorEnabled: Boolean;
  MonitorGain: LongInt;

const
  CaptureChip: TCaptureChip = (
    BaseReg:$46; SizeReg:$4A; ControlReg:$42; IndexReg:$63;
    Ring32K:$1B;
    AnalogLeft:$4A; AnalogRight:$4B; MicLeft:$40; MicRight:$41;
    OutputLeft:$76; OutputRight:$77);
  CapCodecRegs: array[0..12] of Byte =
    ($02,$0A,$0C,$0E,$10,$12,$14,$16,$18,$1A,$1C,$20,$26);

{$S-}
procedure AudSelectPlayback(Device: Word);
begin
  if Device<=AudOplPlayback then Playback := @Playbacks[Device];
end;

function AudAnyStreaming: Boolean;
begin
  Result := Playbacks[0].Streaming or Playbacks[1].Streaming;
end;

function AudOplAvailable: Boolean;
begin
  Result := Ready and (OplDMASel<>0);
end;

function AudOplSilentBytes: LongInt;
begin
  Result := Playbacks[AudOplPlayback].SilentBytes;
end;

function AudOplWriteTotal: LongInt;
begin
  Result := Playbacks[AudOplPlayback].WriteTotal;
end;

procedure AudOplFault(var Code: Word; var Value: LongInt);
begin
  Code := Playbacks[AudOplPlayback].FaultCode;
  Value := Playbacks[AudOplPlayback].FaultValue;
end;

procedure AudStopAll;
var Saved: PHWPlayback;
    I: Word;
begin
  Saved := Playback;
  for I:=0 to 1 do begin Playback := @Playbacks[I]; AudStop; end;
  if OplDMASel<>0 then begin Playback := @Playbacks[AudOplPlayback]; AudStop; end;
  Playback := Saved;
end;

function PCMAddress(Position: LongInt): Pointer;
begin
  if Playback=@Playbacks[AudOplPlayback] then
    Result := Ptr(OplDMASel,Word(Position mod Playback^.AudPCMBytes))
  else Result := Ptr(PCMSel,Playback^.RingOffset+
                     Word(Position mod Playback^.AudPCMBytes));
end;

function FillPlayback(Destination: Pointer; Bytes: Word;
                      Offset: LongInt): Word;
begin
  if Playback=@Playbacks[AudOplPlayback] then
    Result := OplSupply(Destination,Bytes,Offset)
  else Result := PublicSupply(Destination,Bytes,Offset);
end;
{$S+}

procedure Say(const S: string);
begin
  if Assigned(Log) then Log(S);
end;

{$S-} { interrupt path: no task-stack RTL check }
function In32(PortNo: Word): LongInt;
begin
  asm
    mov dx,PortNo
    db 66h; in ax,dx
    db 66h; mov word ptr Result,ax
  end;
end;

{$S+}
{$S-} { interrupt path: no task-stack RTL check }
procedure Out32(PortNo: Word; Value: LongInt);
begin
  asm
    mov dx,PortNo
    db 66h; mov ax,word ptr Value
    db 66h; out dx,ax
  end;
end;

{ Indexed port pairs must not be interrupted between pointer and data.
  Restore the original FLAGS; never unconditionally enable interrupts. }
{$S+}
{$S-} { interrupt path: no task-stack RTL check }
function ReadReg(RegNo, Voice: Word): LongInt;
var Flags: Word;
begin
  asm
    pushf
    pop ax
    mov Flags,ax
    cli
  end;
  Out32(IOBase, (LongInt(RegNo) shl 16) or Voice);
  Result := In32(IOBase+4);
  asm
    mov ax,Flags
    push ax
    popf
  end;
end;

{$S+}
{$S-} { interrupt path: no task-stack RTL check }
procedure WriteReg(RegNo, Voice: Word; Value: LongInt);
var Flags: Word;
begin
  asm
    pushf
    pop ax
    mov Flags,ax
    cli
  end;
  Out32(IOBase, (LongInt(RegNo) shl 16) or Voice);
  Out32(IOBase+4, Value);
  asm
    mov ax,Flags
    push ax
    popf
  end;
end;

{$S+}
function MapRAM(Phys, Size: LongInt; var Lin: LongInt): Boolean;
var OK: Boolean;
    L: LongInt;
begin
  OK := False;
  L := 0;
  asm
    push si
    push di
    mov bx,word ptr Phys+2
    mov cx,word ptr Phys
    mov si,word ptr Size+2
    mov di,word ptr Size
    mov ax,0800h
    int 31h
    jc @Failed
    mov word ptr L,cx
    mov word ptr L+2,bx
    mov OK,1
  @Failed:
    pop di
    pop si
  end;
  Lin := L;
  Result := OK;
end;

procedure UnmapRAM(Lin: LongInt);
begin
  asm
    mov bx,word ptr Lin+2
    mov cx,word ptr Lin
    mov ax,0801h
    int 31h
  end;
  { Some DPMI 0.9 hosts do not implement 0801h. Selectors are still freed;
    any remaining mapping belongs to this process until it terminates. }
end;

function SetLimit(Sel: Word; Limit: LongInt): Boolean;
var OK: Boolean;
begin
  OK := False;
  asm
    mov ax,0008h
    mov bx,Sel
    mov cx,word ptr Limit+2
    mov dx,word ptr Limit
    int 31h
    jc @Failed
    mov OK,1
  @Failed:
  end;
  Result := OK;
end;

function MakeSelector(Base, Size: LongInt): Word;
var Sel: Word;
begin
  Result := 0;
  Sel := AllocSelector(DSeg);
  if Sel=0 then Exit;
  SetSelectorBase(Sel, Base);
  if (GetSelectorBase(Sel)<>Base) or not SetLimit(Sel,Size-1) then
    FreeSelector(Sel)
  else Result := Sel;
end;

procedure FreeRAM;
begin
  { All aliases belong to the single mapping acquired at DRV_LOAD. }
  if CapSel<>0 then FreeSelector(CapSel);
  CapSel := 0;
  if OplDMASel<>0 then FreeSelector(OplDMASel);
  OplDMASel := 0;
  if PCMSel<>0 then FreeSelector(PCMSel);
  if SilentSel<>0 then FreeSelector(SilentSel);
  if TableSel<>0 then FreeSelector(TableSel);
  PCMSel := 0;
  SilentSel := 0;
  TableSel := 0;
  Samples := nil;
  Silence := nil;
  Table := nil;
  if Mapped then UnmapRAM(LinearBase);
  Mapped := False;
end;

{ The initial 512 bytes are a silent lead-in. They keep samples away from the
  cache initialization region without changing the validated voice setup. }
{$S-} { interrupt path: no task-stack RTL check }
procedure ZeroPCM(Destination: Pointer; Bytes: Word); assembler;
asm
  pushf
  push es
  push di
  les di,Destination
  mov cx,Bytes
  shr cx,1
  xor ax,ax
  cld
  rep stosw
  pop di
  pop es
  popf
end;

{$S+}
{$S-} { interrupt path: no task-stack RTL check }
function TransferSize(Position, Limit: LongInt): Word;
var N, Offset: LongInt;
begin
  with Playback^ do begin
    { Never cross a logical slice, physical ring end, or caller's limit. }
    Offset := Position mod AudPCMBytes;
    N := AudSliceBytes-(Offset mod AudSliceBytes);
    if N>Limit-Position then N := Limit-Position;
    if N<0 then N := 0;
    Result := Word(N and not LongInt(3));
  end;
end;

{$S-} { timer startup: resident integer state and PCM fills only }
procedure PrimeStream;
var N, Used: Word;
    Passes: Word;
begin
  with Playback^ do begin
    FetchTotal := 0; LastFetch := 0; CursorOrigin := 0;
    Refills := 0; MaxFillMS := 0; MaxServiceMS := 0;
    FaultCode := 0; FaultValue := 0;
    MinSlack := AudHalfBytes; Misses := 0;
    SilentBytes := 0; RetryFills := 0; Catchups := 0;
    ZeroPCM(PCMAddress(0),AudPCMBytes);
    ClearTotal := AudPCMBytes;
    WriteTotal := AudStartupBytes;
    { Voice/cache initialization is unchanged. The startup silence may span
      several slices. Missing source is NOT committed to a whole silent slice. }
    Passes := AudSlicesPerHalf*2+1;
    while (WriteTotal<ClearTotal) and (Passes<>0) do begin
      Dec(Passes);
      N := TransferSize(WriteTotal,ClearTotal);
      Used := FillPlayback(PCMAddress(WriteTotal),N,WriteTotal);
      if (Used>N) or ((Used and 3)<>0) then begin
        FaultCode := 7; FaultValue := Used; Exit;
      end;
      Inc(WriteTotal,LongInt(Used));
      if Used<N then Break;
    end;
  end;
end;

{$S+}
function PrepareRAM: Boolean;
var I,Sel: Word;
    ClearOK: Boolean;
begin
  Result := False;
  if not MapRAM(RAMBase,AudMapBytes,LinearBase) then begin
    Say('FAIL: DPMI 0800h could not map the physical RAM region.');
    Exit;
  end;
  Mapped := True;
  Say('RAM physical=$'+IntToHex(RAMBase,8)+
      ' linear=$'+IntToHex(LinearBase,8));
  TableSel := MakeSelector(LinearBase,$8000);
  SilentSel := MakeSelector(LinearBase+$8000,$1000);
  PCMSel := MakeSelector(LinearBase+$9000,$C000);
  CapSel := MakeSelector(LinearBase+AudRAMBytes,AudCaptureBytes);
  if (TableSel=0) or (SilentSel=0) or (PCMSel=0) or (CapSel=0) then begin
    Say('FAIL: could not create the four RAM selectors.');
    Exit;
  end;
  Table := Ptr(TableSel,0);
  Silence := Ptr(SilentSel,0);
  Samples := Ptr(PCMSel,0);
  FillChar(Silence^,SizeOf(TSilentPage),0);
  FillChar(Samples^,SizeOf(TSampleBuffer),0);
  FillChar(Ptr(CapSel,0)^,AudCaptureBytes,0);
  { 8192 entries: initialize the full hardware page table, including PTI
    bits in every entry. Physical addresses, never CPU linear addresses. }
  for I:=0 to 8191 do
    Table^[I] := ((RAMBase+$8000) shl 1) or LongInt(I);
  for I:=0 to 11 do
    Table^[I] := ((RAMBase+$9000+LongInt(I)*4096) shl 1) or LongInt(I);
  if AudOplEnabled and Assigned(OplSupply) then begin
    OplDMASel := MakeSelector(LinearBase+$1D000,$3000);
    if OplDMASel<>0 then begin
      ZeroPCM(Ptr(OplDMASel,0),$3000);
      if (PSilentPage(Ptr(OplDMASel,0))^[0]<>0) or
         (PSilentPage(Ptr(OplDMASel,$2000))^[4095]<>0) then begin
        FreeSelector(OplDMASel); OplDMASel := 0;
      end;
      if OplDMASel<>0 then begin
        for I:=12 to 14 do
          Table^[I] := ((RAMBase+$1D000+LongInt(I-12)*4096) shl 1) or LongInt(I);
        Say('OPL PCM: 12 KiB of existing reserved RAM; voices 4/5.');
      end;
    end;
    if OplDMASel=0 then Say('OPL PCM: optional RAM alias failed; public audio unchanged.');
  end;
  if (Table^[0]<>((RAMBase+$9000) shl 1)) or
     (Table^[8191]<>(((RAMBase+$8000) shl 1) or $1FFF)) or
     (Samples^[0]<>0) or (Samples^[23999]<>0) then begin
    Say('FAIL: RAM readback did not match table/silence data.');
    Exit;
  end;
  Say('RAM verified: table 32 KiB, silence 4 KiB, two PCM rings of 24 KiB.');
  Say('CAPTURE RAM: extra 32 KiB; mapping/selector owned by driver lifetime.');
  { Clear 128 KiB external TRAM using four temporary 32 KiB windows. }
  for I:=0 to 3 do begin
    Sel := MakeSelector(LinearBase+$20000+LongInt(I)*$8000,$8000);
    if Sel=0 then begin Say('FAIL: reverb RAM selector.'); Exit; end;
    ZeroPCM(Ptr(Sel,0),$8000);
    ClearOK := (PTramChunk(Ptr(Sel,0))^[0]=0) and
               (PTramChunk(Ptr(Sel,0))^[8191]=0);
    FreeSelector(Sel);
    if not ClearOK then begin Say('FAIL: reverb RAM clear readback.'); Exit; end;
  end;
  Say('REVERB RAM: 128 KiB at base+$20000; total reserved region 256 KiB.');
  Say('DMA: signed 16-bit stereo; ring geometry selected by sample rate.');
  Say('Source: Windows waveOut queue; conservative cursor completion.');
  Result := True;
end;

procedure DSPInstruction(PC, Op, Dest, Accum, X, Y: Word);
begin
  WriteReg($600+PC*2,0,(LongInt(X) shl 12) or Y);
  WriteReg($601+PC*2,0,(LongInt(Op) shl 24) or
                       (LongInt(Dest) shl 12) or Accum);
end;

function DSPMatches(PC,Op,Dest,Accum,X,Y: Word): Boolean;
begin
  Result := (ReadReg($600+PC*2,0)=((LongInt(X) shl 12) or Y)) and
    (ReadReg($601+PC*2,0)=((LongInt(Op) shl 24) or
                         (LongInt(Dest) shl 12) or Accum));
end;

{ Resident timer safe. Recomputed from the current front gain on every
  volume update. Divide first to avoid 32-bit overflow in Delphi 1. }
{$S-}
function ScalePairGain(Gain: LongInt; P: Word): LongInt;
begin
  if P>100 then P := 100;
  Result := (Gain div 100)*LongInt(P)+
            ((Gain mod 100)*LongInt(P)) div 100;
end;

{$S+}

{$I EQDSP.INC}
{$I REVDSP.INC}
{$I BASSDSP.INC}

procedure InitDSP;
var I: Word;
begin
  WriteReg($53,0,$00020000); { A_DBG: halt DSP }
  for I:=0 to 511 do WriteReg($400+I,0,0);
  { PCM FX buses 0/1 to front and rear stereo outputs. GPRs 8/9
    control front gain; GPRs10/11 control rear gain.
    Rear routing matches VSBHDA SBLIVE.C's Audigy outdev=1 path. }
  { GPR20..23 contain the preceding DSP frame's monitor contribution.
    Reading GPRs, not output registers, keeps the summation well defined.
    With monitor gains zero this is the original PCM path, bit for bit. }
  { Render the front sum ONCE into GPR24/25 for speaker outputs only.
    Wave captures raw PCM before this speaker-volume stage. }
  DSPInstruction(0,0,$424,$420,$408,0);
  DSPInstruction(1,0,$425,$421,$409,1);
  DSPInstruction(2,6,$60,$424,$C0,$C0);
  DSPInstruction(3,6,$61,$425,$C0,$C0);
  DSPInstruction(4,0,$6E,$422,$40A,0); { analog rear left }
  DSPInstruction(5,0,$6F,$423,$40B,1); { analog rear right }
  DSPInstruction(6,0,$66,$422,$40A,0); { digital rear left }
  DSPInstruction(7,0,$67,$423,$40B,1); { digital rear right }
  for I:=8 to 1023 do DSPInstruction(I,$F,$C0,$C0,$CF,$C0);
  { Slots8/9 belong exclusively to recording. Monitor gain is independent. }
  DSPInstruction(10,0,$420,$C0,$410,$4A);
  DSPInstruction(11,0,$421,$C0,$411,$4B);
  DSPInstruction(12,0,$422,$C0,$412,$4A);
  DSPInstruction(13,0,$423,$C0,$413,$4B);
  DSPInstruction(14,6,$68,$424,$C0,$C0);
  DSPInstruction(15,6,$69,$425,$C0,$C0);
  WriteReg($408,0,$40000000);
  WriteReg($409,0,$40000000);
  WriteReg($40A,0,$40000000);
  WriteReg($40B,0,$40000000);
  InitEqualizer;
  InitReverb;
  InitBass;
  { Wave 1 uses FX0/1, Wave 2 FX2/3, FM FX4/5. The recording tap is
    the raw sum, before any listening volumes, faders, EQ or reverb. }
  DSPInstruction(20,6,$428,0,2,4); { pre-volume Wave + FM sum, left }
  DSPInstruction(21,6,$429,1,3,5); { pre-volume Wave + FM sum, right }
  DSPInstruction(22,0,$424,$424,$414,2);
  DSPInstruction(23,0,$425,$425,$415,3);
  DSPInstruction(24,0,$426,$426,$416,2);
  DSPInstruction(25,0,$427,$427,$417,3);
  DSPInstruction(26,0,$424,$424,$56F,4);
  DSPInstruction(27,0,$425,$425,$570,5);
  DSPInstruction(28,0,$426,$426,$571,4);
  DSPInstruction(29,0,$427,$427,$572,5);
  WriteReg($414,0,$40000000); WriteReg($415,0,$40000000);
  WriteReg($416,0,$40000000); WriteReg($417,0,$40000000);
  { Unfaded reverb-send volumes $569..$56E, FM dry gains $56F..$572. }
  for I:=$569 to $572 do WriteReg(I,0,$40000000);
  WriteReg($53,0,0);
  { Do not mix AC97's analog front route into the Philips DAC output. }
  Port[IOBase+$1E] := $02;
  PortW[IOBase+$1C] := PortW[IOBase+$1C] or $8000;
  Say('DSP loaded: FX0/1, FX2/3 and FM FX4/5; independent speaker gains.');
end;

procedure InitHardware;
var V: Word;
    SilentMap: LongInt;
begin
  Touched := True;
  Out32(IOBase+$0C,0); { INTE: all card interrupts disabled }
  Out32(IOBase+$14,$0E); { mute, lock sound/tank cache }
  WriteReg($53,0,$00020000);
  for V:=0 to 255 do WriteReg($100+V,0,0); { disable stale TRAM operations }
  WriteReg(R_MICBS,0,0); WriteReg(R_MICBA,0,0);
  WriteReg(R_FXBS,0,0);  WriteReg(R_FXBA,0,0);
  WriteReg(R_ADCBS,0,0); WriteReg(R_ADCBA,0,0);
  WriteReg(R_CLIEL,0,0); WriteReg(R_CLIEH,0,0);
  WriteReg(R_HLIEL,0,0); WriteReg(R_HLIEH,0,0);
  WriteReg(R_SOLEL,0,0); WriteReg(R_SOLEH,0,0);
  WriteReg(R_SPBYPASS,0,R_SPBYPASS_FORMAT);
  SilentMap := ((RAMBase+$8000) shl 1) or $1FFF;
  for V:=0 to 63 do begin
    WriteReg(R_DCYSUSV,V,0); WriteReg(R_IP,V,0);
    WriteReg(R_VTFT,V,$FFFF); WriteReg(R_CVCF,V,$FFFF);
    WriteReg(R_PTRX,V,0); WriteReg(R_CPF,V,0); WriteReg(R_CCR,V,0);
    WriteReg(R_PSST,V,0); WriteReg(R_DSL,V,$10);
    WriteReg(R_CCCA,V,0); WriteReg(R_Z1,V,0); WriteReg(R_Z2,V,0);
    WriteReg(R_FXRT,V,$32100000);
    WriteReg(R_ATKHLDM,V,0); WriteReg(R_DCYSUSM,V,0);
    WriteReg(R_IFATN,V,$FFFF); WriteReg(R_PEFE,V,0);
    WriteReg(R_FMMOD,V,0); WriteReg(R_TREMFRQ,V,24);
    WriteReg(R_FM2FRQ2,V,24); WriteReg(R_TEMPENV,V,0);
    WriteReg(R_LFOVAL2,V,0); WriteReg(R_LFOVAL1,V,0);
    WriteReg(R_ATKHLDV,V,0); WriteReg(R_ENVVOL,V,0);
    WriteReg(R_ENVVAL,V,0);
    WriteReg($4C,V,0); WriteReg($4D,V,0);
    WriteReg($4E,V,0); WriteReg($4F,V,0);
    WriteReg(R_A_FXRT1,V,$03020100);
    WriteReg(R_A_FXRT2,V,$3F3F3F3F);
    WriteReg(R_A_SENDAMOUNTS,V,0);
    WriteReg(R_MAPA,V,SilentMap); WriteReg(R_MAPB,V,SilentMap);
  end;
  WriteReg(R_SPCS0,0,$02109204);
  WriteReg(R_SPCS1,0,$02109204);
  WriteReg(R_SPCS2,0,$02109204);
  WriteReg(R_PTB,0,RAMBase);
  WriteReg(R_TCB,0,0); WriteReg(R_TCBS,0,4);
  WriteReg($76,0,ReadReg($76,0) and not LongInt($E0));
  Out32(IOBase+$14,$210); { Audigy 1: automute and joystick }
  PortW[IOBase+$18] := PortW[IOBase+$18] or $0044;
  InitDSP;
  Out32(IOBase+$14,In32(IOBase+$14) or 1);
  PortW[IOBase+$18] := (PortW[IOBase+$18] and $FFBB) or $0080;
  Out32(IOBase+$08,In32(IOBase+$08)); { acknowledge stale IPR }
  Say('Hardware initialized; INTE remains zero.');
end;

{$S-} { timer startup: indexed port writes only }
procedure InitVoice(V: Word; Master: Boolean);
var SilentMap: LongInt;
begin
  with Playback^ do begin
    WriteReg(R_DCYSUSV,V,0);
    { A/B carry audio; C/D stay muted but MUST have different destinations.
      Reusing FX2/3 for C/D as well as A/B gives illegal duplicate routes. }
    case VoiceFirst of
      2: WriteReg(R_A_FXRT1,V,$05040302);
      4: WriteReg(R_A_FXRT1,V,$07060504);
    else WriteReg(R_A_FXRT1,V,$03020100);
    end;
    if Master then begin
      WriteReg(R_PTRX,V,$FF00); { send A -> this stream's left FX bus }
      WriteReg(R_CPF,V,$8000);  { stereo pair, even master }
      WriteReg(R_CCCA,V,(FrameBase+56) or InterpROM);   { 28 stereo cache samples * 2 }
    end else begin
      WriteReg(R_PTRX,V,$00FF); { send B -> this stream's right FX bus }
      WriteReg(R_CPF,V,0);
      WriteReg(R_CCCA,V,FrameBase or InterpROM);
    end;
    WriteReg(R_DSL,V,FrameBase+AudFrames); WriteReg(R_PSST,V,FrameBase);
    WriteReg(R_Z1,V,0); WriteReg(R_Z2,V,0);
    SilentMap := ((RAMBase+$8000) shl 1) or $1FFF;
    WriteReg(R_MAPA,V,SilentMap); WriteReg(R_MAPB,V,SilentMap);
    WriteReg(R_CVCF,V,$FFFF); WriteReg(R_VTFT,V,$FFFF);
    WriteReg(R_PEFE,V,0);
    { Keep volume/modulation envelopes inactive. Direct CVCF/VTFT and
      CPF/PTRX updates control PCM, following current ALSA emupcm.c.
      In particular, do not trigger the initial-pitch/envelope machinery. }
    WriteReg(R_DCYSUSV,V,0);
  end;
end;

procedure AudStart;
var I,V: Word;
    C: LongInt;
begin
  with Playback^ do begin
    if not Ready or not Assigned(PublicSupply) then Exit;
    if Playback=@Playbacks[AudOplPlayback] then
      if (OplDMASel=0) or not Assigned(OplSupply) then Exit;
    AudStop;
    PrimeStream;
    if FaultCode<>0 then Exit;
    InitVoice(VoiceFirst,True); InitVoice(VoiceFirst+1,False);
    for V:=VoiceFirst to VoiceFirst+1 do begin
      for I:=0 to 3 do WriteReg(R_CD0+I,V,0);
      C := ReadReg(R_CCR,V) and not LongInt($FE000000);
      WriteReg(R_CCR,V,C);
      { VSBHDA uses cra=64; this 6-bit field intentionally truncates to 0. }
      C := C and not LongInt($003F0000);
      WriteReg(R_CCR,V,C);
      WriteReg(R_CCR,V,C or (LongInt(28) shl 25));
    end;
    LastFetch := AudPosition;
    CursorOrigin := LastFetch;
    ServiceTick := timeGetTime;
    for V:=VoiceFirst to VoiceFirst+1 do begin
      WriteReg(R_IFATN,V,$FF00);
      WriteReg(R_DCYSUSV,V,0);
      { Explicitly unmute both linear volume registers. }
      WriteReg(R_VTFT,V,-1);
      WriteReg(R_CVCF,V,-1);
      C := ReadReg(R_PTRX,V) and $FFFF;
      WriteReg(R_PTRX,V,C or (PlayPitch shl 16)); { native sample-rate pitch }
      if V=VoiceFirst then begin
        C := ReadReg(R_CPF,V) and $FFFF;
        WriteReg(R_CPF,V,C or (PlayPitch shl 16));
      end;
      { IP remains zero: CPF/PTRX already specify unity playback pitch. }
    end;
    Streaming := True;
    { Startup runs in the resident timer without task-context logging. }
  end;
end;

{$S-} { interrupt path: no task-stack RTL check }
procedure AudStop;
var V: Word;
begin
  with Playback^ do begin
    Streaming := False; HardwarePaused := False;
    if not Touched then Exit;
    for V:=VoiceFirst to VoiceFirst+1 do begin
      WriteReg(R_IP,V,0);
      WriteReg(R_CPF,V,ReadReg(R_CPF,V) and $FFFF);
      WriteReg(R_DCYSUSV,V,0);
      WriteReg(R_PTRX,V,0);
      WriteReg(R_CVCF,V,$FFFF);
      WriteReg(R_VTFT,V,$FFFF);
    end;
  end;
end;

{$S+}
{$S-} { interrupt path: no task-stack RTL check }
function AudPosition: LongInt;
begin
  with Playback^ do begin
    Result := 0;
    if Ready then
      Result := (((ReadReg(R_CCCA,VoiceFirst) and $00FFFFFF)-FrameBase)*4)
                mod AudPCMBytes;
  end;
end;

function AudRefillCount: LongInt;
begin
  with Playback^ do begin
    Result := Refills;
  end;
end;

function AudIsStreaming: Boolean;
begin
  with Playback^ do begin
    Result := Streaming;
  end;
end;

{$S+}
{$S-} { interrupt path: no task-stack RTL check }
function AudPlayedThrough: LongInt;
begin
  with Playback^ do begin
    { A full ring is a deliberately conservative cache/drain allowance.
      Output offsets already include the startup silence guard. }
    Result := FetchTotal-AudDrainBytes;
    if Result<0 then Result := 0;
  end;
end;

{$S+}
{$S-} { interrupt path: no task-stack RTL check }
procedure RecordPosition(P: LongInt);
var D: LongInt;
begin
  with Playback^ do begin
    D := P-LastFetch;
    if D<0 then D := D+AudPCMBytes;
    if FetchTotal>$7F000000-D then begin
      AudStop;
      FaultCode := 1; FaultValue := FetchTotal;
      Exit;
    end;
    FetchTotal := FetchTotal+D;
    LastFetch := P;
  end;
end;

{$S+}
procedure AudStreamReport;
begin
  with Playback^ do begin
    Say('STREAM: refills='+IntToStr(Refills)+' misses='+IntToStr(Misses)+
        ' maxfill_ms='+IntToStr(MaxFillMS)+' maxservice_ms='+IntToStr(MaxServiceMS)+
        ' minslack_bytes='+IntToStr(MinSlack));
    Say('CURSOR: fetch_bytes='+IntToStr(FetchTotal)+
        ' played_through='+IntToStr(AudPlayedThrough));
    Say('DEADLINE: silent_bytes='+IntToStr(SilentBytes)+
        ' short_requests='+IntToStr(RetryFills));
    Say('DEADLINE: catchups='+IntToStr(Catchups)+
        ' pending_bytes='+IntToStr(ClearTotal-WriteTotal));
  end;
end;

{$S-} { interrupt path: no task-stack RTL check }
function StreamFailure(Code: Word; Value: LongInt): Boolean;
begin
  with Playback^ do begin
    Inc(Misses);
    AudStop;
    FaultCode := Code; FaultValue := Value;
    Result := False;
  end;
end;

{$S-}
function RefreshCursor: Boolean;
var Now, Gap, P, BytesPerMS: LongInt;
begin
  with Playback^ do begin
    Result := False;
    Now := timeGetTime;
    Gap := Now-ServiceTick;
    if Gap>MaxServiceMS then MaxServiceMS := Gap;
    BytesPerMS := (PlayRate*4+999) div 1000;
    { A whole unobserved revolution is ambiguous. Missing a slice is not.
      Bound elapsed time before interpreting the modulo cursor. }
    if (Gap<0) or
       (Gap>=LongInt(AudPCMBytes) div BytesPerMS-AudClockMargin) then begin
      Result := StreamFailure(2,Gap);
      Exit;
    end;
    P := AudPosition;
    RecordPosition(P);
    if not Streaming then Exit;
    ServiceTick := Now;
    Result := True;
  end;
end;

{$S-}
function RefillBudget: LongInt;
begin
  with Playback^ do begin
    { CCCA is ahead of audible playback. Keep the agreed 512-byte guard on
      EACH side of the reuse window; separately allow for observed copy time.
      The extra millisecond covers timestamp quantization. No disk delay. }
    Result := AudCacheGuardBytes+
              (MaxFillMS+AudClockMargin+1)*((PlayRate*4+999) div 1000);
  end;
end;

{$S-}
function FinishTransfer(StartOffset, StartTick: LongInt): Boolean;
var Elapsed, Slack: LongInt;
begin
  with Playback^ do begin
    Result := False;
    if not RefreshCursor then Exit;
    Elapsed := ServiceTick-StartTick;
    if Elapsed>MaxFillMS then MaxFillMS := Elapsed;
    Slack := StartOffset-(FetchTotal+CursorOrigin);
    if Slack<MinSlack then MinSlack := Slack;
    if Slack<=AudCacheGuardBytes then begin
      Result := StreamFailure(5,Slack);
      Exit;
    end;
    Result := True;
  end;
end;

{$S-}
function AudService: Boolean;
var Cursor, ClearLimit, WriteLimit, Budget, Fence: LongInt;
    StartOffset, StartTick, Gap: LongInt;
    N, Used, Passes: Word;
begin
  with Playback^ do begin
    Result := False;
    if not Ready or not Streaming then Exit;
    Gap := timeGetTime-ServiceTick;
    if not RefreshCursor then Exit;
    if Gap>=AudSliceMS then Inc(Catchups);
    Cursor := FetchTotal+CursorOrigin;

    { Recycle only storage whose PREVIOUS generation is safely behind CCCA.
      Preclear it early, but do not commit it as silence until its deadline.
      ClearLimit is a snapshot: this loop never chases the moving hardware. }
    ClearLimit := (Cursor+AudPCMBytes-AudCacheGuardBytes) and not LongInt(3);
    Passes := AudSlicesPerHalf*2+2;
    while (ClearTotal<ClearLimit) and (Passes<>0) do begin
      Dec(Passes);
      Budget := RefillBudget;
      if ClearTotal-(FetchTotal+CursorOrigin)<=Budget then begin
        Result := StreamFailure(3,ClearTotal-(FetchTotal+CursorOrigin));
        Exit;
      end;
      N := TransferSize(ClearTotal,ClearLimit);
      StartOffset := ClearTotal; StartTick := ServiceTick;
      ZeroPCM(PCMAddress(ClearTotal),N);
      Inc(ClearTotal,LongInt(N));
      if not FinishTransfer(StartOffset,StartTick) then Exit;
    end;
    if ClearTotal<ClearLimit then begin
      Result := StreamFailure(6,ClearLimit-ClearTotal); Exit;
    end;

    Budget := RefillBudget;
    Cursor := FetchTotal+CursorOrigin;
    WriteLimit := Cursor+AudHalfBytes;
    { At low rates the guard itself can approach a requested half. Retain
      room for one copy quantum when possible, NEVER beyond safe storage. }
    if WriteLimit<Cursor+Budget+AudSliceBytes then
      WriteLimit := Cursor+Budget+AudSliceBytes;
    if WriteLimit>ClearTotal then WriteLimit := ClearTotal;
    WriteLimit := WriteLimit and not LongInt(3);
    Passes := AudSlicesPerHalf*2+2;
    while Passes<>0 do begin
      Dec(Passes);
      Budget := RefillBudget;
      Cursor := FetchTotal+CursorOrigin;
      Fence := (Cursor+Budget+4) and not LongInt(3);
      if WriteTotal<Fence then begin
        if Fence>ClearTotal then begin
          Result := StreamFailure(3,ClearTotal-Cursor); Exit;
        end;
        { Only expired, already-zeroed bytes become silence. New source
          begins at the first still-safe frame, not at the next whole slice. }
        Inc(SilentBytes,Fence-WriteTotal);
        WriteTotal := Fence;
      end;
      if WriteTotal>=WriteLimit then Break;
      N := TransferSize(WriteTotal,WriteLimit);
      StartOffset := WriteTotal; StartTick := ServiceTick;
      Used := FillPlayback(PCMAddress(WriteTotal),N,WriteTotal);
      if (Used>N) or ((Used and 3)<>0) then begin
        Result := StreamFailure(7,Used); Exit;
      end;
      Inc(WriteTotal,LongInt(Used));
      if not FinishTransfer(StartOffset,StartTick) then Exit;
      if Used<>0 then Inc(Refills);
      if Used<N then begin Inc(RetryFills); Break; end;
    end;
    Result := True;
  end;
end;

{$S+}
function AudSetRate(Rate: LongInt): Boolean;
var P, HalfMS, SliceMS, MinimumMS: LongInt;
    TargetHalfFrames: LongInt;
begin
  with Playback^ do begin
    Result := False;
    if Streaming or HardwarePaused then Exit;
    if (Rate<8000) or (Rate>48000) then Exit;
    { Same integer pitch calculation as pinned VSBHDA SBLIVE.C. }
    P := (Rate shl 8) div 375;
    PlayPitch := (P shr 1)+(P and 1);
    PlayRate := Rate;
    HalfMS := AudBufferHalfMS;
    SliceMS := AudRefillSliceMS;
    { Bound timer latency plus the agreed 512-byte guard. Two extra
      milliseconds cover frame rounding and strict boundary comparisons. }
    MinimumMS := AudTimerInterval+AudClockMargin+2+
                 (LongInt(AudCacheGuardBytes)*1000+Rate*4-1) div (Rate*4);
    if MinimumMS>AudBufferMaxMS then Exit;
    if HalfMS>AudBufferMaxMS then HalfMS := AudBufferMaxMS;
    if HalfMS<MinimumMS then HalfMS := MinimumMS;
    if SliceMS>HalfMS then SliceMS := HalfMS;
    MinimumMS := AudTimerInterval+AudClockMargin+2;
    if SliceMS<MinimumMS then SliceMS := MinimumMS;
    TargetHalfFrames := (Rate*HalfMS+999) div 1000;
    AudSlicesPerHalf := Word(HalfMS div SliceMS);
    if AudSlicesPerHalf<1 then AudSlicesPerHalf := 1;
    if AudSlicesPerHalf>16 then AudSlicesPerHalf := 16;
    AudSliceFrames := Word((TargetHalfFrames+AudSlicesPerHalf-1) div
                           AudSlicesPerHalf);
    { Startup silence is independent of slice size and can span slices. }
    AudHalfFrames := AudSliceFrames*AudSlicesPerHalf;
    AudFrames := Word(LongInt(AudHalfFrames)*2);
    AudSliceBytes := Word(LongInt(AudSliceFrames)*4);
    AudHalfBytes := Word(LongInt(AudHalfFrames)*4);
    AudPCMBytes := Word(LongInt(AudHalfBytes)*2);
    AudLeadBytes := AudStartupBytes; AudDrainBytes := AudPCMBytes;
    AudSliceMS := Word(LongInt(AudSliceFrames)*1000 div Rate);
    AudHalfMS := Word(LongInt(AudHalfFrames)*1000 div Rate);
    if AudSliceMS<=AudClockMargin then Exit;
    { Each ring owns exactly six page-table pages (24 KiB). Never overlap
      the other stream, the ADC ring, or external reverb TRAM. }
    if (AudPCMBytes=0) or (AudPCMBytes>$6000) then Exit;
    if Rate=48000 then InterpROM := 0 else InterpROM := $02000000;
    Say('RATE: '+IntToStr(PlayRate)+' pitch=$'+IntToHex(PlayPitch,4)+
        ' interpolation=$'+IntToHex(InterpROM,8)+
        ' half_bytes='+IntToStr(AudHalfBytes)+' ring_bytes='+IntToStr(AudPCMBytes));
    Say('SERVICE: requested_half_ms='+IntToStr(AudBufferHalfMS)+
        ' requested_slice_ms='+IntToStr(AudRefillSliceMS));
    Say('SERVICE: half_ms='+IntToStr(AudHalfMS)+
        ' slice_ms='+IntToStr(AudSliceMS)+
        ' slice_bytes='+IntToStr(AudSliceBytes)+
        ' slices_per_half='+IntToStr(AudSlicesPerHalf));
    Say('SERVICE: timer_ms='+IntToStr(AudTimerInterval));
    Say('SERVICE: clock_margin_ms='+IntToStr(AudClockMargin));
    Say('SERVICE: deadline refill; guard_bytes=512');
    Result := True;
  end;
end;

const
  { 48 dB curve sampled at 1024-step input intervals. Integer linear
    interpolation differs from the former floating calculation by <0.1%. }
  VolumeGainTable: array[0..64] of LongInt = (
       4274643,    4660156,    5080436,    5538620,
       6038126,    6582680,    7176345,    7823550,
       8529124,    9298331,   10136910,   11051117,
      12047772,   13134311,   14318841,   15610199,
      17018020,   18552806,   20226008,   22050109,
      24038719,   26206673,   28570146,   31146771,
      33955772,   37018104,   40356616,   43996215,
      47964055,   52289738,   57005536,   62146634,
      67751385,   73861607,   80522885,   87784916,
      95701880,  104332843,  113742197,  124000143,
     135183211,  147374835,  160665971,  175155781,
     190952368,  208173584,  226947912,  247415420,
     269728810,  294054553,  320574136,  349485412,
     381004079,  415365286,  452825390,  493663868,
     538185402,  586722153,  639636235,  697322423,
     760211093,  828771437,  903514959,  984999294,
    1073741824);

{$S-} { cached PCM and monitor gains are both applied by the resident timer }
function VolumeGain(V: Word): LongInt;
var I,F: Word;
    Base,Delta: LongInt;
begin
  if V=0 then Result := 0
  else if V=$FFFF then Result := $40000000
  else begin
    I := V shr 10; F := V and $03FF;
    Base := VolumeGainTable[I];
    Delta := VolumeGainTable[I+1]-Base;
    { Split before multiplying to stay inside signed 32-bit arithmetic. }
    Result := Base+(Delta div 1024)*LongInt(F)+
              ((Delta mod 1024)*LongInt(F)) div 1024;
  end;
end;

procedure AudSetVolume(Device,Left,Right,Fader: Word);
var L,R: LongInt;
    G,Front,Rear,BassG,SendG: Word;
begin
  if not Ready or (Device>2) then Exit;
  L := VolumeGain(Left); R := VolumeGain(Right);
  case Device of
    0: begin G := $408; BassG := $560; end;
    1: begin G := $414; BassG := $562; end;
  else begin G := $56F; BassG := $573; end;
  end;
  Front := 100; Rear := 100;
  if Fader<50 then Front := Fader*2
  else if Fader>50 then Rear := (100-Fader)*2;
  WriteReg(G,0,ScalePairGain(L,Front));
  WriteReg(G+1,0,ScalePairGain(R,Front));
  WriteReg(G+2,0,ScalePairGain(L,Rear));
  WriteReg(G+3,0,ScalePairGain(R,Rear));
  WriteReg(BassG,0,L div 2);
  WriteReg(BassG+1,0,R div 2);
  SendG := $569+Device*2;
  WriteReg(SendG,0,L); WriteReg(SendG+1,0,R);
end;
{$S+}

function AudPause: Boolean;
var V: Word;
begin
  with Playback^ do begin
    Result := False;
    if not Ready then Exit;
    if HardwarePaused or not Streaming then begin Result := True; Exit; end;
    if not AudService then Exit;
    { Freeze pitch while preserving routing, cache state, and current
      addresses. Reset's AudStop deliberately discards more state. }
    for V:=VoiceFirst to VoiceFirst+1 do begin
      WriteReg(R_CVCF,V,$FFFF); WriteReg(R_VTFT,V,$FFFF);
      WriteReg(R_PTRX,V,ReadReg(R_PTRX,V) and $FFFF);
    end;
    WriteReg(R_CPF,VoiceFirst,ReadReg(R_CPF,VoiceFirst) and $FFFF);
    WriteReg(R_CPF,VoiceFirst+1,ReadReg(R_CPF,VoiceFirst+1) and $FFFF);
    RecordPosition(AudPosition);
    if not Streaming then Exit;
    Streaming := False; HardwarePaused := True;
    Say('PAUSE: fetch_bytes='+IntToStr(FetchTotal));
    Result := True;
  end;
end;

function AudResume: Boolean;
var V: Word;
    C: LongInt;
begin
  with Playback^ do begin
    Result := False;
    if not Ready or not HardwarePaused then Exit;
    ServiceTick := timeGetTime;
    Streaming := True;
    { Catch any progression while pitch was being frozen. This
      service runs with pitch still zero and cannot restart DMA by itself. }
    if not AudService then begin HardwarePaused := False; Exit; end;
    ServiceTick := timeGetTime;
    for V:=VoiceFirst to VoiceFirst+1 do begin
      WriteReg(R_VTFT,V,-1); WriteReg(R_CVCF,V,-1);
      C := ReadReg(R_PTRX,V) and $FFFF;
      WriteReg(R_PTRX,V,C or (PlayPitch shl 16));
    end;
    C := ReadReg(R_CPF,VoiceFirst) and $FFFF;
    WriteReg(R_CPF,VoiceFirst,C or (PlayPitch shl 16));
    HardwarePaused := False;
    Say('RESTART: fetch_bytes='+IntToStr(FetchTotal));
    Result := True;
  end;
end;

procedure DumpRegisters;
var V: Word;
begin
  with Playback^ do begin
    if not Touched then Exit;
    Say('HCFG=$'+IntToHex(In32(IOBase+$14),8)+
        ' IOCFG=$'+IntToHex(PortW[IOBase+$18],4)+
        ' INTE=$'+IntToHex(In32(IOBase+$0C),8)+
        ' IPR=$'+IntToHex(In32(IOBase+$08),8));
    Say('PTB=$'+IntToHex(ReadReg(R_PTB,0),8)+
        ' EHC=$'+IntToHex(ReadReg($76,0),8)+
        ' DBG=$'+IntToHex(ReadReg($53,0),8));
    Say('DSP0=$'+IntToHex(ReadReg($600,0),8)+
        '/$'+IntToHex(ReadReg($601,0),8)+
        ' gainL=$'+IntToHex(ReadReg($408,0),8)+
        ' gainR=$'+IntToHex(ReadReg($409,0),8));
    for V:=VoiceFirst to VoiceFirst+1 do
      Say('V'+IntToStr(V)+' CPF=$'+IntToHex(ReadReg(R_CPF,V),8)+
          ' PTRX=$'+IntToHex(ReadReg(R_PTRX,V),8)+
          ' CCCA=$'+IntToHex(ReadReg(R_CCCA,V),8)+
          ' CCR=$'+IntToHex(ReadReg(R_CCR,V),8));
    for V:=VoiceFirst to VoiceFirst+1 do
      Say('V'+IntToStr(V)+' CVCF=$'+IntToHex(ReadReg(R_CVCF,V),8)+
          ' VTFT=$'+IntToHex(ReadReg(R_VTFT,V),8)+
          ' MAPA=$'+IntToHex(ReadReg(R_MAPA,V),8)+
          ' MAPB=$'+IntToHex(ReadReg(R_MAPB,V),8));
    for V:=VoiceFirst to VoiceFirst+1 do
      Say('V'+IntToStr(V)+' DCYSUSV=$'+IntToHex(ReadReg(R_DCYSUSV,V),8)+
          ' IP=$'+IntToHex(ReadReg(R_IP,V),8));
  end;
end;

procedure ReportFault;
begin
  with Playback^ do begin
    if FaultCode=0 then Exit;
    case FaultCode of
      1: Say('STREAM STOP: output timeline limit.');
      2: Say('STREAM STOP: refill servicing gap; value is milliseconds.');
      3: Say('STREAM STOP: insufficient refill margin; value is bytes.');
      4: Say('STREAM STOP: playback reached the half during refill.');
      5: Say('STREAM STOP: refill ended inside the cache guard margin.');
    end;
    Say('FAULT value='+IntToStr(FaultValue));
  end;
end;

procedure AudDump;
begin
  DumpRegisters;
  AudStreamReport;
  ReportFault;
end;

{$I AUD1IN.INC}

procedure AudClose;
var V: Word;
    OK: Boolean;
begin
  MonitorEnabled := False; MonitorGain := 0;
  if Touched then begin
    WriteReg($410,0,0); WriteReg($411,0,0);
    WriteReg($412,0,0); WriteReg($413,0,0);
  end;
  AudCaptureClose;
  Ready := False;
  AudStopAll;
  if Touched then begin
    Out32(IOBase+$0C,0);
    for V:=0 to 63 do begin
      WriteReg(R_DCYSUSV,V,0); WriteReg(R_IP,V,0);
      WriteReg(R_PTRX,V,0); WriteReg(R_CPF,V,0);
      WriteReg(R_VTFT,V,0); WriteReg(R_CVCF,V,0);
    end;
    WriteReg($53,0,$00020000);
    Out32(IOBase+$14,$0E);
    { Disable PCI bus mastering before detaching the page table. }
    OK := writePCIRegisterWord($04,Bus,DevFn,OldCommand and $FFFB);
    WriteReg(R_PTB,0,0);
    WriteReg(R_TCB,0,0); WriteReg(R_TCBS,0,0);
    Say('CLOSE: voices stopped, caches locked, page table detached.');
  end;
  FreeRAM;
  if CommandChanged then begin
    OK := writePCIRegisterWord($04,Bus,DevFn,OldCommand);
    CommandChanged := False;
  end;
  Touched := False;
end;

function AudOpen(PhysicalBase: LongInt; CardIndex: Word;
                 LogProc: TAudLog; FillProc,OplFillProc: TAudFill): Boolean;
var BAR, Subsystem: LongInt;
    Cmd: Word;
begin
  Result := False;
  AudClose;
  Log := LogProc; PublicSupply := FillProc; OplSupply := OplFillProc;
  Say('AUD1 dual WaveOut backend; VSBHDA reference 99969b04.');
  if (PhysicalBase<$100000) or (PhysicalBase>$7FFFFFFF-AudMapBytes) or
     ((PhysicalBase and $FFF)<>0) then begin
    Say('FAIL: RAM base must be page aligned, >= 1 MiB, below 2 GiB.');
    Exit;
  end;
  RAMBase := PhysicalBase;
  if not detectPCIdevice($0004,$1102,Bus,DevFn,CardIndex) then begin
    Say('FAIL: PCI 1102:0004 card index not found.'); Exit;
  end;
  if not readPCIRegisterByte($08,Bus,DevFn,Revision) then begin
    Say('FAIL: could not read PCI revision.'); Exit;
  end;
  if (Revision=0) or (Revision>=4) then begin
    Say('FAIL: Audigy 1 PCI revision must be 1..3; found $'+
        IntToHex(Revision,2)); Exit;
  end;
  if not readPCIRegisterDWord($10,Bus,DevFn,BAR) then begin
    Say('FAIL: could not read PCI BAR0.'); Exit;
  end;
  if ((BAR and 1)=0) or ((BAR and $FFFF0000)<>0) or
     ((BAR and $FFF0)=0) then begin
    Say('FAIL: BAR0 is not a usable 16-bit I/O port base.'); Exit;
  end;
  IOBase := Word(BAR and $FFF0);
  Subsystem := 0;
  if not readPCIRegisterDWord($2C,Bus,DevFn,Subsystem) then begin
    Say('FAIL: could not read PCI subsystem ID.'); Exit;
  end;
  Say('PCI bus=$'+IntToHex(Bus,2));
  Say('PCI devfn=$'+IntToHex(DevFn,2));
  Say('PCI revision=$'+IntToHex(Revision,2));
  Say('PCI subsystem=$'+IntToHex(Subsystem,8));
  Say('PCI I/O=$'+IntToHex(IOBase,4));
  if not readPCIRegisterWord($04,Bus,DevFn,OldCommand) then begin
    Say('FAIL: could not read PCI command.'); Exit;
  end;
  if not PrepareRAM then begin AudClose; Exit; end;
  Cmd := OldCommand or 5; { PCI I/O decoding and bus mastering }
  if not writePCIRegisterWord($04,Bus,DevFn,Cmd) then begin
    Say('FAIL: could not enable PCI I/O/bus mastering.'); AudClose; Exit;
  end;
  CommandChanged := True;
  if not readPCIRegisterWord($04,Bus,DevFn,Cmd) or
     ((Cmd and 5)<>5) then begin
    Say('FAIL: PCI command readback.'); AudClose; Exit;
  end;
  if In32(IOBase+$14)=-1 then begin
    Say('FAIL: HCFG port read returned all ones.'); AudClose; Exit;
  end;
  InitHardware;
  if (ReadReg(R_TCB,0)<>RAMBase+$20000) or
     ((ReadReg(R_TCBS,0) and 7)<>3) then begin
    Say('FAIL: reverb delay-memory base/size readback.'); AudClose; Exit;
  end;
  if ReadReg(R_PTB,0)<>RAMBase then begin
    Say('FAIL: hardware page-table base readback mismatch.');
    AudDump; AudClose; Exit;
  end;
  if (ReadReg($600,0)<>$00408000) or
     (ReadReg($601,0)<>$00424420) or
     (ReadReg($608,0)<>$0040A000) or
     (ReadReg($609,0)<>$0006E422) or
     (ReadReg($60A,0)<>$0040B001) or
     (ReadReg($60B,0)<>$0006F423) or
     (ReadReg($408,0)<>$40000000) or
     (ReadReg($409,0)<>$40000000) or
     (ReadReg($40A,0)<>$40000000) or
     (ReadReg($40B,0)<>$40000000) then begin
    Say('FAIL: DSP instruction/gain readback mismatch.');
    AudDump; AudClose; Exit;
  end;
  if not DSPMatches(20,6,$428,0,2,4) or
     not DSPMatches(21,6,$429,1,3,5) or
     not DSPMatches(22,0,$424,$424,$414,2) or
     not DSPMatches(23,0,$425,$425,$415,3) or
     not DSPMatches(24,0,$426,$426,$416,2) or
     not DSPMatches(25,0,$427,$427,$417,3) or
     (ReadReg($414,0)<>$40000000) or (ReadReg($415,0)<>$40000000) or
     (ReadReg($416,0)<>$40000000) or (ReadReg($417,0)<>$40000000) or
     not DSPMatches(26,0,$424,$424,$56F,4) or
     not DSPMatches(27,0,$425,$425,$570,5) or
     not DSPMatches(28,0,$426,$426,$571,4) or
     not DSPMatches(29,0,$427,$427,$572,5) then begin
    Say('FAIL: independent playback DSP/gain readback mismatch.');
    AudDump; AudClose; Exit;
  end;
  if ((In32(IOBase+$14) and 1)=0) or (In32(IOBase+$0C)<>0) then begin
    Say('FAIL: audio enable / interrupt disable readback.');
    AudDump; AudClose; Exit;
  end;
  Ready := True;
  AudDump;
  Result := True;
end;

function AudIsOpen: Boolean;
begin
  Result := Ready;
end;

procedure AudSetSynthRate(Rate: Word);
begin
  with Playbacks[AudOplPlayback] do begin
    PlayRate := Rate;
    if Rate=48000 then begin
      PlayPitch := $4000; InterpROM := 0;
    end else begin
      PlayPitch := $3ACD; InterpROM := $02000000;
    end;
    { 30 ms half, 10 ms slice, stereo 16-bit. Both rings fit in $3000 bytes. }
    AudSliceFrames := Rate div 100; AudSliceBytes := AudSliceFrames*4;
    AudHalfFrames := AudSliceFrames*3; AudFrames := AudHalfFrames*2;
    AudHalfBytes := AudHalfFrames*4; AudPCMBytes := AudHalfBytes*2;
    AudDrainBytes := AudPCMBytes;
  end;
end;

procedure InitPlaybackStates;
var I: Word;
begin
  FillChar(Playbacks,SizeOf(Playbacks),0);
  for I:=0 to 1 do with Playbacks[I] do begin
    VoiceFirst := I*2; RingOffset := I*$6000;
    FrameBase := LongInt(RingOffset) div 4;
    PlayRate := 48000; PlayPitch := $4000; InterpROM := 0;
    AudHalfFrames := 1920; AudFrames := 3840;
    AudSliceFrames := 480; AudSliceBytes := 1920;
    AudHalfBytes := 7680; AudPCMBytes := 15360;
    AudLeadBytes := AudStartupBytes; AudDrainBytes := 15360;
    AudHalfMS := 40; AudSliceMS := 10; AudSlicesPerHalf := 4;
  end;
  with Playbacks[AudOplPlayback] do begin
    VoiceFirst := 4; FrameBase := LongInt($C000) div 4;
    AudLeadBytes := AudStartupBytes;
    AudHalfMS := 30; AudSliceMS := 10; AudSlicesPerHalf := 3;
  end;
  AudSetSynthRate(44100);
  Playback := @Playbacks[0];
end;

begin
  InitPlaybackStates;
  Log := nil; PublicSupply := nil; OplSupply := nil;
  AudOplEnabled := False; OplDMASel := 0;
  Ready := False; Touched := False; Mapped := False;
  AudBufferHalfMS := AudBufferDefaultMS;
  AudRefillSliceMS := AudSliceDefaultMS;
  AudInputSourceLevel := 50;
  CommandChanged := False;
  TableSel := 0; SilentSel := 0; PCMSel := 0; CapSel := 0;
  CapRate := 48000; CapChannels := 2; CapControl := $30;
  CapPrepared := False; CapCodecSaved := False;
  CapRouteSource := $FFFF; CodecRouteSource := $FFFF;
  MonitorEnabled := False; MonitorGain := 0;
end.
