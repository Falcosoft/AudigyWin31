{ Shared task-only INI/dialog parser; no floating point or resident work. }
function AudGainParse(const Value: string; var Steps: Word): Boolean;
var B: array[0..31] of Char;
    I,First: Word;
    Whole,Quarter: Word;
begin
  Result := False; Steps := 0;
  if Length(Value)>31 then Exit;
  StrPCopy(B,Value);
  I := 0;
  while (B[I]=' ') or (B[I]=#9) do Inc(I);
  if B[I]='+' then Inc(I);
  First := I; Whole := 0; Quarter := 0;
  while (B[I]>='0') and (B[I]<='9') do begin
    if Whole>12 then Exit;
    Whole := Whole*10+Ord(B[I])-Ord('0'); Inc(I);
  end;
  if I=First then Exit;
  if B[I]='.' then begin
    Inc(I);
    case B[I] of
      '0': begin Inc(I); if B[I]='0' then Inc(I); end;
      '2': begin
        Inc(I); if B[I]<>'5' then Exit; Inc(I); Quarter := 1;
      end;
      '5': begin
        Inc(I); Quarter := 2; if B[I]='0' then Inc(I);
      end;
      '7': begin
        Inc(I); if B[I]<>'5' then Exit; Inc(I); Quarter := 3;
      end;
    else Exit;
    end;
  end;
  while (B[I]=' ') or (B[I]=#9) do Inc(I);
  if (B[I]<>#0) or (Whole>12) then Exit;
  Whole := Whole*4+Quarter;
  if Whole>48 then Exit;
  Steps := Whole; Result := True;
end;

function AudGainText(Steps: Word): string;
begin
  if Steps>48 then Steps := 0;
  Result := IntToStr(Steps div 4);
  case Steps mod 4 of
    1: Result := Result+'.25';
    2: Result := Result+'.5';
    3: Result := Result+'.75';
  end;
end;
