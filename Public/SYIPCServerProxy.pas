unit SYIPCServerProxy;

interface

uses
  SysUtils, SYIPCIntf;

type
  TIPCServerProxy = class(TInterfacedObject)
  private
    FClient: IIPCClient;
    FSessionName: WideString;
    function GetClient: IIPCClient; virtual;
    function GetSessionName: WideString;
    function GetActive: Boolean;
    function GetID: Cardinal;
    function GetReciveQueue: PIIPCMessageQueue;
    function GetOnMessage: TIPCClientMessageEvent;
    function GetReciveMessageToQueue: Boolean;
    function GetReciveMessageInThread: Boolean;
    function GetServerID: Cardinal;
    function GetSessionHandle: THandle;
    function GetLastError: WideString;
    procedure SetSessionName(const Value: WideString);
    procedure SetActive(const Value: Boolean);
    procedure SetOnMessage(const Value: TIPCClientMessageEvent);
    procedure SetReciveMessageToQueue(const Value: Boolean);
    procedure SetReciveMessageInThread(const Value: Boolean);
  public
    constructor Create(const ASessionName: WideString); 
  
    function IsExist: Boolean;
    function IsConnect: Boolean;
    function IsOpened: Boolean;

    function Open(const bFailIfServerNotExist: Boolean = True;
      const ATimeOut: Cardinal = IPC_TIMEOUT_OPENCLOSE): Boolean; overload;
    function Open(const ASessionName: WideString;  const bFailIfServerNotExist: Boolean = True;
      const ATimeOut: Cardinal = IPC_TIMEOUT_OPENCLOSE): Boolean; overload;
    procedure Close;

    function Send(const AData: IIPCMessage; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AData: Pointer; const ADataLen: Cardinal; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AData: WideString; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AData: Integer; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AData: Boolean; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function Send(const AData: Double; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean; overload;
    function SendC(const AData: Currency; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean;
    function SendDT(const AData: TDateTime; const ATimeOut: Cardinal = IPC_TIMEOUT): Boolean;
    function SendFile(const AFileName: WideString; ATimeOut: Cardinal = IPC_TIMEOUT): Boolean;

    function  MethodExist(const AMethodName: WideString): Boolean;
    procedure Bind(const ARttiObject: TObject; const AOwnObject: Boolean = True);

    property ID: Cardinal read GetID;
    property SessionName: WideString read GetSessionName write SetSessionName;
    property SessionHandle: THandle read GetSessionHandle;
    property Active: Boolean read GetActive write SetActive;
    property ReciveMessageInThread: Boolean read GetReciveMessageInThread write SetReciveMessageInThread;
    property ReciveMessageToQueue: Boolean read GetReciveMessageToQueue write SetReciveMessageToQueue;
    property ServerID: Cardinal read GetServerID;
    property ReciveQueue: PIIPCMessageQueue read GetReciveQueue;
    property OnMessage: TIPCClientMessageEvent read GetOnMessage write SetOnMessage;
    property Client: IIPCClient read GetClient;
    property LastError: WideString read GetLastError;
  end;

implementation

uses
  ObjComAuto;

{ TIPCServerProxy }

procedure TIPCServerProxy.Close;
begin
  if FClient = nil then
    Exit;
  Client.Close;
end;

constructor TIPCServerProxy.Create(const ASessionName: WideString);
begin
  FSessionName := ASessionName;
end;

procedure TIPCServerProxy.Bind(const ARttiObject: TObject;
  const AOwnObject: Boolean);
begin
  Client.Dispatch := TObjectDispatch.Create(ARttiObject, AOwnObject);
end;

function TIPCServerProxy.GetActive: Boolean;
begin
  Result := Client.Active;
end;

function TIPCServerProxy.GetClient: IIPCClient;
begin
  if FClient = nil then
  begin
    Assert(FSessionName <> '');
    FClient := CreateIPCClient(FSessionName);
  end;
  Result := FClient;
end;

function TIPCServerProxy.GetID: Cardinal;
begin
  Result := Client.ID;
end;

function TIPCServerProxy.GetLastError: WideString;
begin
  Result := Client.LastError;
end;

function TIPCServerProxy.GetReciveQueue: PIIPCMessageQueue;
begin
  Result := Client.ReciveQueue;
end;

function TIPCServerProxy.GetOnMessage: TIPCClientMessageEvent;
begin
  Result := Client.OnMessage;
end;

function TIPCServerProxy.GetReciveMessageToQueue: Boolean;
begin
  Result := Client.ReciveMessageToQueue;
end;

function TIPCServerProxy.GetReciveMessageInThread: Boolean;
begin
  Result := Client.ReciveMessageInThread;
end;

function TIPCServerProxy.GetServerID: Cardinal;
begin
  Result := Client.ServerID;
end;

function TIPCServerProxy.GetSessionHandle: THandle;
begin
  Result := Client.SessionHandle;
end;

function TIPCServerProxy.GetSessionName: WideString;
begin
  Result := Client.SessionName;
end;

function TIPCServerProxy.IsConnect: Boolean;
begin
  Result := Client.IsConnect;
end;

function TIPCServerProxy.IsExist: Boolean;
begin
  Result := Client.IsExist(Client.SessionName)
end;

function TIPCServerProxy.IsOpened: Boolean;
begin
  Result := Client.IsOpened;
end;

function TIPCServerProxy.MethodExist(
  const AMethodName: WideString): Boolean;
begin
  Result := Client.MethodExist(AMethodName)
end;

function TIPCServerProxy.Open(const bFailIfServerNotExist: Boolean;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := Client.Open(bFailIfServerNotExist, ATimeOut)
end;

function TIPCServerProxy.Open(const ASessionName: WideString;
  const bFailIfServerNotExist: Boolean; const ATimeOut: Cardinal): Boolean;
begin
  Result := Client.Open(ASessionName, bFailIfServerNotExist, ATimeOut)
end;

procedure TIPCServerProxy.SetActive(const Value: Boolean);
begin
  Client.Active := Value;
end;

procedure TIPCServerProxy.SetOnMessage(
  const Value: TIPCClientMessageEvent);
begin
  Client.OnMessage := Value;
end;

procedure TIPCServerProxy.SetReciveMessageToQueue(const Value: Boolean);
begin
  Client.ReciveMessageToQueue := Value;
end;

procedure TIPCServerProxy.SetReciveMessageInThread(const Value: Boolean);
begin
  Client.ReciveMessageInThread := Value;
end;

procedure TIPCServerProxy.SetSessionName(const Value: WideString);
begin
  Client.SessionName := Value;
end;

function TIPCServerProxy.Send(const AData: WideString;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := Client.Send(AData, ATimeOut)
end;

function TIPCServerProxy.Send(const AData: Integer;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := Client.Send(AData, ATimeOut)
end;

function TIPCServerProxy.Send(const AData: IIPCMessage;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := Client.Send(AData,ATimeOut)
end;

function TIPCServerProxy.Send(const AData: Pointer; const ADataLen,
  ATimeOut: Cardinal): Boolean;
begin
  Result := Client.Send(AData, ADataLen, ATimeOut)
end;

function TIPCServerProxy.Send(const AData: Double;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := Client.Send(AData, ATimeOut)  
end;

function TIPCServerProxy.Send(const AData: Boolean;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := Client.Send(AData, ATimeOut)
end;

function TIPCServerProxy.SendC(const AData: Currency;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := Client.SendC(AData, ATimeOut)
end;

function TIPCServerProxy.SendDT(const AData: TDateTime;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := Client.SendDT(AData, ATimeOut)
end;

function TIPCServerProxy.SendFile(const AFileName: WideString;
  ATimeOut: Cardinal): Boolean;
begin
  Result := Client.SendFile(AFileName, ATimeOut)
end;

end.
