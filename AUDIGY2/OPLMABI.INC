  { Resident MIDI queue and counters. No external worker protocol. }
  OplEventSlots=1024;
  OplSysExMax=11;

type
  TOplEvent=packed record
    Tick: LongInt;
    Size: Byte; { zero means a packed short message in Data[0..2] }
    Data: array[0..OplSysExMax-1] of Byte;
  end;
  POplEvent=^TOplEvent;
  TOplEventQueue=array[0..OplEventSlots-1] of TOplEvent;
  POplEventQueue=^TOplEventQueue;
  TOplDiag=packed record
    Epoch,Cookie: LongInt;
    Opens,ResetCalls,ResetOK,CloseCalls,CloseOK: LongInt;
    LastOpen,LastReset,LastClose: LongInt;
    DMAStarts,DMAStops,SilentTotal,SilentCurrent,HeadTick: LongInt;
    SkipFIFO,SkipWorker: LongInt;
    Accepted,AcceptedBusy,AcceptedBusyWave2: LongInt;
    FullRejects,BusyRejects: LongInt;
    Controllers,ResetCCs,Programs,NoteOns,LongPackets: LongInt;
    QueueDepth,PeakQueue,FIFOFrames,Playing: Word;
  end;
