type
  TMxClient=record
    Cookie,Flags,Pending: LongInt;
    Desc: TMxOpen;
  end;
var
  MxClients: array[0..7] of TMxClient;
  MxSeen: array[1..MxControlCount] of TMxValues;
  MxObserved,MxNotifying,MxOwnsConfig: Boolean;
  MxSerial,MxSaveTick: LongInt;
