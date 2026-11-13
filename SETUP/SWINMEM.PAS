unit SWinMem;

{ Native Win3.1 ToolHelp query. No Win32 API or audio-driver operations. }
{$F+}
{$B-}
interface

function WindowsMemoryMB(var MB: LongInt): Boolean;

implementation
uses WinTypes, WinProcs, ToolHelp;

function WindowsMemoryMB(var MB: LongInt): Boolean;
var Info: TMemManInfo;
    Bytes: LongInt;
begin
  Result := False; MB := 0;
  { In standard mode only dwLargestFreeBlock is documented as valid. }
  if (GetWinFlags and WF_ENHANCED)=0 then Exit;
  FillChar(Info,SizeOf(Info),0); Info.dwSize := SizeOf(Info);
  if not MemManInfo(@Info) then Exit;
  { Native x86 Win3.1 uses 4 KiB pages. Reject unset/unsupported fields. }
  if (Info.wPageSize<>4096) or (Info.dwTotalPages<=0) then Exit;
  if Info.dwTotalPages>$7FE00000 div 4096 then Exit;
  Bytes := Info.dwTotalPages*LongInt(Info.wPageSize);
  MB := Bytes div $100000;
  if (Bytes and $FFFFF)<>0 then Inc(MB);
  { Round upward; caller adds its existing 1 MiB address margin. }
  Result := (MB>=1) and (MB<=2046);
end;

end.
