unit MxLoad;
{ Optional Win16 mixer API. No static import of MSMIXMGR.DLL. }
{$F+}
interface
uses WinTypes,WinProcs,MxTypes;
type
  TMxNum=function: Word;
  TMxCapsProc=function(ID: Word; Caps: Pointer; Bytes: Word): Word;
  TMxOpenProc=function(Handle: Pointer; ID: Word;
                        Callback,Instance,Flags: LongInt): Word;
  TMxCloseProc=function(Handle: Word): Word;
  TMxInfoProc=function(Handle: Word; Info: Pointer; Flags: LongInt): Word;
var
  mixerGetNumDevs: TMxNum;
  mixerGetDevCaps: TMxCapsProc;
  mixerOpen: TMxOpenProc;
  mixerClose: TMxCloseProc;
  mixerGetLineInfo,mixerGetLineControls: TMxInfoProc;
  mixerGetControlDetails,mixerSetControlDetails: TMxInfoProc;
function MxLoadAPI: Boolean;
procedure MxFreeAPI;
implementation
var Module: THandle;
procedure MxFreeAPI;
begin
  @mixerGetNumDevs := nil; @mixerGetDevCaps := nil;
  @mixerOpen := nil; @mixerClose := nil;
  @mixerGetLineInfo := nil; @mixerGetLineControls := nil;
  @mixerGetControlDetails := nil; @mixerSetControlDetails := nil;
  if Module>=32 then FreeLibrary(Module);
  Module := 0;
end;
function MxLoadAPI: Boolean;
begin
  if Module>=32 then begin Result := True; Exit; end;
  Module := LoadLibrary('MSMIXMGR.DLL');
  if Module<32 then begin Module := 0; Result := False; Exit; end;
  @mixerGetNumDevs := GetProcAddress(Module,'MIXERGETNUMDEVS');
  @mixerGetDevCaps := GetProcAddress(Module,'MIXERGETDEVCAPS');
  @mixerOpen := GetProcAddress(Module,'MIXEROPEN');
  @mixerClose := GetProcAddress(Module,'MIXERCLOSE');
  @mixerGetLineInfo := GetProcAddress(Module,'MIXERGETLINEINFO');
  @mixerGetLineControls := GetProcAddress(Module,'MIXERGETLINECONTROLS');
  @mixerGetControlDetails := GetProcAddress(Module,'MIXERGETCONTROLDETAILS');
  @mixerSetControlDetails := GetProcAddress(Module,'MIXERSETCONTROLDETAILS');
  Result := Assigned(mixerGetNumDevs) and Assigned(mixerGetDevCaps) and
    Assigned(mixerOpen) and Assigned(mixerClose) and Assigned(mixerGetLineInfo) and
    Assigned(mixerGetLineControls) and Assigned(mixerGetControlDetails) and
    Assigned(mixerSetControlDetails);
  if not Result then MxFreeAPI;
end;
begin
  Module := 0;
end.
