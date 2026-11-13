{ Classic Audigy 2/ZS CA0151 setup: hardware-confirmed LMP Audigy2 R1,
  source/AUDIGY2.S; ALSA v6.12 emu10k1_main.c; kX p16v.cpp.
  The companion routes EMU DSP output only. Its DMA is NEVER started. }
{$S-}
function ReadReg2(RegNo,Channel: Word): LongInt;
var Flags: Word;
begin
  asm
    pushf
    pop ax
    mov Flags,ax
    cli
  end;
  Out32(IOBase+$20,(LongInt(RegNo) shl 16) or Channel);
  Result := In32(IOBase+$24);
  asm
    mov ax,Flags
    push ax
    popf
  end;
end;

procedure WriteReg2(RegNo,Channel: Word; Value: LongInt);
var Flags: Word;
begin
  asm
    pushf
    pop ax
    mov Flags,ax
    cli
  end;
  Out32(IOBase+$20,(LongInt(RegNo) shl 16) or Channel);
  Out32(IOBase+$24,Value);
  asm
    mov ax,Flags
    push ax
    popf
  end;
end;

procedure CompanionStop;
begin
  Out32(IOBase+$2C,0); Out32(IOBase+$3C,0); { INTE2/INTE3 }
  WriteReg2($40,0,0); { all playback AND capture P16V streams stopped }
  Out32(IOBase+$34,0); { disable companion interface }
end;

function CompanionGainWord: LongInt;
begin
  { LMP gain R6: each SRCMulti byte is 48 minus gain in quarter dB. }
  if Aud2GainSteps>48 then Result := $30303030
  else Result := LongInt(48-Aud2GainSteps)*$01010101;
end;

procedure CompanionConfigure;
var I: Word;
    Gain: LongInt;
begin
  { I2S/SRCMulti interface clock only; EMU voices/DSP still run at48 kHz. }
  WriteReg($76,0,(ReadReg($76,0) and not LongInt($E00)) or $400);
  WriteReg2($60,0,$14);
  WriteReg2($6E,0,LongInt($FF00FF00)); { DSP only; no P16V sample inputs }
  Gain := CompanionGainWord;
  for I:=$63 to $66 do WriteReg2(I,0,Gain); { default unity/0dB }
  WriteReg2($6F,0,$000100FF);
  Out32(IOBase+$34,$00000201);
  WriteReg2($16,0,$000078E4);
end;

function CompanionReady: Boolean;
begin
  Result := (ReadReg2($40,0)=0) and
    (ReadReg2($60,0)=$14) and
    (ReadReg2($6E,0)=LongInt($FF00FF00)) and
    (ReadReg2($6F,0)=$000100FF) and
    ((ReadReg($76,0) and $E00)=$400) and
    ((In32(IOBase+$34) and $201)=$201) and
    (In32(IOBase+$2C)=0) and (In32(IOBase+$3C)=0);
end;
{$S+}
