unit AudEQ;

{ Task-only coefficient builder. DSP equations use Q2.30 coefficients.
  Independent implementation of RBJ peaking-EQ equations; see EQREF.TXT. }
{$F+}
{$R-}
{$Q-}
interface
uses WinTypes;
const EqBands=10;
type
  TEqSettings=record
    Enabled: Word;
    Preamp: Integer;
    Band: array[0..EqBands-1] of Integer;
  end;
  TEqProgram=array[0..50] of LongInt;
function EqValid(const E: TEqSettings): Boolean;
function EqSame(const A,B: TEqSettings): Boolean;
procedure EqBuild(const E: TEqSettings; var P: TEqProgram);
function EqCaption(I: Word): PChar;
implementation
function EqCaption(I: Word): PChar;
begin
  case I of
    0: Result := '31'; 1: Result := '63'; 2: Result := '125';
    3: Result := '250'; 4: Result := '500'; 5: Result := '1k';
    6: Result := '2k'; 7: Result := '4k'; 8: Result := '8k';
  else Result := '16k';
  end;
end;
function EqValid(const E: TEqSettings): Boolean;
var I: Word;
begin
  Result := False;
  if (E.Enabled>1) or (E.Preamp< -24) or (E.Preamp>0) then Exit;
  for I:=0 to EqBands-1 do
    if (E.Band[I]< -12) or (E.Band[I]>12) then Exit;
  Result := True;
end;
function EqSame(const A,B: TEqSettings): Boolean;
var I: Word;
begin
  Result := False;
  if (A.Enabled<>B.Enabled) or (A.Preamp<>B.Preamp) then Exit;
  for I:=0 to EqBands-1 do if A.Band[I]<>B.Band[I] then Exit;
  Result := True;
end;
procedure EqBuild(const E: TEqSettings; var P: TEqProgram);
var I,J: Word;
    F,W,A,Alpha,Den,C: Extended;
begin
  F := 31.25;
  for I:=0 to EqBands-1 do begin
    J := I*5;
    if E.Band[I]=0 then begin
      { Exact wire: no recursive roundoff for a flat band. }
      P[J] := $40000000;
      P[J+1] := 0; P[J+2] := 0; P[J+3] := 0; P[J+4] := 0;
    end else begin
      W := 2*Pi*F/48000;
      A := Exp(Ln(10)*E.Band[I]/40);
      Alpha := Sin(W)/(2*1.414213562373095);
      Den := 1+Alpha/A; C := Cos(W);
      P[J] := Round((1+Alpha*A)/Den*1073741824.0);
      P[J+1] := Round(-2*C/Den*1073741824.0);
      P[J+2] := Round((1-Alpha*A)/Den*1073741824.0);
      P[J+3] := Round(2*C/Den*1073741824.0);
      P[J+4] := Round(-(1-Alpha/A)/Den*1073741824.0);
    end;
    F := F*2;
  end;
  C := Exp(Ln(10)*E.Preamp/20);
  if C>=1 then P[50] := $7FFFFFFF
  else P[50] := Round(C*2147483647.0);
end;
end.
