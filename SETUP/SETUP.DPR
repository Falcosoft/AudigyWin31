program Setup;

{ Standalone Win16 installer. Never links or loads an audio driver. }
{$M 16384,8192}
uses WinTypes, WinProcs, SPanel;

{$R SETUP.RES}

begin
  RunSetup;
end.
