unit SYIPCMasks;

interface

uses SysUtils;

type
  EMaskException = class(Exception);

  TMask = class
  private
    FMask: Pointer;
    FSize: Integer;
  public
    constructor Create(const MaskValue: WideString);
    destructor Destroy; override;
    function Matches(const MatchName: PWideChar): Boolean;
  end;

function MatchesMask(const MatchName, Mask: WideString): Boolean; overload;
function MatchesMask(const MatchName: PWideChar; const Mask: WideString): Boolean; overload;

implementation

resourcestring
  SInvalidMask = '''%s'' is an invalid mask at (%d)';

const
  MaxCards = 30;

type
  PMaskSet = ^TMaskSet;
  TMaskSet = set of AnsiChar;
  TMaskStates = (msLiteral, msAny, msSet, msMBCSLiteral);
  TMaskState = record
    SkipTo: Boolean;
    case State: TMaskStates of
      msLiteral: (Literal: WideChar);
      msAny: ();
      msSet: (
        Negate: Boolean;
        CharSet: PMaskSet);
      msMBCSLiteral: (LeadByte, TrailByte: WideChar);
  end;
  PMaskStateArray = ^TMaskStateArray;
  TMaskStateArray = array[0..128] of TMaskState;

function IsLeadChar(const C: WideChar): Boolean;
begin
  Result := (C >= #$D800) and (C <= #$DFFF);
end;

function UpCase(const Ch: WideChar): WideChar;
begin
  Result := Ch;
  case Ch of
    'a'..'z':
      Result := WideChar(Word(Ch) and $FFDF);
  end;
end;

function CharInSet(const C: WideChar; const CharSet: TSysCharSet): Boolean;
begin
  {$IF CompilerVersion > 18.5}
    Result := SysUtils.CharInSet(C, CharSet);
  {$ELSE}
  Result := AnsiChar(C) in CharSet;
  {$IFEND}
end;

function InitMaskStates(const Mask: WideString;
  var MaskStates: array of TMaskState): Integer;
var
  I: Integer;
  SkipTo: Boolean;
  Literal: WideChar;
  LeadByte, TrailByte: WideChar;
  P: PWideChar;
  Negate: Boolean;
  CharSet: TMaskSet;
  Cards: Integer;

  procedure InvalidMask;
  begin
    raise EMaskException.CreateResFmt(@SInvalidMask, [Mask,
      P - PWideChar(Mask) + 1]);
  end;

  procedure Reset;
  begin
    SkipTo := False;
    Negate := False;
    CharSet := [];
  end;

  procedure WriteScan(MaskState: TMaskStates);
  begin
    if I <= High(MaskStates) then
    begin
      if SkipTo then
      begin
        Inc(Cards);
        if Cards > MaxCards then InvalidMask;
      end;
      MaskStates[I].SkipTo := SkipTo;
      MaskStates[I].State := MaskState;
      case MaskState of
        msLiteral: MaskStates[I].Literal := UpCase(Literal);
        msSet:
          begin
            MaskStates[I].Negate := Negate;
            New(MaskStates[I].CharSet);
            MaskStates[I].CharSet^ := CharSet;
          end;
        msMBCSLiteral:
          begin
            MaskStates[I].LeadByte := LeadByte;
            MaskStates[I].TrailByte := TrailByte;
          end;
      end;
    end;
    Inc(I);
    Reset;
  end;

  procedure ScanSet;
  var
    LastChar: WideChar;
    C: WideChar;
  begin
    Inc(P);
    if P^ = '!' then
    begin
      Negate := True;
      Inc(P);
    end;
    LastChar := #0;
    while (P^ <> #0) and (P^ <> ']') do
    begin
      // MBCS characters not supported in msSet!
      if IsLeadChar(P^) then
         Inc(P)
      else
      case P^ of
        '-':
          if LastChar = #0 then InvalidMask
          else
          begin
            Inc(P);
            for C := LastChar to UpCase(P^) do
              Include(CharSet, AnsiChar(C));
          end;
      else
        LastChar := UpCase(P^);
                                                                          
        Include(CharSet, AnsiChar(LastChar));
      end;
      Inc(P);
    end;
    if (P^ <> ']') or (CharSet = []) then InvalidMask;
    WriteScan(msSet);
  end;

begin
  P := PWideChar(Mask);
  I := 0;
  Cards := 0;
  Reset;
  while P^ <> #0 do
  begin
    case P^ of
      '*': SkipTo := True;
      '?': if not SkipTo then WriteScan(msAny);
      '[':  ScanSet;
    else
      if IsLeadChar(P^) then
      begin
        LeadByte := P^;
        Inc(P);
        TrailByte := P^;
        WriteScan(msMBCSLiteral);
      end
      else
      begin
        Literal := P^;
        WriteScan(msLiteral);
      end;
    end;
    Inc(P);
  end;
  Literal := #0;
  WriteScan(msLiteral);
  Result := I;
end;

function MatchesMaskStates(const Filename: PWideChar;
  const MaskStates: array of TMaskState): Boolean;
type
  TStackRec = record
    sP: PWideChar;
    sI: Integer;
  end;
var
  T: Integer;
  S: array[0..MaxCards - 1] of TStackRec;
  I: Integer;
  P: PWideChar;

  procedure Push(P: PWideChar; I: Integer);
  begin
    with S[T] do
    begin
      sP := P;
      sI := I;
    end;
    Inc(T);
  end;

  function Pop(var P: PWideChar; var I: Integer): Boolean;
  begin
    if T = 0 then
      Result := False
    else
    begin
      Dec(T);
      with S[T] do
      begin
        P := sP;
        I := sI;
      end;
      Result := True;
    end;
  end;

  function Matches(P: PWideChar; Start: Integer): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    for I := Start to High(MaskStates) do
      with MaskStates[I] do
      begin
        if SkipTo then
        begin
          case State of
            msLiteral:
              while (P^ <> #0) and (UpCase(P^) <> Literal) do Inc(P);
            msSet:
              while (P^ <> #0) and not (Negate xor CharInSet(UpCase(P^), CharSet^)) do Inc(P);
            msMBCSLiteral:
              while (P^ <> #0) do
              begin
                if (P^ <> LeadByte) then Inc(P, 2)
                else
                begin
                  Inc(P);
                  if (P^ = TrailByte) then Break;
                  Inc(P);
                end;
              end;
          end;
          if P^ <> #0 then
            Push(@P[1], I);
        end;
        case State of
          msLiteral: if UpCase(P^) <> Literal then Exit;
          msSet: if not (Negate xor CharInSet(UpCase(P^), CharSet^)) then Exit;
          msMBCSLiteral:
            begin
              if P^ <> LeadByte then Exit;
              Inc(P);
              if P^ <> TrailByte then Exit;
            end;
          msAny:
            if P^ = #0 then
            begin
              Result := False;
              Exit;
            end;
        end;
        Inc(P);
      end;
    Result := True;
  end;

begin
  Result := True;
  T := 0;
  P := PWideChar(Filename);
  I := Low(MaskStates);
  repeat
    if Matches(P, I) then Exit;
  until not Pop(P, I);
  Result := False;
end;

procedure DoneMaskStates(var MaskStates: array of TMaskState);
var
  I: Integer;
begin
  for I := Low(MaskStates) to High(MaskStates) do
    if MaskStates[I].State = msSet then Dispose(MaskStates[I].CharSet);
end;

{ TMask }

constructor TMask.Create(const MaskValue: WideString);
var
  A: array[0..0] of TMaskState;
begin
  FSize := InitMaskStates(MaskValue, A);
  DoneMaskStates(A);

  FMask := AllocMem(FSize * SizeOf(TMaskState));
  InitMaskStates(MaskValue, Slice(PMaskStateArray(FMask)^, FSize));
end;

destructor TMask.Destroy;
begin
  if FMask <> nil then
  begin
    DoneMaskStates(Slice(PMaskStateArray(FMask)^, FSize));
    FreeMem(FMask, FSize * SizeOf(TMaskState));
  end;
end;

function TMask.Matches(const MatchName: PWideChar): Boolean;
begin
  Result := MatchesMaskStates(MatchName, Slice(PMaskStateArray(FMask)^, FSize));
end;

function MatchesMask(const MatchName, Mask: WideString): Boolean;
var
  CMask: TMask;
begin
  CMask := TMask.Create(Mask);
  try
    Result := CMask.Matches(PWideChar(MatchName));
  finally
    CMask.Free;
  end;
end;

function MatchesMask(const MatchName: PWideChar; const Mask: WideString): Boolean; overload;
var
  CMask: TMask;
begin
  CMask := TMask.Create(Mask);
  try
    Result := CMask.Matches(MatchName);
  finally
    CMask.Free;
  end;
end;

end.
