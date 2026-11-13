unit AudPCM;

{ Delphi 1: integer-only PCM expansion, no allocation, I/O or resampling.
  Source is normal WAV PCM: unsigned 8-bit or signed little-endian 16-bit.
  Hardware destination always contains signed 16-bit interleaved stereo. }
{$C FIXED PRELOAD PERMANENT}
{$F+}
{$R-}
{$Q-}
interface

function PCMFormatValid(Rate: LongInt; Bits,Channels: Word): Boolean;
function PCMFrameBytes(Bits,Channels: Word): Word;
procedure PCMExpand(Source,Destination: Pointer;
                    Frames,Bits,Channels: Word);

implementation

type
  TPCMBytes=array[0..23999] of Byte;
  PPCMBytes=^TPCMBytes;
  TPCMWords=array[0..11999] of Integer;
  PPCMWords=^TPCMWords;

function PCMFormatValid(Rate: LongInt; Bits,Channels: Word): Boolean;
begin
  Result := (Rate>=8000) and (Rate<=48000) and
            ((Bits=8) or (Bits=16)) and
            ((Channels=1) or (Channels=2));
end;

function PCMFrameBytes(Bits,Channels: Word): Word;
begin
  Result := 0;
  if ((Bits=8) or (Bits=16)) and ((Channels=1) or (Channels=2)) then
    Result := (Bits div 8)*Channels;
end;

{$S-} { called directly by the resident timer path }
procedure PCMExpand(Source,Destination: Pointer;
                    Frames,Bits,Channels: Word);
var I,S,D: Word;
    L,R: LongInt;
begin
  { Caller bounds Frames to one hardware half, at most 6000 frames.
    Both pointer windows have already been validated by the driver. }
  if Frames=0 then Exit;
  if (Bits=16) and (Channels=2) then begin
    for I:=0 to Frames*2-1 do
      PPCMWords(Destination)^[I] := PPCMWords(Source)^[I];
    Exit;
  end;
  S := 0; D := 0;
  for I:=0 to Frames-1 do begin
    if Bits=8 then begin
      L := (LongInt(PPCMBytes(Source)^[S])-128)*256; Inc(S);
      if Channels=2 then begin
        R := (LongInt(PPCMBytes(Source)^[S])-128)*256; Inc(S);
      end else R := L;
    end else begin
      L := PPCMWords(Source)^[S]; Inc(S);
      R := L; { The remaining 16-bit case is mono. }
    end;
    PPCMWords(Destination)^[D] := Integer(L); Inc(D);
    PPCMWords(Destination)^[D] := Integer(R); Inc(D);
  end;
end;
{$S+}
end.
