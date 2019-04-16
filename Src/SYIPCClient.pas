unit SYIPCClient;

interface

uses
  Windows, Messages, SysUtils, SYIPCCommon, SYIPCMessageLoop, SYIPCBase, SYIPCIntf;

const
  IPC_RETURN_MAXCOUNT = 255;
  
type
  TIPCClient = class(TIPCBase, IIPCClient)
  protected
    FServerID: Cardinal;
    FOnMessage: TIPCClientMessageEvent;
  protected
    function GetServerID: Cardinal;
    function GetOnMessage: TIPCClientMessageEvent;
    procedure SetActive(const Value: Boolean); override;
    procedure SetSessionName(const Value: WideString); override;
    procedure SetOnMessage(const Value: TIPCClientMessageEvent);
  protected
    procedure WndProc(var AMsg: TMessage); override;
    function DoMessage(const ASelf: TIPCBase; const AState: TIPCState;
      const ASenderID: Cardinal; const AMessage: IIPCMessage): Boolean; override;
  public
    function IsConnect: Boolean;
    function IsOpened: Boolean;
    
    function Open(const bFailIfServerNotExist: Boolean; const ATimeOut: Cardinal = IPC_TIMEOUT_OPENCLOSE): Boolean; overload;
    function Open(const ASessionName: WideString;const bFailIfServerNotExist: Boolean;
       const ATimeOut: Cardinal = IPC_TIMEOUT_OPENCLOSE): Boolean; overload;
    procedure Close; override;

    function MethodExist(const AMethodName: WideString): Boolean;
    function TryCall(const AMethodName: WideString; const AParams: array of OleVariant;
      out AResult: IIPCMessage; const ATimeOut: Cardinal): Boolean;
    function TryCallEx(const AMethodName: WideString; const AParams: array of IIPCMessage;
      out AResult: IIPCMessage; const ATimeOut: Cardinal): Boolean;
    function Call(const AMethodName: WideString; const AParams: array of OleVariant; const ATimeOut: Cardinal): IIPCMessage;
    function CallEx(const AMethodName: WideString; const AParams: array of IIPCMessage; const ATimeOut: Cardinal): IIPCMessage;

    function Send(const AData: IIPCMessage; const ATimeOut: Cardinal): Boolean; overload;
    function Send(const AData: Pointer; const ADataLen: Cardinal; const ATimeOut: Cardinal): Boolean; overload;
    function Send(const AData: WideString; const ATimeOut: Cardinal): Boolean; overload;
    function Send(const AData: Int64; const ATimeOut: Cardinal): Boolean; overload;
    function Send(const AData: Boolean; const ATimeOut: Cardinal): Boolean; overload;
    function Send(const AData: Double; const ATimeOut: Cardinal): Boolean; overload;
    function Send(const AData: TDateTime; const ATimeOut: Cardinal): Boolean; overload;
    function SendC(const AData: Currency; const ATimeOut: Cardinal): Boolean;
    function SendDT(const AData: TDateTime; const ATimeOut: Cardinal): Boolean;
    function SendFile(const AFileName: WideString; ATimeOut: Cardinal): Boolean;
  public
    property OnMessage: TIPCClientMessageEvent read GetOnMessage write SetOnMessage;
  end;
  
implementation

uses
  SYIPCUtilsImpl;

{ TIPCClient }

function TIPCClient.Open(const bFailIfServerNotExist: Boolean; const ATimeOut: Cardinal): Boolean;
var
  hServerID: HWND;
begin
  Result := False;
  if FActive or IsOpened then
  begin
    Result := True;
    Exit;
  end;
  FSessionHandle := MainThreadWindow.AllocSession(FSessionName);
  if FSessionHandle = 0 then
  begin
    FLastError := '无法注册['+FSessionName+']消息！';
    Exit;    
  end;
  hServerID := FindWindowW(IPCWindowClassName, PWideChar(GetIPCServerName(FSessionName, FSessionHandle)));
  if bFailIfServerNotExist then
  begin
    if (hServerID = 0) or (not IsWindow(hServerID)) then
    begin
      FLastError := '未找到['+FSessionName+']的IPC服务端！';
      Exit;   
    end;
  end;
  FID := FMessageLoop.AllocateThreadHWND(WndProc, GetIPCClientName(FSessionName, FSessionHandle));
  Assert(FID<>0);
  if FID = 0 then
  begin
    FLastError := '创建['+FSessionName+']会话的IPC客户端失败！';
    Exit;     
  end;
  Result := (SendMessageTimeout(hServerID, FConnectRequestHwnd, FSessionHandle, FID, ATimeOut) = 1)
    or (not bFailIfServerNotExist);
  DoHandleMessage(isAfterOpen, FID, nil);
end;

procedure TIPCClient.Close;
begin
  if (FID = 0) or (not IsWindow(FID)) then
    Exit;
  if (FServerID <> 0) and IsWindow(FServerID) then
    PostMessage(FServerID, FClientDisconnetHwnd, FSessionHandle, FID);
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

procedure TIPCClient.WndProc(var AMsg: TMessage);
begin
  if AMsg.WParamLo <> FSessionHandle then
  begin
    AMsg.Result := DefWindowProc(FID, AMsg.Msg, AMsg.WParam, AMsg.LParam);
    Exit;
  end;
  inherited WndProc(AMsg);
  if AMsg.Result = 1 then
    Exit;
  if AMsg.Msg = FConnectResposeHwnd then
  begin
    if (not FActive) or (not IsWindow(FServerID)) then
    begin
      FServerID := AMsg.lParam;
      DoHandleMessage(SYIPCIntf.isConnect, FServerID, nil);
      FActive := True;
      AMsg.Result := 1;
    end;
  end
  else
  if AMsg.Msg = FServerDisconnetHwnd then
  begin                                      
    if FActive then
    begin
      if AMsg.lParam = Longint(FServerID) then
      begin
        DoHandleMessage(isDisconnect, FServerID, nil);
        FServerID := 0;
        FActive := False;
        AMsg.Result := 1;
      end;
    end;
  end;
end;

function TIPCClient.Send(const AData: Pointer; const ADataLen, ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(FServerID, AData, ADataLen, mdtUnknown, ATimeOut);
end;

function TIPCClient.Send(const AData: IIPCMessage;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(FServerID, AData,  ATimeOut);
end;

procedure TIPCClient.SetActive(const Value: Boolean);
begin
  if FActive = Value then
    Exit;
  if Value then
    Open(True)
  else
    Close;
end;

procedure TIPCClient.SetSessionName(const Value: WideString);
begin
  if FSessionName = Value then
    Exit;
  Assert((not IsConnect) and (not IsOpened), 'IPC服务打开时不能修改SessionName！');
  inherited SetSessionName(Value);
end;

function TIPCClient.GetOnMessage: TIPCClientMessageEvent;
begin
  Result := FOnMessage;
end;

procedure TIPCClient.SetOnMessage(const Value: TIPCClientMessageEvent);
begin
  FOnMessage := Value;
end;

function TIPCClient.Send(const AData: WideString;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(FServerID, PWideChar(AData), Length(AData) * IPC_CHAR_SIZE, mdtString, ATimeOut);
end;

function TIPCClient.Send(const AData: Double;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(FServerID, @AData, SizeOf(AData), mdtDouble, ATimeOut);
end;

function TIPCClient.Send(const AData: Int64; const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(FServerID, @AData, SizeOf(AData), mdtInteger, ATimeOut);
end;

function TIPCClient.Send(const AData: TDateTime;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(FServerID,@AData, SizeOf(AData), mdtDateTime, ATimeOut);
end;

function TIPCClient.SendC(const AData: Currency;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(FServerID,@AData, SizeOf(AData), mdtCurrency, ATimeOut);
end;

function TIPCClient.SendDT(const AData: TDateTime;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(FServerID,@AData, SizeOf(AData), mdtDateTime, ATimeOut);
end;

function TIPCClient.SendFile(const AFileName: WideString;
  ATimeOut: Cardinal): Boolean;
var
  LData: IIPCMessage;
begin
  LData := CreateIPCMessage;
  if not LData.LoadFromFile(AFileName) then
  begin
    Result := False;
    Exit;
  end;
  Result := Send(LData, ATimeOut);
end;

function TIPCClient.Open(const ASessionName: WideString; const bFailIfServerNotExist: Boolean;
  const ATimeOut: Cardinal): Boolean;
begin
  Assert(ASessionName <> '');
  if (FSessionName <> '') and (ASessionName <> FSessionName) and FActive then
    Close;
  if FActive then
  begin
    Result := False;
    Exit;
  end;
  SessionName := ASessionName;
  Result := Open(bFailIfServerNotExist);
end;

function TIPCClient.GetServerID: Cardinal;
begin
  Result := FServerID;
end;

function TIPCClient.IsConnect: Boolean;
begin
  Result := FActive and (FServerID <> 0) and IsWindow(FServerID);
end;

function TIPCClient.IsOpened: Boolean;
begin
  Result := (FID <> 0) and IsWindow(FID)
end;

function TIPCClient.Send(const AData: Boolean;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(FServerID, @AData, SizeOf(AData), mdtBoolean, ATimeOut);
end;

function TIPCClient.CallEx(const AMethodName: WideString;
  const AParams: array of IIPCMessage; const ATimeOut: Cardinal): IIPCMessage;
begin
  Result := inherited CallEx(FServerID, AMethodName, AParams, ATimeOut)
end;

function TIPCClient.Call(const AMethodName: WideString;
  const AParams: array of OleVariant; const ATimeOut: Cardinal): IIPCMessage;
begin
  Result := inherited Call(FServerID, AMethodName, AParams, ATimeOut)
end;

function TIPCClient.DoMessage(const ASelf: TIPCBase;
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
      OutputDebugString(PChar('[TIPCClient.DoMessage]'+E.Message));
    end
  end;
end;

function TIPCClient.TryCall(const AMethodName: WideString;
  const AParams: array of OleVariant; out AResult: IIPCMessage;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := inherited TryCall(FServerID, AMethodName, AParams, AResult, ATimeOut)
end;

function TIPCClient.TryCallEx(const AMethodName: WideString;
  const AParams: array of IIPCMessage; out AResult: IIPCMessage;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := inherited TryCallEx(FServerID, AMethodName, AParams, AResult, ATimeOut)
end;

function TIPCClient.MethodExist(const AMethodName: WideString): Boolean;
begin
  Result := inherited MethodExist(FServerID, AMethodName);
end;

end.
