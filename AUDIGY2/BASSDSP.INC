{ Audigy 2/ZS analog LFE only. No DAC, DMA or speaker-mode changes.
  DSP slots 600..608; FM input gains $573/$574.
  The fixed-point coefficient table is indexed in 5 Hz steps at 48 kHz.
  Two identical one-poles give -3 dB combined at the selected frequency. }
const
  BassCoeff: array[0..AudBassSteps] of LongInt = (
    $018D71D4, $01AE5892, $01CF36B5,
    $01F00C40, $0210D935, $02319D94,
    $0252595F, $02730C97, $0293B73F,
    $02B45957, $02D4F2E1, $02F583DF,
    $03160C52, $03368C3B, $0357039C,
    $03777276, $0397D8CB, $03B8369D,
    $03D88BEC, $03F8D8BB, $04191D0B);

{$S-}
procedure AudBassApply(OnOff,Hz: Word);
var G: LongInt;
begin
  if not Ready then Exit;
  if (Hz<AudBassMinHz) or (Hz>AudBassMaxHz) then Hz := AudBassDefaultHz;
  WriteReg($567,0,BassCoeff[(Hz-AudBassMinHz) div AudBassStepHz]);
  if OnOff=0 then G := 0 else G := $7FFFFFFF;
  WriteReg($568,0,G);
end;
{$S+}

procedure InitBass;
begin
  { Start muted. Volume writes supply half the nominal gain per channel,
    so each stereo pair is averaged before the three streams are summed. }
  DSPInstruction(600,0,$564,$C0,$560,0);
  DSPInstruction(601,0,$564,$564,$561,1);
  DSPInstruction(602,0,$564,$564,$562,2);
  DSPInstruction(603,0,$564,$564,$563,3);
  DSPInstruction(604,0,$564,$564,$573,4);
  DSPInstruction(605,0,$564,$564,$574,5);
  DSPInstruction(606,$E,$565,$565,$567,$564);
  DSPInstruction(607,$E,$566,$566,$567,$565);
  DSPInstruction(608,0,$6B,$C0,$568,$566); { analog LFE; no center }
end;
