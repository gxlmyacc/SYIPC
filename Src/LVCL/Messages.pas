unit Messages;

interface

const
  WM_DESTROY          = $0002;
  WM_QUIT             = $0012;
  WM_COPYDATA         = $004A;
  
  WM_USER             = $0400;

type
  PMessage = ^TMessage;
  TMessage = packed record
    Msg: Cardinal;
    case Integer of
      0: (
        WParam: Longint;
        LParam: Longint;
        Result: Longint);
      1: (
        WParamLo: Word;
        WParamHi: Word;
        LParamLo: Word;
        LParamHi: Word;
        ResultLo: Word;
        ResultHi: Word);
  end;

implementation

end.