unit AudRev;
{$F+}
interface
type
  TRevSettings=record Enabled,Preset,Level: Word; end;
function RevValid(const R: TRevSettings): Boolean;
function RevSame(const A,B: TRevSettings): Boolean;
implementation
function RevValid(const R: TRevSettings): Boolean;
begin
  Result := (R.Enabled<=1) and (R.Preset<=3) and (R.Level<=100);
end;
function RevSame(const A,B: TRevSettings): Boolean;
begin
  Result := (A.Enabled=B.Enabled) and (A.Preset=B.Preset) and (A.Level=B.Level);
end;
end.
