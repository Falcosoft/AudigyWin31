unit MxTypes;
{ Win16 MSMIXMGR 3.11 layouts, not Win32 handle/version sizes. }
{$F+}
interface
const
  MX_VOLUME=$50030001; MX_FADER=$50030000; MX_EQUALIZER=$50030004;
  MX_ONOFF=$20010001; MX_SINGLE=$70010000; MX_MUX=$70010001;
  MX_UNIFORM=1; MX_MULTIPLE=2;
  MX_HANDLE=LongInt($80000000);
  MX_CONTROL_CHANGE=$3D1;
  { Audigy control IDs and the cutoff scale, not changes to the Win16 ABI. }
  MxBassRedirect=17; MxBassCutoff=18;
  MxBassMinHz=60; MxBassMaxHz=160; MxBassStepHz=5;
  MxBassSteps=(MxBassMaxHz-MxBassMinHz) div MxBassStepHz;
type
  TMxCaps=packed record
    Mid,Pid,Version: Word;
    Name: array[0..31] of Char;
    Support,Destinations: LongInt;
  end;
  PMxCaps=^TMxCaps;
  TMxTarget=packed record
    Kind,DeviceID: LongInt;
    Mid,Pid,Version: Word;
    Name: array[0..31] of Char;
  end;
  TMxLine=packed record
    Size,Destination,Source,ID,Flags,User,Component: LongInt;
    Channels,Connections,Controls: LongInt;
    ShortName: array[0..15] of Char;
    Name: array[0..63] of Char;
    Target: TMxTarget;
  end;
  PMxLine=^TMxLine;
  TMxControl=packed record
    Size,ID,Kind,Flags,Items: LongInt;
    ShortName: array[0..15] of Char;
    Name: array[0..63] of Char;
    Minimum,Maximum: LongInt;
    BoundReserved: array[0..3] of LongInt;
    Steps: LongInt;
    MetricReserved: array[0..4] of LongInt;
  end;
  PMxControl=^TMxControl;
  TMxLineControls=packed record
    Size,LineID,Control,Count,ControlSize: LongInt;
    Data: Pointer;
  end;
  PMxLineControls=^TMxLineControls;
  TMxDetails=packed record
    Size,ControlID,Channels,Items,DetailSize: LongInt;
    Data: Pointer;
  end;
  PMxDetails=^TMxDetails;
  TMxListText=packed record
    Param1,Param2: LongInt;
    Name: array[0..63] of Char;
  end;
  PMxListText=^TMxListText;
  TMxOpen=packed record
    Handle: Word;
    Reserved: Pointer;
    Callback,Instance: LongInt;
  end;
  PMxOpen=^TMxOpen;
  TMxValues=array[0..9] of LongInt;
  PMxValues=^TMxValues;
implementation
end.
