unit SYIPCServer;

interface

uses
  Windows, Messages, SysUtils, Classes,
  SYIPCCommon, SYIPCBase, SYIPCMessageLoop, SYIPCIntf;

type
  TIPCServer = class(TIPCBase, IIPCServer)
  protected
    FClientList: TThreadList;
    FLastClientID: Cardinal;
    FOnMessage: TIPCServerMessageEvent;
    function GetClientCount: Integer;
    function GetClientInfos: WideString;
    function GetLastClientID: Cardinal;
    function GetOnMessage: TIPCServerMessageEvent;
    procedure SetActive(const Value: Boolean); override;
    procedure SetOnMessage(const Value: TIPCServerMessageEvent);
  protected
    procedure WndProc(var AMsg: TMessage); override;
    function DoHandleMessage(const AState: TIPCState; const ASenderID: Cardinal; const AData: PCopyDataStruct;
      const ADataType: TIPCMessageDataType = mdtUnknown; const ATopic: Byte = 0): Boolean; override;
    function DoMessage(const ASelf: TIPCBase; const AState: TIPCState;
      const ASenderID: Cardinal; const AMessage: IIPCMessage): Boolean; override;
      
    function DoBroadcast(const AData: Pointer; const ADataLen: Cardinal;
      const ADataType: TIPCMessageDataType; const AExclude, ATimeOut: Cardinal; const ATopic: Byte = 0): Boolean;
    procedure DoBroadcastMessage(Msg: UINT; wParam: WPARAM; lParam: LPARAM);
    procedure DoRemoveClient(const AClient: Cardinal);
  public
    constructor Create; override;
    destructor Destroy; override;

    function Open: Boolean; overload;
    function Open(const ASessionName: WideString): Boolean; overload;
    procedure Close; override;
    function IsConnect(const AClientID: Cardinal): Boolean;

    function Send(const AClientID: Cardinal; const AData: IIPCMessage; const ATimeOut: Cardinal): Boolean; overload;
    function Send(const AClientID: Cardinal; const AData: Pointer; const ADataLen, ATimeOut: Cardinal): Boolean; overload;
    function Send(const AClientID: Cardinal; const AData: WideString; const ATimeOut: Cardinal): Boolean; overload;
    function Send(const AClientID: Cardinal; const AData: Int64; const ATimeOut: Cardinal): Boolean; overload;
    function Send(const AClientID: Cardinal; const AData: Boolean; const ATimeOut: Cardinal): Boolean; overload;
    function Send(const AClientID: Cardinal; const AData: Double; const ATimeOut: Cardinal): Boolean; overload;
    function SendC(const AClientID: Cardinal; const AData: Currency; const ATimeOut: Cardinal): Boolean;
    function SendDT(const AClientID: Cardinal; const AData: TDateTime; const ATimeOut: Cardinal): Boolean;
    function SendFile(const AClientID: Cardinal; const AFileName: WideString; ATimeOut: Cardinal): Boolean;
    
    function Broadcast(const AData: IIPCMessage; const AExclude, ATimeOut: Cardinal): Boolean; overload;
    function Broadcast(const AData: Pointer; const ADataLen, AExclude, ATimeOut: Cardinal): Boolean; overload;
    function Broadcast(const AData: WideString; const AExclude, ATimeOut: Cardinal): Boolean; overload;
    function BroadcastFile(const AFileName: WideString; const AExclude, ATimeOut: Cardinal): Boolean;
  public
    property ClientCount: Integer read GetClientCount;
    property ClientInfos: WideString read GetClientInfos;
    property LastClientID: Cardinal read GetLastClientID;
    property OnMessage: TIPCServerMessageEvent read GetOnMessage write SetOnMessage;
  end;

implementation

uses
 {$IF CompilerVersion > 18.5}Types,{$IFEND}SYIPCUtils, SYIPCUtilsImpl;

{ TIPCServer }

constructor TIPCServer.Create;
begin
  FClientList := TThreadList.Create;
  inherited Create;
end;


destructor TIPCServer.Destroy;
begin
  inherited Destroy;
  if FClientList <> nil then
    FreeAndNil(FClientList);
end;

function TIPCServer.Open: Boolean;
  procedure _FindExistClient;
  var
    F: PIPCSearchRec;
  begin
    if not ___IPCFindFirst(WideFormat(IPCWindowNameClientFmt, [FSessionHandle, FSessionName]), F, True) then
      Exit;
    try
      repeat
        SendMessageTimeout(FID, FConnectRequestHwnd, FSessionHandle, F.FindID, IPC_TIMEOUT_OPENCLOSE);
      until not IPCFindNext(F);
    finally
      IPCFindClose(F);
    end;   
  end;
var
  hServerID: Cardinal;
  sIPCServerName: WideString;
begin
  if FActive then
  begin
    Result := True;
    Exit;
  end;
  FSessionHandle := MainThreadWindow.AllocSession(FSessionName);
  if FSessionHandle = 0 then
  begin
    FLastError := '无法注册['+FSessionName+']消息！';
    Result := False;
    Exit;  
  end;
  sIPCServerName := GetIPCServerName(FSessionName, FSessionHandle);
  hServerID := FindWindowW(IPCWindowClassName, PWideChar(sIPCServerName));
  if (hServerID <> 0) and (IsWindow(hServerID)) then
  begin
    FLastError := '会话['+FSessionName+']已经存在，不能再创建！';
    Result := False;
    Exit;
  end;
  //AllowMeesageForVistaAbove(FSessionHandle, True);
  FID := FMessageLoop.AllocateThreadHWND(WndProc, sIPCServerName);
  if FID = 0 then
  begin
    FLastError := '无法创建窗口句柄！';
    Result := False;
    Exit;
  end;
  FActive := True;
  DoHandleMessage(isAfterOpen, FID, nil);
  //如果IPC服务端上次以外关闭，则下次启动时自动连接以及存在的IPC客户度
  _FindExistClient;
  Result := True;
end;

function TIPCServer.Open(const ASessionName: WideString): Boolean;
begin
  Assert(ASessionName <> '');
  if (FSessionName <> '') and (ASessionName <> FSessionName) and FActive then
    Close;
  if FActive then
  begin
    Result := True;
    Exit;
  end;
  SessionName := ASessionName;
  Result := Open;
end;

procedure TIPCServer.Close;
begin
  if not FActive then
   Exit;
  if FID = 0 then
    Exit;
  DoBroadcastMessage(FServerDisconnetHwnd, FSessionHandle, FID);
  //PostMessage(HWND_BROADCAST, FServerDisconnetHwnd, FSessionHandle, FServerID);
  if FMessageLoop <> nil then
    FMessageLoop.DeallocateThreadHWND(FID);
  FActive := False;
  DoHandleMessage(isAfterClose, FID, nil);
  if FSessionHandle <> 0 then
  begin
    MainThreadWindow.DeallocSession(FSessionHandle);
    FSessionHandle := 0;
  end;
  FID := 0;
end;

procedure TIPCServer.WndProc(var AMsg: TMessage);
var
  hClientID: Cardinal;
begin
  if AMsg.WParamLo <> FSessionHandle then
  begin
    AMsg.Result := DefWindowProc(FID, AMsg.Msg, AMsg.WParam, AMsg.LParam);
    Exit;
  end;
  inherited WndProc(AMsg);
  if AMsg.Result = 1 then
    Exit;
  if AMsg.Msg = FConnectRequestHwnd then
  begin
    if FActive then
    begin
      hClientID := AMsg.lParam;
      if hClientID <> 0 then
      begin
        AMsg.Result := SendMessage(hClientID, FConnectResposeHwnd, FSessionHandle, FID);
        DoHandleMessage(SYIPCIntf.isConnect, hClientID, nil);
      end;
    end;  
  end
  else
  if AMsg.Msg = FClientDisconnetHwnd then
  begin
    if FActive then
    begin
      hClientID := AMsg.lParam;
      if hClientID <> 0 then
      begin
        DoHandleMessage(isDisconnect, hClientID, nil);
        AMsg.Result := 1;
      end;
    end;
  end;
end;

function TIPCServer.Send(const AClientID: Cardinal; const AData: Pointer;
  const ADataLen, ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(AClientID, AData, ADataLen, mdtUnknown, ATimeOut);
end;

function TIPCServer.Send(const AClientID: Cardinal;
  const AData: IIPCMessage; const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(AClientID, AData.Data, AData.DataSize, AData.DataType, ATimeOut, AData.Topic);
end;

procedure TIPCServer.SetActive(const Value: Boolean);
begin
  if FActive = Value then
    Exit;
  if Value then
    Open
  else
    Close;
end;

function TIPCServer.GetOnMessage: TIPCServerMessageEvent;
begin
  Result := FOnMessage;
end;

procedure TIPCServer.SetOnMessage(const Value: TIPCServerMessageEvent);
begin
  FOnMessage := Value;
end;

function TIPCServer.Broadcast(const AData: IIPCMessage;
  const AExclude, ATimeOut: Cardinal): Boolean;
begin
  Result := DoBroadcast(AData.Data, AData.DataSize, AData.DataType, AExclude, ATimeOut, AData.Topic);
end;

function TIPCServer.Broadcast(const AData: Pointer; const ADataLen, AExclude, ATimeOut: Cardinal): Boolean;
begin
  Result := DoBroadcast(AData, ADataLen, mdtUnknown, AExclude, ATimeOut);
end;      

function TIPCServer.DoHandleMessage(const AState: TIPCState; const ASenderID: Cardinal;
  const AData: PCopyDataStruct; const ADataType: TIPCMessageDataType; const ATopic: Byte): Boolean;
var
  idx: Integer;
  LClientList: TList;
begin
  case AState of
    SYIPCIntf.isConnect:
    begin
      LClientList := FClientList.LockList;
      try
        idx := LClientList.IndexOf(Pointer(ASenderID));
        if idx < 0 then
          LClientList.Add(Pointer(ASenderID));
      finally
        FClientList.UnlockList;
      end;
    end;
    isDisconnect:
    begin
      LClientList := FClientList.LockList;
      try
        idx := LClientList.IndexOf(Pointer(ASenderID));
        if idx >= 0 then
          LClientList.Delete(idx);
      finally
        FClientList.UnlockList;
      end;
    end;
  end;
  if AData <> nil then
    FLastClientID := ASenderID;
  Result := inherited DoHandleMessage(AState, ASenderID, AData, ADataType, ATopic)
end;

function TIPCServer.Send(const AClientID: Cardinal;
  const AData: WideString; const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(AClientID, PWideChar(AData), Length(AData) * IPC_CHAR_SIZE, mdtString, ATimeOut);
end;

function TIPCServer.Send(const AClientID: Cardinal; const AData: Int64; const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(AClientID, @AData, SizeOf(AData), mdtInteger, ATimeOut);
end;

function TIPCServer.Send(const AClientID: Cardinal; const AData: Double;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(AClientID, @AData, SizeOf(AData), mdtDouble, ATimeOut);
end;

function TIPCServer.SendC(const AClientID: Cardinal; const AData: Currency;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(AClientID, @AData, SizeOf(AData), mdtCurrency, ATimeOut);
end;

function TIPCServer.SendDT(const AClientID: Cardinal; const AData: TDateTime;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(AClientID, @AData, SizeOf(AData), mdtDateTime, ATimeOut);
end;

function TIPCServer.SendFile(const AClientID: Cardinal;
  const AFileName: WideString; ATimeOut: Cardinal): Boolean;
var
  LData: IIPCMessage;
begin
  LData := CreateIPCMessage;
  if not LData.LoadFromFile(AFileName) then
  begin
    Result := False;
    Exit;
  end;
  Result := Send(AClientID, LData, ATimeOut);
end;

function TIPCServer.Broadcast(const AData: WideString;
  const AExclude, ATimeOut: Cardinal): Boolean;
begin
  Result := DoBroadcast(PWideChar(AData), Length(AData) * IPC_CHAR_SIZE, mdtString, AExclude, ATimeOut);
end;

function TIPCServer.BroadcastFile(const AFileName: WideString;
  const AExclude, ATimeOut: Cardinal): Boolean;
var
  LData: IIPCMessage;
begin
  LData := CreateIPCMessage;
  if not LData.LoadFromFile(AFileName) then
  begin
    Result := False;
    Exit;
  end;
  Result := Broadcast(LData, AExclude, ATimeOut);
end;

function TIPCServer.GetClientCount: Integer;
var
  LClientList: TList;
begin
  LClientList := FClientList.LockList;
  try
    Result := LClientList.Count;
  finally
    FClientList.UnlockList;
  end;
end;

function TIPCServer.GetClientInfos: WideString;
var
  LClientList: TList;
  i: Integer;
begin
  LClientList := FClientList.LockList;
  try
    for i := 0 to LClientList.Count - 1 do
    begin
      if i < LClientList.Count - 1 then
        Result := WideFormat('{ clientID: %d }, ', [Cardinal(LClientList[i])])
      else
        Result := WideFormat('{ clientID: %d }', [Cardinal(LClientList[i])]);
    end;
    Result := '[ ' + Result + ' ]';
  finally
    FClientList.UnlockList;
  end;
end;

function TIPCServer.GetLastClientID: Cardinal;
begin
  Result := FLastClientID;
end;

function TIPCServer.DoBroadcast(const AData: Pointer;
  const ADataLen: Cardinal; const ADataType: TIPCMessageDataType;
  const AExclude, ATimeOut: Cardinal; const ATopic: Byte): Boolean;
var
  i: Integer;
  tick: Cardinal;
  LClientList: TList;
  LClients: array of Cardinal;
begin
  Result := False;
  LClientList := FClientList.LockList;
  try
    SetLength(LClients, LClientList.Count);
    for i := High(LClients) downto Low(LClients) do
      LClients[i] := Cardinal(LClientList[i]);
  finally
    FClientList.UnlockList;
  end;
  tick := GetTickCount;
  for i := Low(LClients) to High(LClients) do
  begin
    if GetTickCount - tick > ATimeOut then
      Exit;
    if (AExclude <> 0) and (LClients[i] = AExclude) then
      Continue;
    DoSend(LClients[i], AData, ADataLen, ADataType, ATimeOut, ATopic);
  end;
  Result := True;
end;

function TIPCServer.IsConnect(const AClientID: Cardinal): Boolean;
var
  LClientList: TList;
begin
  LClientList := FClientList.LockList;
  try
    Result := LClientList.IndexOf(Pointer(AClientID)) >= 0;
  finally
    FClientList.UnlockList;
  end;
  if Result then
  begin
    if not IsWindow(AClientID) then
    begin
      Result := False;
      DoRemoveClient(AClientID);
    end;
  end;
end;

procedure TIPCServer.DoRemoveClient(const AClient: Cardinal);
var
  LClientList: TList;
begin
  LClientList := FClientList.LockList;
  try
    if LClientList.Remove(Pointer(AClient)) >= 0 then
     DoHandleMessage(isDisconnect, AClient, nil, mdtUnknown);
  finally
    FClientList.UnlockList;
  end;
end;

procedure TIPCServer.DoBroadcastMessage(Msg: UINT;
  wParam: WPARAM; lParam: LPARAM);
var
  i: Integer;
  LClientList: TList;
  LClients: array of Cardinal;
begin
  LClientList := FClientList.LockList;
  try
    SetLength(LClients, LClientList.Count);
    for i := High(LClients) downto Low(LClients) do
      LClients[i] := Cardinal(LClientList[i]);
  finally
    FClientList.UnlockList;
  end;
  for i := Low(LClients) to High(LClients) do
    if IsWindow(LClients[i]) then
      PostMessage(LClients[i], Msg, wParam, lParam);
end;

function TIPCServer.Send(const AClientID: Cardinal; const AData: Boolean;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(AClientID, @AData, SizeOf(AData), mdtBoolean, ATimeOut);
end;

function TIPCServer.DoMessage(const ASelf: TIPCBase;
  const AState: TIPCState; const ASenderID: Cardinal;
  const AMessage: IIPCMessage): Boolean;
begin
  Result := inherited DoMessage(ASelf, AState, ASenderID, AMessage);
  if Result then
    Exit;
  try
     if @FOnMessage <> nil then
       FOnMessage(Self, AState, ASenderID, AMessage);
     Result := True;
  except
    on E: Exception do
    begin
      OutputDebugString(PChar('[TIPCServer.DoMessage]'+E.Message));
    end
  end;
end;

end.
