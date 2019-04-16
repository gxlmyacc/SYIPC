unit SYIPCMessage;

interface

uses
  Windows, Variants, SysUtils, Classes, SYIPCCommon, SYIPCBase, SYIPCIntf;

type
  TIPCMessage = class(TInterfacedObject, IIPCMessage)
  private
    FOwner: TObject;
    FSenderID: Cardinal;
    FReadOnly: Boolean;
    FData: TMessageData;
    FDataSize: Cardinal;
    FDataType: TIPCMessageDataType;
    FTopic: Byte;
    FTag: Pointer;
  protected
    function GetData: TMessageData;
    function GetDataSize: Cardinal;
    function GetDataType: TIPCMessageDataType;
    function GetReadOnly: Boolean;
    function GetSenderID: Cardinal;
    function GetTopic: Byte;
    function GetI: Int64;
    function GetB: Boolean;
    function GetD: Double;
    function GetC: Currency;
    function GetDT: TDateTime;
    function GetS: WideString;
    function GetTag: Pointer;
    procedure SetDataType(const Value: TIPCMessageDataType);
    procedure SetSenderID(const Value: Cardinal);
    procedure SetI(const Value: Int64);
    procedure SetB(const Value: Boolean);
    procedure SetD(const Value: Double);
    procedure SetC(const Value: Currency);
    procedure SetDT(const Value: TDateTime);
    procedure SetS(const Value: WideString);
    procedure SetTopic(const Value: Byte);
    procedure SetTag(const Value: Pointer);

    procedure Rebuild(const ADataSize: Cardinal; const ADataType: TIPCMessageDataType);
  public
    constructor Create(const AOwner: TObject; const ADataType: TIPCMessageDataType = mdtUnknown);
    constructor CreateReadOnly(const AOwner: TObject; const AData: TMessageData; const ADataSize: Cardinal;
      const ADataType: TIPCMessageDataType; const ATopic: Byte); 
    destructor Destroy; override;

    function Implementor: Pointer;

    function  Clone: IIPCMessage;
    procedure Clear;
    procedure SetData(const AData: TMessageData; const ADataSize: Cardinal); overload;
    procedure SetData(const AData: TMessageData; const ADataSize: Cardinal; const ADataType: TIPCMessageDataType); overload;
    procedure Add(const AData: TMessageData; const ADataSize: Cardinal); overload;
    procedure Add(const AData: TMessageData; const ADataSize: Cardinal; const ADataType: TIPCMessageDataType); overload;
    procedure Add(const AData: WideString); overload;
    
    function LoadFromFile(const AFileName: WideString; const ADataType: TIPCMessageDataType = mdtFile): Boolean;
    function SaveToFile(const AFileName: WideString; const bFailIfExist: Boolean = True): Boolean;
    
    property ReadOnly: Boolean read GetReadOnly;
    property S: WideString read GetS write SetS;
    property I: Int64 read GetI write SetI;
    property B: Boolean read GetB write SetB;
    property D: Double read GetD write SetD;
    property C: Currency read GetC write SetC;
    property DT: TDateTime read GetDT write SetDT;
    property Data: TMessageData read GetData;
    property DataSize: Cardinal read GetDataSize;
    property DataType: TIPCMessageDataType read GetDataType write SetDataType;
    property SenderID: Cardinal read GetSenderID write SetSenderID;
    property Topic: Byte read GetTopic write SetTopic;
    property Tag: Pointer read GetTag write SetTag;
  end;

function V2M(const AValue: OleVariant): IIPCMessage; overload;
function V2M(const AValue: TVarData): IIPCMessage; overload;
function M2V(const AMessage: IIPCMessage): OleVariant;

implementation

type
  TIPCBaseAccess = class(TIPCBase);

resourcestring
  SErrorReadOnly = 'This IPCMessage is readonly, it cannot be writed.';

function V2M(const AValue: OleVariant): IIPCMessage;
begin
  Result := V2M(TVarData(AValue));
end;

function V2M(const AValue: TVarData): IIPCMessage;
var
  LMessage: IIPCMessage;
begin
  Result := TIPCMessage.Create(nil);
  case AValue.VType of
    varEmpty, varNull: ;
    varString:
      Result.S  := StringToOleStr(PAnsiString(AValue.VString)^);
    {$IF CompilerVersion > 18.5}
    varUString:
      Result.S  := PUnicodeString(AValue.VUString)^;
    {$IFEND}
    varOleStr:
      Result.S  := AValue.VOleStr;
    varBoolean:
      Result.B  := AValue.VBoolean;
    varByte:
      Result.I  := AValue.VByte;
    varSmallInt:
      Result.I  := AValue.VSmallInt;
    varInteger:
      Result.I  := AValue.VInteger;
    varWord:
      Result.I  := AValue.VWord;
    varLongWord:
      Result.I  := AValue.VLongWord;
    varInt64:
      Result.I  := AValue.VInt64;
    varShortInt:
      Result.I  := AValue.VShortInt;
    varSingle:
      Result.D  := AValue.VSingle;
    varDouble:
      Result.D  := AValue.VDouble;
    varCurrency:
      Result.C  := AValue.VCurrency;
    varDate:
      Result.DT := AValue.VDate;
    varUnknown:
    begin
      if (AValue.VType = varUnknown)
        and (IUnknown(AValue.VUnknown).QueryInterface(IIPCMessage, LMessage) = S_OK) then
      begin
        Result := LMessage;
        Exit;
      end;    
    end;
  else
    Result.Add(Format('IPCMessage不支持的数据类型[%d]！', [AValue.VType]));
    Result.DataType := mdtError;
  end;
end;

function M2V(const AMessage: IIPCMessage): OleVariant;
begin
  if AMessage = nil then
  begin
    Result := varEmpty;
    Exit;
  end;
  case AMessage.DataType of
    mdtString:   Result := AMessage.S;
    mdtInteger:  Result := AMessage.I;
    mdtBoolean:  Result := AMessage.B;
    mdtDouble:   Result := AMessage.D;
    mdtCurrency: Result := AMessage.C;
    mdtDateTime: Result := AMessage.DT;
    mdtUnknown:  Result := AMessage;
    //mdtCallback: Result := AMessage;
  else          
    if AMessage.DataType >= mdtCustomBase then
      Result := AMessage
    else
      TVarData(Result).VType := varError;
  end;
end;

{ TIPCMessage }

constructor TIPCMessage.Create(const AOwner: TObject; const ADataType: TIPCMessageDataType);
begin
  FOwner := AOwner;
  FData := nil;
  FDataSize := 0;
  FDataType := ADataType;
  FReadOnly := False;
end;

procedure TIPCMessage.Add(const AData: TMessageData;
  const ADataSize: Cardinal; const ADataType: TIPCMessageDataType);
var
  iOldDataSize: Cardinal;
begin
  if ADataSize <= 0 then
    Exit;
  iOldDataSize := FDataSize;
  Rebuild(FDataSize + ADataSize, ADataType);
  CopyMemory(@FData[iOldDataSize], AData, ADataSize);
end;

procedure TIPCMessage.Add(const AData: WideString);
begin
  {$WARNINGS OFF}
  Add(TMessageData(AData), Length(AData) * IPC_CHAR_SIZE, mdtString);
  {$WARNINGS ON}
end;

constructor TIPCMessage.CreateReadOnly(const AOwner: TObject; const AData: TMessageData;
  const ADataSize: Cardinal; const ADataType: TIPCMessageDataType;
  const ATopic: Byte);
begin
  FOwner := AOwner;
  FReadOnly := True;
  FData := AData;
  FDataSize := ADataSize;
  FDataType := ADataType;
  FTopic := ATopic;
end;

destructor TIPCMessage.Destroy;
begin
  if (not FReadOnly) and (FData <> nil) and (FDataSize > 0) then
    Rebuild(0, mdtUnknown);
  inherited;
end;

function TIPCMessage.GetC: Currency;
begin
  if FData = nil then
    Result := 0.0
  else
    Result := Currency(Pointer(FData)^);
end;

function TIPCMessage.GetD: Double;
begin
  if FData = nil then
    Result := 0.0
  else
    Result := Double(Pointer(FData)^);
end;

function TIPCMessage.GetData: TMessageData;
begin
  Result := FData;
end;

function TIPCMessage.GetDataSize: Cardinal;
begin
  Result := FDataSize;
end;

function TIPCMessage.GetDataType: TIPCMessageDataType;
begin
  Result := FDataType;
end;

function TIPCMessage.GetDT: TDateTime;
begin
  if FData = nil then
    Result := 0
  else
    Result := TDateTime(Pointer(FData)^);
end;

function TIPCMessage.GetI: Int64;
begin
  if FData = nil then
    Result := 0
  else
    Result := Int64(Pointer(FData)^);
end;

function TIPCMessage.GetS: WideString;
begin
  if FDataSize <= 0 then
    Result := ''
  else
  begin
    SetLength(Result, FDataSize div IPC_CHAR_SIZE);
    if FData <> nil then
      CopyMemory(@Result[1], @PByteArray(FData)[0], FDataSize);
  end;
end;

function TIPCMessage.Implementor: Pointer;
begin
  Result := Self;
end;

procedure TIPCMessage.Rebuild(const ADataSize: Cardinal; const ADataType: TIPCMessageDataType);
begin
  if FReadOnly then
    raise ESYIPCExection.Create(SErrorReadOnly);
  FDataType := ADataType;
  if ADataSize <= 0 then
  begin
    if FData <> nil then
    begin
      FreeMem(FData);
      FData := nil;
      FDataSize := 0;
    end;
  end
  else
  if FData = nil then
    FData := AllocMem(ADataSize)
  else
    FData := ReallocMemory(FData, ADataSize);
  FDataSize := ADataSize;
end;

procedure TIPCMessage.SetC(const Value: Currency);
begin
  if FReadOnly then
    raise ESYIPCExection.Create(SErrorReadOnly);
  if FDataType <> mdtCurrency then
    Rebuild(SizeOf(Value), mdtCurrency);
  Currency(Pointer(FData)^) := Value;
end;

procedure TIPCMessage.SetD(const Value: Double);
begin
  if FReadOnly then
    raise ESYIPCExection.Create(SErrorReadOnly);
  if FDataType <> mdtDouble then
    Rebuild(SizeOf(Value), mdtDouble);
  Double(Pointer(FData)^) := Value;
end;

procedure TIPCMessage.SetData(const AData: TMessageData;
  const ADataSize: Cardinal);
begin
  SetData(AData, ADataSize, FDataType);
end;

procedure TIPCMessage.SetData(const AData: TMessageData;
  const ADataSize: Cardinal; const ADataType: TIPCMessageDataType);
begin
  Rebuild(ADataSize, ADataType);
  if FDataSize > 0 then
    CopyMemory(FData, AData, ADataSize)
end;

procedure TIPCMessage.SetDT(const Value: TDateTime);
begin
  if FReadOnly then
    raise ESYIPCExection.Create(SErrorReadOnly);
  if FDataType <> mdtDateTime then
    Rebuild(SizeOf(Value), mdtDateTime);
  TDateTime(Pointer(FData)^) := Value;
end;

procedure TIPCMessage.SetI(const Value: Int64);
begin
  if FReadOnly then
    raise ESYIPCExection.Create(SErrorReadOnly);
  if FDataType <> mdtInteger then
    Rebuild(SizeOf(Value), mdtInteger);
  Int64(Pointer(FData)^) := Value;
end;

procedure TIPCMessage.SetS(const Value: WideString);
begin
  if FReadOnly then
    raise ESYIPCExection.Create(SErrorReadOnly);
  if (FDataType <> mdtString) or (FDataSize <> Cardinal(Length(Value) * IPC_CHAR_SIZE)) then
    Rebuild(Length(Value) * IPC_CHAR_SIZE, mdtString);
  if FDataSize > 0 then
    Move(Value[1], FData^, FDataSize);   
end;

procedure TIPCMessage.Clear;
begin
  Rebuild(0, mdtUnknown);
end;

function TIPCMessage.LoadFromFile(const AFileName: WideString;
  const ADataType: TIPCMessageDataType): Boolean;
var
  fs: TFileStream;
begin
  if FReadOnly then
    raise ESYIPCExection.Create(SErrorReadOnly);
  Result := False;
  if not FileExists(AFileName) then
    Exit;
  fs := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Rebuild(fs.Size, ADataType);
    Result := fs.Read(FData^, fs.Size) = fs.Size;
  finally
    fs.Free;
  end;   
end;

function TIPCMessage.SaveToFile(const AFileName: WideString;
  const bFailIfExist: Boolean): Boolean;
var
  fs: TFileStream;
begin
  Result := False;
  if (FDataSize <= 0) or (FData = nil) then
    Exit;
  if bFailIfExist and FileExists(AFileName) then
    Exit;
  fs := TFileStream.Create(AFileName, fmCreate or fmOpenWrite or fmShareDenyWrite);
  try
    fs.Position := 0;
    Result := Cardinal(fs.Write(FData^, FDataSize)) = FDataSize;
  finally
    fs.Free;
  end;
end;

procedure TIPCMessage.SetDataType(const Value: TIPCMessageDataType);
begin
  FDataType := Value;
end;

function TIPCMessage.GetReadOnly: Boolean;
begin
  Result := FReadOnly;
end;

function TIPCMessage.GetTopic: Byte;
begin
  Result := FTopic;
end;

procedure TIPCMessage.SetTopic(const Value: Byte);
begin
  FTopic := Value;
end;

function TIPCMessage.Clone: IIPCMessage;
begin
  Result := TIPCMessage.Create(FOwner);
  Result.SetData(FData, FDataSize, FDataType);
  Result.Topic := FTopic;
  Result.SenderID := FSenderID;
  Result.Tag := FTag;
end;

function TIPCMessage.GetSenderID: Cardinal;
begin
  Result := FSenderID;
end;

procedure TIPCMessage.SetSenderID(const Value: Cardinal);
begin
  FSenderID := Value;
end;

function TIPCMessage.GetTag: Pointer;
begin
  Result := FTag;
end;

procedure TIPCMessage.SetTag(const Value: Pointer);
begin
  FTag := FTag;
end;

function TIPCMessage.GetB: Boolean;
begin
  if FData = nil then
    Result := False
  else
    Result := Boolean(Pointer(FData)^);
end;

procedure TIPCMessage.SetB(const Value: Boolean);
begin
  if FReadOnly then
    raise ESYIPCExection.Create(SErrorReadOnly);
  if FDataType <> mdtBoolean then
    Rebuild(SizeOf(Value), mdtBoolean);
  Boolean(Pointer(FData)^) := Value;
end;

procedure TIPCMessage.Add(const AData: TMessageData;
  const ADataSize: Cardinal);
begin
  Add(AData, ADataSize, FDataType);
end;

end.
