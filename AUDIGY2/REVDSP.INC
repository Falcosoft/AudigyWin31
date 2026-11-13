{$I RVTABLE.INC}

{ Hardware adapter for kX Reverb Lite. Delay units/opcodes follow driver/dsp.cpp
  at the pinned source revision. All CPU helpers below are bounded/resident. }
{$S-}
procedure AudRevApply(OnOff,Preset,Level: Word);
const MaxWetGain=$33333333; { 0.4 Q31: new100 equals Test2 level40 }
var Gain,Decay,Diffusion,Balance: LongInt;
begin
  if not Ready then Exit;
  if (OnOff>1) or (Preset>3) or (Level>100) then Exit;
  Decay := $1E147AE1; Diffusion := $33266666; Balance := $28000000;
  case Preset of
    0: begin Decay := $1E147AE1; Diffusion := $33266666; Balance := $28000000; end;
    1: begin Decay := $41EB851E; Diffusion := $39800000; Balance := $5F333333; end;
    2: begin Decay := $33333333; Diffusion := $45B33333; Balance := $69999999; end;
    3: begin Decay := $28A3D70A; Diffusion := $3C6CCCCC; Balance := $48CCCCCC; end;
  end;
  Gain := 0;
  if OnOff<>0 then
    Gain := (MaxWetGain div 100)*LongInt(Level)+
            ((MaxWetGain mod 100)*LongInt(Level)) div 100;
  { Short parameter transaction; no large memory clears in the timer. }
  WriteReg($53,0,$00020000);
  WriteReg($522,0,Gain); { same wet level for all four returns }
  if OnOff<>0 then WriteReg($52A,0,$7FFFFFFF)
  else WriteReg($52A,0,0); { stop new sends, mute tail, do not disturb dry path }
  WriteReg($544,0,Decay); WriteReg($545,0,Balance);
  WriteReg($546,0,Diffusion);
  WriteReg($53,0,0);
end;

procedure InitReverb;
var I,PC,Ch,C,S,X: Word;
begin
  WriteReg($522,0,0); WriteReg($52A,0,0);
  for I:=0 to 28 do WriteReg($540+I,0,RevGPR[I]);
  { Tank DMA remains locked while changing the base, size and tap descriptors. }
  Out32(IOBase+$14,In32(IOBase+$14) or 4);
  WriteReg(R_TCB,0,RAMBase+$20000);
  WriteReg(R_TCBS,0,3); { 128 KiB, 65536 compressed samples }
  for I:=0 to 49 do begin
    WriteReg($300+RevTaps[I].Index,0,RevTaps[I].Offset shl 11);
    { kX read+clear initialization: address supplied through the data register. }
    WriteReg($200+RevTaps[I].Index,0,RevTaps[I].Offset);
    WriteReg($100+RevTaps[I].Index,0,RevTaps[I].Flags);
  end;
  WriteReg($53,0,$40020000); { zero delay-base counter while DSP is halted }
  WriteReg($53,0,$00020000);
  PC := 640;
  { Shadow the post-EQ front/rear outputs without reading output registers. }
  DSPInstruction(PC,$E,$523,$424,$436,$430); Inc(PC);
  DSPInstruction(PC,$E,$524,$425,$436,$431); Inc(PC);
  DSPInstruction(PC,$E,$525,$426,$436,$432); Inc(PC);
  DSPInstruction(PC,$E,$526,$427,$436,$433); Inc(PC);
  { Shared stereo send: all three sources at their unfaded volumes,
    plus input monitor. It does not depend on any speaker fader. }
  DSPInstruction(PC,0,$527,$420,$569,0); Inc(PC);
  DSPInstruction(PC,0,$528,$421,$56A,1); Inc(PC);
  DSPInstruction(PC,0,$527,$527,$56B,2); Inc(PC);
  DSPInstruction(PC,0,$528,$528,$56C,3); Inc(PC);
  DSPInstruction(PC,0,$527,$527,$56D,4); Inc(PC);
  DSPInstruction(PC,0,$528,$528,$56E,5); Inc(PC);
  { Use the same EQ coefficients as the listening mix, with separate state. }
  DSPInstruction(PC,0,$531,$C0,$435,$527); Inc(PC);
  DSPInstruction(PC,0,$532,$C0,$435,$528); Inc(PC);
  for I:=0 to 9 do for Ch:=0 to 1 do begin
    C := $440+I*5; S := $580+I*8+Ch*4; X := $531+Ch;
    EqEmitBand(PC,C,S,X,$533);
  end;
  DSPInstruction(PC,$E,$527,$527,$436,$531); Inc(PC);
  DSPInstruction(PC,$E,$528,$528,$436,$532); Inc(PC);
  DSPInstruction(PC,0,$520,$C0,$52A,$527); Inc(PC);
  DSPInstruction(PC,0,$521,$C0,$52A,$528); Inc(PC);
  for I:=0 to 76 do with RevCode[I] do begin
    DSPInstruction(PC,Op,R,A,X,Y); Inc(PC);
  end;
  { Level before integer boost: 100 gives 1.6x wet, 50 gives 0.8x wet.
    MACINTS saturates only the final dry+wet sum, not a boosted intermediate.
    $C4 is the Audigy integer constant4. Dry and feedback remain unchanged. }
  DSPInstruction(PC,0,$52B,$C0,$522,$540); Inc(PC);
  DSPInstruction(PC,0,$52C,$C0,$522,$541); Inc(PC);
  DSPInstruction(PC,0,$52D,$C0,$522,$542); Inc(PC);
  DSPInstruction(PC,0,$52E,$C0,$522,$543); Inc(PC);
  DSPInstruction(PC,4,$60,$523,$52B,$C4); Inc(PC);
  DSPInstruction(PC,4,$61,$524,$52C,$C4); Inc(PC);
  DSPInstruction(PC,4,$68,$523,$52B,$C4); Inc(PC);
  DSPInstruction(PC,4,$69,$524,$52C,$C4); Inc(PC);
  DSPInstruction(PC,4,$6E,$525,$52D,$C4); Inc(PC);
  DSPInstruction(PC,4,$6F,$526,$52E,$C4); Inc(PC);
  DSPInstruction(PC,4,$66,$525,$52D,$C4); Inc(PC);
  DSPInstruction(PC,4,$67,$526,$52E,$C4);
  Out32(IOBase+$14,In32(IOBase+$14) and not LongInt(4));
end;
{$S+}
