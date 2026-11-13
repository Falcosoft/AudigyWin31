{ Standard Win16 WaveIn state. Queues live in one driver-owned, page-locked
  shared block rather than increasing Delphi 1's 64 KiB static data segment. }
const
  WIDM_GETNUMDEVS=50; WIDM_GETDEVCAPS=51; WIDM_OPEN=52; WIDM_CLOSE=53;
  WIDM_PREPARE=54; WIDM_UNPREPARE=55; WIDM_ADDBUFFER=56;
  WIDM_START=57; WIDM_STOP=58; WIDM_RESET=59; WIDM_GETPOS=60;
  WIDM_INIT=100;
  InputGuard=512;

type
  TInputBuffer=record
    Header: PWaveHdr;
    Data: PChar;
    Size, Used: LongInt;
  end;
  TInputState=record
    Client: TWaveOpenDesc;
    Flags: LongInt;
    Rate, BytesPerSec, Position: LongInt;
    Produced, Consumed, LastPos, LastTick, ProgressTick: LongInt;
    DeliveredBytes, DroppedBytes: LongInt;
    Bits, Channels, Align, Source, Level: Word;
    Head, Tail, Count, NoteHead, NoteTail, NoteCount: Word;
    Fault, MaxGap: Word;
    Running, Pending: Boolean;
    Buffers: array[0..QueueMax-1] of TInputBuffer;
    Notes: array[0..NotifyMax-1] of TNotification;
  end;
  PInputState=^TInputState;
