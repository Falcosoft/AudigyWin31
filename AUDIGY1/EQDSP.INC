{ Four listening channels: front L/R and rear L/R. Original dry outputs
  remain intact when EQ is bypassed. Recording slots8/9 are untouched.
  GPR430..436,438..439,440..471,480..51F; DSP16..19 and32..443. }
{$S-}
procedure AudEqApply(OnOff: Word; const P: TEqProgram);
var I: Word;
begin
  if not Ready then Exit;
  { Brief bounded DSP halt, as used at initialization. Do not expose a
    partially updated recursive filter. No wait, allocation or callback. }
  WriteReg($53,0,$00020000);
  WriteReg($436,0,0);
  for I:=0 to 49 do WriteReg($440+I,0,P[I]);
  WriteReg($435,0,P[50]);
  for I:=$480 to $51F do WriteReg(I,0,0);
  for I:=$580 to $5CF do WriteReg(I,0,0); { stereo reverb-send EQ history }
  for I:=$430 to $434 do WriteReg(I,0,0);
  if OnOff<>0 then WriteReg($436,0,$7FFFFFFF);
  WriteReg($53,0,0);
end;

procedure EqEmitBand(var PC: Word; C,S,X,T: Word);
begin
  { DF-I half coefficients. Wrap partial sums; saturate the final double. }
  DSPInstruction(PC,2,T,$C0,C,X); Inc(PC);
  DSPInstruction(PC,2,T,T,C+1,S); Inc(PC);
  DSPInstruction(PC,2,T,T,C+2,S+1); Inc(PC);
  DSPInstruction(PC,2,T,T,C+3,S+2); Inc(PC);
  DSPInstruction(PC,2,T,T,C+4,S+3); Inc(PC);
  DSPInstruction(PC,6,S+3,S+2,$C0,$C0); Inc(PC);
  DSPInstruction(PC,6,S+2,T,T,$C0); Inc(PC);
  DSPInstruction(PC,6,S+1,S,$C0,$C0); Inc(PC);
  DSPInstruction(PC,6,S,X,$C0,$C0); Inc(PC);
  DSPInstruction(PC,6,X,S+2,$C0,$C0); Inc(PC);
end;

procedure InitEqualizer;
var I,Ch,PC,C,S,X: Word;
begin
  WriteReg($435,0,$7FFFFFFF); WriteReg($436,0,0);
  for I:=0 to 9 do WriteReg($440+I*5,0,$40000000);
  { Retain rear arithmetic exactly, including independent rounding. }
  { Monitor slots10..13 have already advanced this frame. Cached438/439
    retain the preceding frame, exactly as the original rear slots4..7. }
  DSPInstruction(16,0,$426,$438,$40A,0);
  DSPInstruction(17,0,$427,$439,$40B,1);
  DSPInstruction(18,6,$438,$422,$C0,$C0);
  DSPInstruction(19,6,$439,$423,$C0,$C0);
  PC := 32;
  for Ch:=0 to 3 do begin
    if Ch<2 then X := $424+Ch else X := $426+Ch-2;
    DSPInstruction(PC,0,$430+Ch,$C0,$435,X); Inc(PC);
  end;
  for I:=0 to 9 do for Ch:=0 to 3 do begin
    C := $440+I*5; S := $480+I*16+Ch*4; X := $430+Ch;
    EqEmitBand(PC,C,S,X,$434);
  end;
  { INTERP control=0 yields the EXACT old dry sample. No output-register
    reads. Enabled front/rear filters see their respective dry mixes. }
  DSPInstruction(PC,$E,$60,$424,$436,$430); Inc(PC);
  DSPInstruction(PC,$E,$61,$425,$436,$431); Inc(PC);
  DSPInstruction(PC,$E,$68,$424,$436,$430); Inc(PC);
  DSPInstruction(PC,$E,$69,$425,$436,$431); Inc(PC);
  DSPInstruction(PC,$E,$6E,$426,$436,$432); Inc(PC);
  DSPInstruction(PC,$E,$6F,$427,$436,$433); Inc(PC);
  DSPInstruction(PC,$E,$66,$426,$436,$432); Inc(PC);
  DSPInstruction(PC,$E,$67,$427,$436,$433); Inc(PC);
end;
{$S+}
