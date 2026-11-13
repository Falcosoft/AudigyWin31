unit PCI;

{ Read-only Setup subset of the Audigy project PCI BIOS unit. See PCILIC.TXT. }

{$G+}
{$F+}
{$W+}
{$R-}
{$Q-}

interface

const PCINotFound=$86;

function FindPCIStatus(DeviceID,VendorID: Word;
  var BusNumber,FunctionNumber: Byte; SearchStart: Word): Word;
function readPCIRegisterByte(RegisterNumber: Word;
  BusNumber,FunctionNumber: Byte; var ResultY: Byte): Boolean;
function readPCIRegisterDWord(RegisterNumber: Word;
  BusNumber,FunctionNumber: Byte; var ResultY: LongInt): Boolean;

implementation

type
  { Fixed offsets are used by InvokeBIOS. Keep this record packed. }
  TPCIRequest = packed record
    A,B: Word;                  { +0 AX, +2 BX }
    C,D: LongInt;               { +4 ECX, +8 EDX }
    Index,RegisterNo: Word;     { +12 SI, +14 DI }
    Status: Word;              { +16 returned FLAGS }
  end;

procedure InitRequest(var R: TPCIRequest; Operation: Word);
begin
  R.A := Operation; R.B := 0;
  R.C := 0; R.D := 0;
  R.Index := 0; R.RegisterNo := 0; R.Status := 1;
end;

procedure InvokeBIOS(var R: TPCIRequest); assembler;
asm
  { Save caller FLAGS, all 32-bit general registers, DS and ES. The 66h
    prefixes let Delphi 1's 16-bit assembler encode 386 operations. }
  pushf
  db 66h; pusha
  push ds
  push es
  les di,R
  mov ax,es:[di]
  mov bx,es:[di+2]
  db 66h; mov cx,es:[di+4]
  db 66h; mov dx,es:[di+8]
  mov si,es:[di+12]
  mov di,es:[di+14]
  stc
  int 1Ah

  { Save results before recovering the far record pointer. BP is preserved
    by the specified BIOS interface. BP-based parameter loads use SS, so
    this does not depend on DS/ES still holding their original values. }
  pushf
  push ax
  push bx
  db 66h; push cx
  les di,R
  db 66h; pop cx
  db 66h; mov es:[di+4],cx
  pop bx
  mov es:[di+2],bx
  pop ax
  mov es:[di],ax
  pop ax
  mov es:[di+16],ax
  pop es
  pop ds
  db 66h; popa
  popf
end;

function Completed(const R: TPCIRequest): Boolean;
begin
  Result := ((R.Status and 1)=0) and ((R.A and $FF00)=0);
end;

function FindPCIStatus(DeviceID,VendorID: Word;
  var BusNumber,FunctionNumber: Byte; SearchStart: Word): Word;
var R: TPCIRequest;
begin
  Result := $100; { Invalid request or inconsistent BIOS result. }
  BusNumber := 0; FunctionNumber := 0;
  if VendorID=$FFFF then Exit;
  InitRequest(R,$B102);
  R.C := DeviceID; R.D := VendorID; R.Index := SearchStart;
  InvokeBIOS(R);
  if not Completed(R) then begin
    if ((R.Status and 1)<>0) and ((R.A and $FF00)<>0) then
      Result := R.A shr 8;
    Exit;
  end;
  BusNumber := Byte(R.B shr 8);
  FunctionNumber := Byte(R.B);
  Result := 0;
end;

function Configuration(Operation,Offset: Word; Bus,DevFn: Byte;
  var Value: LongInt): Boolean;
var R: TPCIRequest;
    Alignment: Word;
begin
  Result := False;
  { Conventional PCI BIOS covers 256 bytes, not PCIe extended space. }
  if Offset>$FF then Exit;
  case Operation of
    $B108: Alignment := 0;
    $B10A: Alignment := 3;
  else Exit;
  end;
  if (Offset and Alignment)<>0 then Exit;
  InitRequest(R,Operation);
  R.B := (Word(Bus) shl 8) or Word(DevFn);
  R.C := Value; R.RegisterNo := Offset;
  InvokeBIOS(R);
  if not Completed(R) then Exit;
  Value := R.C;
  Result := True;
end;

function readPCIRegisterByte(RegisterNumber: Word;
  BusNumber,FunctionNumber: Byte; var ResultY: Byte): Boolean;
var Data: LongInt;
begin
  Data := 0;
  Result := Configuration($B108,RegisterNumber,BusNumber,FunctionNumber,Data);
  if Result then ResultY := Byte(Data);
end;

function readPCIRegisterDWord(RegisterNumber: Word;
  BusNumber,FunctionNumber: Byte; var ResultY: LongInt): Boolean;
var Data: LongInt;
begin
  Data := 0;
  Result := Configuration($B10A,RegisterNumber,BusNumber,FunctionNumber,Data);
  if Result then ResultY := Data;
end;

end.
