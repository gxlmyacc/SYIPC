unit SYIPCBase;

interface

uses
  Windows, SysUtils, Messages, Variants, SYIPCCommon,
  SYIPCMessageQueue, SYIPCMessageLoop, SYIPCIntf;

type
  TIPCReturnQueue = array[0..254] of IIPCMessage;
  
  TIPCBase = class(TInterfacedObject)
  protected
    FDestroying: Boolean;
    FID: Cardinal;
    FActive: Boolean;
    FReciveMessageInThread: Boolean;
    FReciveMessageToQueue: Boolean;
    FSessionName: WideString;
    FSessionHandle: LongInt;
    FMessageLoop: TMessageLoopThread;
    FReturnQueue: TIPCReturnQueue;
    FReturnQueueLock: TRTLCriticalSection;
    FReciveQueue: IIPCMessageQueue;
    FServerDisconnetHwnd: Longword;
    FClientDisconnetHwnd: LongWord;
    FConnectRequestHwnd: Longword;
    FConnectResposeHwnd: Longword;
    FDispatch: IDispatch;
    FTag: Pointer;
    FLastError: WideString;
    function GetActive: Boolean;
    function GetReciveMessageInThread: Boolean;
    function GetReciveMessageToQueue: Boolean;
    function GetSessionName: WideString;
    function GetSessionHandle: Cardinal;
    function GetID: Cardinal;
    function GetReciveQueue: PIIPCMessageQueue;
    function GetDispatch: IDispatch;
    function GetTag: Pointer;
    function GetLastError: WideString;
    procedure SetActive(const Value: Boolean); virtual; abstract;
    procedure SetReciveMessageInThread(const Value: Boolean);
    procedure SetReciveMessageToQueue(const Value: Boolean);
    procedure SetSessionName(const Value: WideString); virtual;
    procedure SetDispatch(const Value: IDispatch);
    procedure SetTag(const Value: Pointer);
  protected
    procedure WndProc(var AMsg: TMessage); virtual;
    function DoHandleMessage(const AState: TIPCState; const ASenderID: Cardinal; const AData: PCopyDataStruct;
      const ADataType: TIPCMessageDataType = mdtUnknown; const ATopic: Byte = 0): Boolean; virtual;
    function DoMessage(const ASelf: TIPCBase; const AState: TIPCState;
      const ASenderID: Cardinal; const AMessage: IIPCMessage): Boolean; virtual;
    function DoSend(ASendID: Cardinal; const AData: Pointer;
      const ADataLen: Cardinal; const ADataType: TIPCMessageDataType;
      const ATimeOut: Cardinal; const ATopic: Byte = 0): Boolean; overload;
    function DoSend(ASendID: Cardinal; const AData: IIPCMessage; const ATimeOut: Cardinal): Boolean; overload;
      
    function  DoAllocateReturnTopic: Byte;
    procedure DoSetReturnTopic(const ATopic: Byte; const AMessage: IIPCMessage);
    function  DoDeallocateReturnTopic(const ATopic: Byte): IIPCMessage;
    procedure DoClearReturnTopics;

    function MethodExist(const ASendID: Cardinal;const AMethodName: WideString): Boolean;
    function TryCall(const ASendID: Cardinal;const AMethodName: WideString;
      const AParams: array of OleVariant;
      out AResult: IIPCMessage; const ATimeOut: Cardinal): Boolean;
    function TryCallEx(const ASendID: Cardinal;const AMethodName: WideString;
      const AParams: array of IIPCMessage;
      out AResult: IIPCMessage; const ATimeOut: Cardinal): Boolean;
    function Call(const ASendID: Cardinal;const AMethodName: WideString;
      const AParams: array of OleVariant; const ATimeOut: Cardinal): IIPCMessage;
    function CallEx(const ASendID: Cardinal;const AMethodName: WideString;
      const AParams: array of IIPCMessage; const ATimeOut: Cardinal): IIPCMessage;

    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    constructor Create; virtual;
    procedure BeforeDestruction; override;
    destructor Destroy; override;
    
    function Implementor: Pointer;
    function IsExist(const ASessionName: WideString): Boolean;

    procedure Close; virtual; abstract;
  public
    property SessionName: WideString read GetSessionName write SetSessionName;
    property SessionHandle: Cardinal read GetSessionHandle;
    property Active: Boolean read GetActive write SetActive;
    property ReciveMessageInThread: Boolean read GetReciveMessageInThread write SetReciveMessageInThread;
    property ReciveMessageToQueue: Boolean read GetReciveMessageToQueue write SetReciveMessageToQueue;
    property ID: Cardinal read GetID;
    property ReciveQueue: PIIPCMessageQueue read GetReciveQueue;
    property Tag: Pointer read GetTag write SetTag;
    {$WARNINGS OFF}
    property Dispatch: IDispatch read GetDispatch write SetDispatch;
    {$WARNINGS ON}
    property LastError: WideString read GetLastError;
  end;

implementation

uses
  SYIPCMessage, SYIPCUtilsImpl;

{ TIPCBase }

function TIPCBase._AddRef: Integer;
begin
  if FDestroying then
    Result := FRefCount
  else
    Result := inherited _AddRef;
end;

function TIPCBase._Release: Integer;
begin
  if FDestroying then
    Result := FRefCount
  else
    Result := inherited _Release;
end;

constructor TIPCBase.Create;
begin
  FID := 0;
  FSessionHandle := 0;
  FReciveMessageInThread := False;
  FReciveQueue := TIPCMessageQueue.Create;
  InitializeCriticalSection(FReturnQueueLock);
  FConnectRequestHwnd  := RegisterWindowMessage(IPCConnectRequest);
  FConnectResposeHwnd  := RegisterWindowMessage(IPCConnectRespose);
  FServerDisconnetHwnd := RegisterWindowMessage(IPCServerDisconneting);
  FClientDisconnetHwnd := RegisterWindowMessage(IPCClientDisconneting);
  AllowMeesageForVistaAbove(FConnectRequestHwnd, True);
  AllowMeesageForVistaAbove(FConnectResposeHwnd, True);
  AllowMeesageForVistaAbove(FServerDisconnetHwnd, True);
  AllowMeesageForVistaAbove(FClientDisconnetHwnd, True);
  FMessageLoop := MainThreadWindow.CreateMessageLoop(False, Self);
end;

destructor TIPCBase.Destroy;
begin
  Close;
  DoClearReturnTopics;
  DeleteCriticalSection(FReturnQueueLock);
  FReciveQueue := nil;
  if FMessageLoop <> nil then
    MainThreadWindow.FreeMessageLoop(FMessageLoop);
  inherited Destroy;
end;

function TIPCBase.DoHandleMessage(const AState: TIPCState;
  const ASenderID: Cardinal; const AData: PCopyDataStruct;
  const ADataType: TIPCMessageDataType; const ATopic: Byte): Boolean;
var
  LMessageStruct: TIPCMessageStruct;
  LMessage: IIPCMessage;
begin
  Result := False;
  if AData <> nil then
  begin
    LMessage := TIPCMessage.CreateReadOnly(Self, AData.lpData, AData.cbData, ADataType, ATopic);
    LMessage.SenderID := ASenderID;
    if FReciveMessageToQueue then
    begin
      FReciveQueue.Push(LMessage.Clone);
      Exit;
    end;
  end;
  if FReciveMessageInThread or (MainThreadID = GetCurrentThreadId) then
    Result := DoMessage(Self, AState, ASenderID, LMessage)
  else
  begin
    LMessageStruct.Sender   := Self;
    LMessageStruct.State    := AState;
    LMessageStruct.SenderID := ASenderID;
    LMessageStruct.Message  := LMessage;
    MainThreadWindow.DoIPCMessage(Self, @LMessageStruct);
  end;
end;

function TIPCBase.DoMessage(const ASelf: TIPCBase; 
  const AState: TIPCState; const ASenderID: Cardinal;
  const AMessage: IIPCMessage): Boolean;
var
  LResultMessage, LReturnMessage, LMessage: IIPCMessage;
  LArgs: array of OleVariant;
  LReturn: TSYIPCCallReturn;
  LPReturn: PSYIPCCallReturn;
  i, iArgCount: Integer;
  LMethod: PSYIPCCallMethod;
  LParam: PSYIPCData;
  LData: TMessageData;
  oResult: OleVariant;
  sMethodName: WideString;
begin
  Result := False;
  try
    if (AState <> isReceiveData) or (AMessage = nil) then
      Exit;
    if AMessage.DataType = mdtCall then
    begin
      Result := True;
      LData := AMessage.Data;
      LMethod := PSYIPCCallMethod(LData);
      LData := LData + SizeOf(TSYIPCCallMethod);
      LResultMessage := CreateIPCMessage;
      try
        try
          if FDispatch = nil then
          begin
            LResultMessage.Add('IPC服务端未注册Dispatch属性！');
            LResultMessage.DataType := mdtError;
          end
          else
          begin
            sMethodName := LMethod.MethodName; 
            if sMethodName = IPCMethod_MethodExist then
            begin
              LParam := PSYIPCData(LData);
              LData := LData + SizeOf(TSYIPCData);
              LMessage := CreateIPCMessageReadOnly(LData, LParam.Size, LParam.Type_);
              LResultMessage.B := _DispatchMethodExist(FDispatch, LMessage.S)
            end
            else
            begin
              iArgCount := LMethod.Params.Length;
              SetLength(LArgs, iArgCount);
              for i := 0 to iArgCount - 1 do
              begin
                LParam := PSYIPCData(LData);
                LData := LData + SizeOf(TSYIPCData);
                LMessage := CreateIPCMessageReadOnly(LData, LParam.Size, LParam.Type_);
                LArgs[i] := M2V(LMessage);
                if TVarData(LArgs[i]).VType = varError then
                begin
                  LResultMessage.Add(Format('不支持的类型[%d]！', [LParam.Type_]));
                  LResultMessage.DataType := mdtError;
                end;
              end;
              oResult := _DispatchInvoke(FDispatch, PWideChar(sMethodName), LArgs);
              LResultMessage := V2M(oResult);
            end;
          end;
        except
          on E: Exception do
          begin
            LResultMessage.Add(E.Message);
            LResultMessage.DataType := mdtError;
          end;
        end;             
      finally
        LReturnMessage          := CreateIPCMessage;
        LReturnMessage.DataType := mdtCallReturn;
        LReturn.ResTopic        := LMethod.ResTopic;
        LReturn.Data.Size       := LResultMessage.DataSize;
        LReturn.Data.Type_      := LResultMessage.DataType;
        LReturnMessage.Add(@LReturn, SizeOf(TSYIPCCallReturn));
        LReturnMessage.Add(LResultMessage.Data, LResultMessage.DataSize);
        DoSend(ASenderID, LReturnMessage.Data, LReturnMessage.DataSize, LReturnMessage.DataType, IPC_TIMEOUT);
      end;
    end
    else
    if AMessage.DataType = mdtCallReturn then
    begin
      Result := True;
      LData := AMessage.Data;
      LPReturn := PSYIPCCallReturn(LData);
      LData := LData + SizeOf(TSYIPCCallReturn);
      LMessage := CreateIPCMessage;
      LMessage.SetData(LData, LPReturn.Data.Size, LPReturn.Data.Type_);
      DoSetReturnTopic(AMessage.Topic, LMessage);
    end;
  except
    on E: Exception do
    begin
      OutputDebugString(PChar('[TIPCBase.DoMessage]'+E.Message));
    end
  end;
end;

function TIPCBase.DoSend(ASendID: Cardinal; const AData: Pointer;
  const ADataLen: Cardinal; const ADataType: TIPCMessageDataType;
  const ATimeOut: Cardinal; const ATopic: Byte): Boolean;
begin
  Result := __SendIPCMessageP(FID, ASendID, FSessionHandle, AData, ADataLen, ADataType, ATimeOut, ATopic) <> 0;
end;

function TIPCBase.GetActive: Boolean;
begin
  Result := FActive;
end;

function TIPCBase.GetDispatch: IDispatch;
begin
  Result := FDispatch;
end;

function TIPCBase.GetLastError: WideString;
begin
  Result := FLastError;
end;

function TIPCBase.GetReciveQueue: PIIPCMessageQueue;
begin
  Result := @FReciveQueue;
end;

function TIPCBase.GetReciveMessageToQueue: Boolean;
begin
  Result := FReciveMessageToQueue;
end;

function TIPCBase.GetReciveMessageInThread: Boolean;
begin
  Result := FReciveMessageInThread;
end;

function TIPCBase.GetID: Cardinal;
begin
  Result := FID;
end;

function TIPCBase.GetSessionHandle: Cardinal;
begin
  Result := FSessionHandle;
end;

function TIPCBase.GetSessionName: WideString;
begin
  Result := FSessionName;
end;

function TIPCBase.GetTag: Pointer;
begin
  Result := FTag;
end;

function TIPCBase.Implementor: Pointer;
begin
  Result := Self;
end;

procedure TIPCBase.SetDispatch(const Value: IDispatch);
begin
  FDispatch := Value;
end;

procedure TIPCBase.SetReciveMessageToQueue(const Value: Boolean);
begin
  FReciveMessageToQueue := Value;
end;

procedure TIPCBase.SetReciveMessageInThread(const Value: Boolean);
begin
  FReciveMessageInThread := Value;
end;

procedure TIPCBase.SetSessionName(const Value: WideString);
begin
  if FSessionName = Value then
    Exit;
  Assert(not FActive, 'IPC服务打开时不能修改SessionName！');
  if Length(Value) > IPC_SESSIONNAME_SIZE then
    raise ESYIPCExection.CreateFmt('SessionName不能超过%d个字符！', [IPC_SESSIONNAME_SIZE]);
  FSessionName := Value;
end;

procedure TIPCBase.SetTag(const Value: Pointer);
begin
  FTag := Value;
end;

procedure TIPCBase.WndProc(var AMsg: TMessage);
var
  LByteMsg: array[0..11] of Byte absolute AMsg;
begin
  if AMsg.Msg = WM_COPYDATA then
  begin
    DoHandleMessage(isReceiveData,
      PCopyDataStruct(AMsg.lParam).dwData,
      PCopyDataStruct(AMsg.lParam),
      TIPCMessageDataType(LByteMsg[6]), LByteMsg[7]);
    AMsg.Result := 1;
  end;
end;

function TIPCBase.DoAllocateReturnTopic: Byte;
begin
  EnterCriticalSection(FReturnQueueLock);
  try
    for Result := Low(FReturnQueue) to High(FReturnQueue) do
    begin
      if FReturnQueue[Result] = nil then
        Exit;
    end;
    Result := 0;
    raise ESYIPCExection.Create('当前返回队列已满！');
  finally
    LeaveCriticalSection(FReturnQueueLock);
  end;   
end;

function TIPCBase.DoDeallocateReturnTopic(const ATopic: Byte): IIPCMessage;
begin
  EnterCriticalSection(FReturnQueueLock);
  try
    Result := FReturnQueue[ATopic];
    FReturnQueue[ATopic] := nil;
  finally
    LeaveCriticalSection(FReturnQueueLock);
  end;   
end;

procedure TIPCBase.DoSetReturnTopic(const ATopic: Byte;
  const AMessage: IIPCMessage);
begin
  EnterCriticalSection(FReturnQueueLock);
  try
    FReturnQueue[ATopic] := AMessage;
  finally
    LeaveCriticalSection(FReturnQueueLock);
  end;   
end;

procedure TIPCBase.BeforeDestruction;
begin
  inherited;
  FDestroying := True;
end;

procedure TIPCBase.DoClearReturnTopics;
var
  i: Integer;
begin
  EnterCriticalSection(FReturnQueueLock);
  try
    for i := Low(FReturnQueue) to High(FReturnQueue) do
      FReturnQueue[i] := nil;
  finally
    LeaveCriticalSection(FReturnQueueLock);
  end;
end;

function TIPCBase.IsExist(const ASessionName: WideString): Boolean;
var
  hServerID: Cardinal;
begin
  hServerID := FindWindowW(IPCWindowClassName, PWideChar(GetIPCServerName(FSessionName, FSessionHandle)));
  Result := (hServerID <> 0) and IsWindow(hServerID);
end;

function TIPCBase.Call(const ASendID: Cardinal;
  const AMethodName: WideString; const AParams: array of OleVariant;
  const ATimeOut: Cardinal): IIPCMessage;
begin
  if not TryCall(ASendID, AMethodName, AParams, Result, ATimeOut) then
    raise ESYIPCExection.Create(FLastError);
end;

function TIPCBase.CallEx(const ASendID: Cardinal;
  const AMethodName: WideString; const AParams: array of IIPCMessage;
  const ATimeOut: Cardinal): IIPCMessage;
begin
  if not TryCallEx(ASendID, AMethodName, AParams, Result, ATimeOut) then
    raise ESYIPCExection.Create(FLastError);
end;

function TIPCBase.MethodExist(const ASendID: Cardinal;
  const AMethodName: WideString): Boolean;
var
  LParam, LResult: IIPCMessage;
begin
  Result := False;
  if AMethodName = '' then
    Exit;
  LParam := CreateIPCMessage;
  LParam.S := AMethodName;
  if not TryCallEx(ASendID, IPCMethod_MethodExist, [LParam], LResult, IPC_TIMEOUT) then
    Exit;
  Result := (LResult <> nil) and LResult.B;
end;

function TIPCBase.TryCall(const ASendID: Cardinal;
  const AMethodName: WideString; const AParams: array of OleVariant;
  out AResult: IIPCMessage; const ATimeOut: Cardinal): Boolean;
var
  LParams: array of IIPCMessage;
  i: Integer;
begin
  SetLength(LParams, Length(AParams));
  for i := Low(AParams) to High(AParams) do
  begin
    LParams[i] := V2M(AParams[i]);
    if LParams[i].DataType = mdtError then
    begin
      FLastError := LParams[i].S;
      Result := False;
      Exit;
    end;
  end;
  Result := TryCallEx(ASendID, AMethodName, LParams, AResult, ATimeOut);
end;

function TIPCBase.TryCallEx(const ASendID: Cardinal;
  const AMethodName: WideString; const AParams: array of IIPCMessage;
  out AResult: IIPCMessage; const ATimeOut: Cardinal): Boolean;
var
  bResTopic: Byte;
  LMethod: TSYIPCCallMethod;
  LData: TSYIPCData;
  LSendMessage: IIPCMessage;
  i: Integer;
  LParam: IIPCMessage;
begin
  Assert(not FDestroying, 'IPC客户端正在销毁！');
  Result := False;
  if AMethodName = '' then
  begin
    FLastError := '方法名不能为空！';
    Exit;
  end;
  if Length(AMethodName) > IPC_CALLMETHOD_SIZE then
  begin
    FLastError :=  Format('方法名称长度不能超过[%d]个字符！', [IPC_CALLMETHOD_SIZE]);
    Exit;
  end;
  bResTopic := DoAllocateReturnTopic;
  LMethod.ResTopic := bResTopic;
  ZeroMemory(@LMethod.MethodName[0], (IPC_CALLMETHOD_SIZE+1) *  IPC_CHAR_SIZE);
  CopyMemory(@LMethod.MethodName[0], PWideChar(AMethodName), Length(AMethodName)*IPC_CHAR_SIZE);
  LMethod.Params.Length := Length(AParams);
  LSendMessage := CreateIPCMessage;
  LSendMessage.Add(@LMethod, SizeOf(LMethod), mdtCall);
  for i := Low(AParams) to High(AParams) do
  begin
    LParam := AParams[i];
    LData.Size  := LParam.DataSize;
    LData.Type_ := LParam.DataType;
    LSendMessage.Add(@LData, SizeOf(LData));
    LSendMessage.Add(LParam.Data, LData.Size);
  end;
  if not DoSend(ASendID, LSendMessage, ATimeOut) then
  begin
    FLastError :=  Format('[%s]接收端发送数据失败：%s。', [FSessionName, FLastError]);
    Exit;  
  end;
  AResult := DoDeallocateReturnTopic(bResTopic);
  if AResult = nil then
  begin
    FLastError :=  Format('[%s]接收端未响应[%s]方法！', [FSessionName, AMethodName]);
    Exit;    
  end
  else
  if AResult.DataType = mdtError then
  begin
    FLastError :=  AResult.S;
    Exit;
  end
  else
  if AResult.DataSize <= 0 then
    AResult := nil;
  Result := True;
end;

function TIPCBase.DoSend(ASendID: Cardinal; const AData: IIPCMessage;
  const ATimeOut: Cardinal): Boolean;
begin
  Result := DoSend(ASendID, AData.Data, AData.DataSize, AData.DataType, ATimeOut, AData.Topic)
end;

end.
