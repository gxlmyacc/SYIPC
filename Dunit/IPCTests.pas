unit IPCTests;

interface

uses
  Windows,
  SysUtils,
  Classes,
  SYIPCIntf,
  SYIPCUtils,
  TestFrameWork,
  Math,
  Forms;

type
  {$METHODINFO ON}
  TIPCServerTest = class
  public
    function ShowMessage(const AMsg: WideString): Boolean;
    function ShowMessage1(const AMsg: IIPCMessage): IIPCMessage;
  end;
  TIPCClientTest = class
  public
    function ShowMessage(const AMsg: WideString): Boolean;
  end;
  {$METHODINFO OFF}



  TIPCTest = class(TTestCase)
  private
    FLastMessage: IIPCMessage;
    FMainThreadHang: Boolean;
    FServer: IIPCServer;
    FClient: IIPCClient;
    FTag: WideString;
  protected
    procedure DoServerMessage1(const AServer: IIPCServer; const AState: TIPCState;
      const ASenderID: Cardinal; const AMessage: IIPCMessage);
    procedure DoClientMessage1(const AClient: IIPCClient; const AState: TIPCState;
      const ASenderID: Cardinal; const AMessage: IIPCMessage);
    procedure DoServerMessage2(const AServer: IIPCServer; const AState: TIPCState;
      const ASenderID: Cardinal; const AMessage: IIPCMessage);
    procedure DoClientMessage2(const AClient: IIPCClient; const AState: TIPCState;
      const ASenderID: Cardinal; const AMessage: IIPCMessage);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    //基础测试
    procedure TestBase;
    //基础消息队列
    procedure TestMessageQueue;
    //SessionHandle测试
    procedure SessionHandleTest;
    //测试多个客户端
    procedure TestMultiClient;
    //测试多个服务端和客户端
    procedure TestMultiServerAndClient;
    //测试Send数据性能
    procedure TestSendPerformance;
    //测试线程内发消息
    //procedure TestThreadMessage1;
    procedure TestThreadMessage2;
    procedure TestThreadMessage3;
    //测试查找方法
    procedure TestFindMethods;
  end;

implementation

uses
  ObjComAuto;

var
  TestThreadMessageResult: Boolean;
  bIPCServerTestCalled: Boolean;
  bIPCClientTestCalled: Boolean;
  
procedure _TestThreadMessageProc(ATest: TIPCTest);
var
  LServer: IIPCServer;
  LClient: IIPCClient;
  sMsg, sClientInfos: WideString;
  ms1, ms2: TMemoryStream;
  LMessage: IIPCMessage;
begin
  with ATest do
  begin
    if FServer = nil then
      LServer := CreateIPCServer
    else
      LServer := FServer;
    if FClient = nil then
      LClient := CreateIPCClient
    else
      LClient := FClient;
    try
      LServer.SessionName := 'Test';
      LClient.SessionName := 'Test';
      LServer.OnMessage := ATest.DoServerMessage1;
      LClient.OnMessage := ATest.DoClientMessage1;
      if FMainThreadHang then
      begin
        LServer.ReciveMessageInThread := True;  //因为主线程挂起了，所以只能在线程里处理接收数据
        LClient.ReciveMessageInThread := True;  //因为主线程挂起了，所以只能在线程里处理接收数据
      end;

      FTag := '1';
      if not LServer.Open then
      begin
        FTag := '[1]'+LServer.LastError;
        Exit;
      end;
      FTag := '2';
      if not LClient.Open then Exit;
      FTag := '3';
      if LServer.ID = 0 then Exit;
      FTag := '4';
      if LClient.ID = 0 then Exit;
      FTag := '5';
      if not LServer.IsConnect(LClient.ID) then Exit;

      sClientInfos := LServer.ClientInfos;
      FTag := '6';
      if sClientInfos <> ('[ { clientID: ' + IntToStr(LClient.ID) + ' } ]') then Exit;

      sMsg := 'Hello 你好';
      FTag := '7';
      if not LClient.Send(sMsg) then Exit;
      FTag := '8';
      if LServer.LastClientID <> LClient.ID then Exit;
      FTag := '9';
      if FLastMessage = nil then Exit;
      FTag := '10';
      if FLastMessage.S <> sMsg then Exit;
      FTag := '11';
      if FLastMessage.SenderID <>  LClient.ID then Exit;
      FTag := '12';
      LServer.Send(LServer.LastClientID, '你好，我是服务端');
      FTag := '13';
      if FLastMessage = nil then Exit;
      FTag := '14';
      if FLastMessage.S <> '你好，我是服务端' then Exit;
      FTag := '15';
      if FLastMessage.SenderID <> LServer.ID then Exit;

      FTag := '16';
      if not LServer.Send(LServer.LastClientID, 1) then Exit;
      FTag := '17';
      if Integer(FLastMessage.DataType) <> Integer(mdtInteger) then Exit;
      FTag := '18';
      if FLastMessage.I <> 1 then Exit;

      FTag := '19';
      if not LServer.Send(LServer.LastClientID, 1.1) then Exit;
      FTag := '20';
      if Integer(FLastMessage.DataType) <> Integer(mdtDouble) then Exit;
      FTag := '21';
      if not SameValue(FLastMessage.D, 1.1, 0.00001) then Exit;

      FTag := '22';
      if not LServer.SendC(LServer.LastClientID, 1.2) then Exit;
      FTag := '23';
      if Integer(FLastMessage.DataType) <> Integer(mdtCurrency) then Exit;
      FTag := '24';
      if FLastMessage.C <> 1.2 then Exit;

      FTag := '25';
      if not LServer.SendDT(LServer.LastClientID, Date) then Exit;
      FTag := '26';
      if Integer(FLastMessage.DataType) <> Integer(mdtDateTime) then Exit;
      FTag := '27';
      if FLastMessage.DT <> Date then Exit;

      FTag := '28';
      DeleteFile(ExtractFilePath(ParamStr(0))+'TestFile_Client.txt');
      FTag := '29';
      if not LServer.SendFile(LClient.ID, ExtractFilePath(ParamStr(0))+'TestFile_Server.txt') then Exit;
      FTag := '30';
      if Integer(FLastMessage.DataType) <> Integer(mdtFile) then Exit;
      FTag := '31';
      if not FileExists(ExtractFilePath(ParamStr(0))+'TestFile_Client.txt') then Exit;

      ms1 := TMemoryStream.Create;
      ms2 := TMemoryStream.Create;
      try
        ms1.LoadFromFile(ExtractFilePath(ParamStr(0))+'TestFile_Server.txt');
        FTag := '32';
        if ms1.Size <> FLastMessage.DataSize then Exit;
        FTag := '33';
        if not CompareMem(ms1.Memory, FLastMessage.Data, ms1.Size) then Exit;

        ms2.LoadFromFile(ExtractFilePath(ParamStr(0))+'TestFile_Client.txt');
        FTag := '34';
        if ms1.Size <> ms2.Size then Exit;
        FTag := '35';
        if not CompareMem(ms1.Memory, ms2.Memory, ms1.Size) then Exit;
      finally
        ms1.Free;
        ms2.Free;
      end;

      LMessage := CreateIPCMessage;
      LMessage.S := '你好，';
      LMessage.Add('我是服务端。');
      LMessage.Topic := 123;
      LServer.Send(LClient.ID, LMessage);
      FTag := '36';
      if Integer(FLastMessage.DataType) <> Integer(mdtString) then Exit;
      FTag := '37';
      if FLastMessage.S <> '你好，我是服务端。' then Exit;
      FTag := '38';
      if FLastMessage.Topic <>123 then Exit;

      LMessage := CreateIPCMessage;
      LMessage.S := '你好，';
      LMessage.Add('我是客户端。');
      LMessage.Topic := 111;
      LClient.Send(LMessage);
      FTag := '39';
      if FLastMessage.S <> '你好，我是客户端。' then Exit;
      FTag := '40';
      if FLastMessage.Topic <> 111 then Exit;

      FLastMessage := nil;
      sMsg := '你好，这是广播消息';
      LServer.Broadcast(sMsg);
      FTag := '41';
      if FLastMessage = nil then Exit;;
      FTag := '42';
      if FLastMessage.S <> sMsg then Exit;

      LMessage := CreateIPCMessage;
      LMessage.S := '你好，';
      LMessage.Add('这是广播消息。');
      LMessage.Topic := 124;
      FTag := '43';
      if not LServer.Broadcast(LMessage) then Exit;
      FTag := '44';
      if FLastMessage.S <> '你好，这是广播消息。' then Exit;
      FTag := '45';
      if FLastMessage.Topic <>124 then Exit;
    finally
      LClient := nil;
      LServer := nil;
      FServer := nil;
      FClient := nil;
    end;   

    TestThreadMessageResult := True;

    ExitThread(0);
  end;
end;

{ TIPCTest }

procedure TIPCTest.DoClientMessage1(const AClient: IIPCClient; const AState: TIPCState;
  const ASenderID: Cardinal; const AMessage: IIPCMessage);
begin
  if not FMainThreadHang then
  begin
    if AState = isReceiveData then
      Assert(MainThreadID = GetCurrentThreadId);
  end;
  case AState of
    isAfterOpen:
    begin
      OutputDebugString('DoClientMessage1.isAfterOpen');
    end;
    isAfterClose:
    begin
      OutputDebugString('DoClientMessage1.isAfterClose');
    end;
    isConnect:
    begin
      OutputDebugString('DoClientMessage1.isConnect');
    end;
    isDisconnect:
    begin
      OutputDebugString('DoClientMessage1.isDisconnect');
    end;
    isReceiveData://该状态的处理处在主线程(默认)或一个独立的线程中(Server/Client的ReciveMessageInThread=True)
    begin
      OutputDebugString('DoClientMessage1.isReceiveData');
      FLastMessage := AMessage.Clone;
      case AMessage.DataType of
        mdtUnknown:
          OutputDebugString('自定义数据');
        mdtString:
          OutputDebugStringW(PWideChar('字符串：' + AMessage.S));
        mdtInteger:
          OutputDebugString(PChar('整数:' + IntToStr(AMessage.I)));
        mdtDouble:
          OutputDebugString(PChar('浮点数:' + FloatToStr(AMessage.D)));
        mdtCurrency:
          OutputDebugString(PChar('金额:' + FloatToStr(AMessage.C)));
        mdtDateTime:
          OutputDebugString(PChar('日期:' + DateTimeToStr(AMessage.DT)));
        mdtFile:
        begin
          OutputDebugString(PChar('接收到文件。'));
          AMessage.SaveToFile(ExtractFilePath(ParamStr(0))+'TestFile_Client.txt', False);
        end;
      end;
    end;
  end;
end;

procedure TIPCTest.DoClientMessage2(const AClient: IIPCClient;
  const AState: TIPCState; const ASenderID: Cardinal; const AMessage: IIPCMessage);
begin
  case AState of
    isAfterOpen:
    begin
      OutputDebugString('DoClientMessage2.isAfterOpen');
    end;
    isAfterClose:
    begin
      OutputDebugString('DoClientMessage2.isAfterClose');
    end;
    isConnect:
    begin
      OutputDebugString('DoClientMessage2.isConnect');
    end;
    isDisconnect:
    begin
      OutputDebugString('DoClientMessage2.isDisconnect');
    end;
    isReceiveData://该状态的处理处在主线程(默认)或一个独立的线程中(Server/Client的ReciveMessageInThread=True)
    begin
      //OutputDebugString('DoClientMessage2.isReceiveData');
      FLastMessage := AMessage.Clone;
    end;
  end;
end;

procedure TIPCTest.DoServerMessage1(const AServer: IIPCServer; const AState: TIPCState;
  const ASenderID: Cardinal; const AMessage: IIPCMessage);
begin
  if not FMainThreadHang then
    Assert(MainThreadID = GetCurrentThreadId);
  case AState of
    isAfterOpen:
    begin
      OutputDebugString('DoServerMessage1.isAfterOpen');
    end;
    isAfterClose:
    begin
      OutputDebugString('DoServerMessage1.isAfterClose');
    end;
    isConnect:
    begin
      OutputDebugString('DoServerMessage1.isConnect');
    end;
    isDisconnect:
    begin
      OutputDebugString('DoServerMessage1.isDisconnect');
    end;
    isReceiveData://该状态的处理处在主线程(默认)或一个独立的线程中(Server/Client的ReciveMessageInThread=True)
    begin
      OutputDebugString('DoServerMessage1.isReceiveData');
      case AMessage.DataType of
        mdtUnknown:
          OutputDebugString('自定义数据');
        mdtString:
          OutputDebugStringW(PWideChar('字符串：' + AMessage.S));
        mdtInteger:
          OutputDebugString(PChar('整数:' + IntToStr(AMessage.I)));
        mdtDouble:
          OutputDebugString(PChar('浮点数:' + FloatToStr(AMessage.D)));
        mdtCurrency:
          OutputDebugString(PChar('金额:' + FloatToStr(AMessage.C)));
        mdtDateTime:
          OutputDebugString(PChar('日期:' + DateTimeToStr(AMessage.DT)));
        mdtFile:
          OutputDebugString(PChar('接收到文件。'));
      end;
      FLastMessage := AMessage.Clone;
      //AServer.Send(ASenderID, '你好，我是服务端');
    end;
  end;
end;

procedure TIPCTest.DoServerMessage2(const AServer: IIPCServer;
  const AState: TIPCState; const ASenderID: Cardinal; const AMessage: IIPCMessage);
begin
  case AState of
    isAfterOpen:
    begin
      OutputDebugString('DoServerMessage2.isAfterOpen');
    end;
    isAfterClose:
    begin
      OutputDebugString('DoServerMessage2.isAfterClose');
    end;
    isConnect:
    begin
      OutputDebugString('DoServerMessage2.isConnect');
    end;
    isDisconnect:
    begin
      OutputDebugString('DoServerMessage2.isDisconnect');
    end;
    isReceiveData://该状态的处理处在主线程(默认)或一个独立的线程中(Server/Client的ReciveMessageInThread=True)
    begin
      //OutputDebugString('DoServerMessage2.isReceiveData');
      //FLastMessage := AMessage.Clone;
      //AServer.Send(ASenderID, '你好，我是服务端');
    end;
  end;
end;

procedure TIPCTest.SessionHandleTest;
var
  LServer1, LServer2: IIPCServer;
  LClient1, LClient2: IIPCClient;
//  i: Integer;
begin
  LServer1 := CreateIPCServer('Test1');
  LClient1 := CreateIPCClient('Test1');
  LServer2 := CreateIPCServer('Test2');
  LClient2 := CreateIPCClient('Test2');

  CheckTrue(LServer1.Open);
  CheckEquals(LServer1.SessionHandle, 1);
  CheckTrue(LServer2.Open);
  CheckEquals(LServer2.SessionHandle, 2);
  CheckTrue(LClient1.Open);
  CheckEquals(LClient1.SessionHandle, 1);
  CheckTrue(LClient2.Open);
  CheckEquals(LClient2.SessionHandle, 2);

  LServer2 := nil;
  LServer2 := CreateIPCServer('Test2');
  CheckTrue(LServer2.Open);
  CheckEquals(LServer2.SessionHandle, 2);

  LServer1 := nil;
  LServer1 := CreateIPCServer('Test1');
  CheckTrue(LServer1.Open);
  CheckEquals(LServer1.SessionHandle, 1);

  LServer1 := nil;
  LClient1 := nil;
  LServer1 := CreateIPCServer('Test3');
  LClient1 := CreateIPCClient('Test3');
  CheckTrue(LServer1.Open);
  CheckEquals(LServer1.SessionHandle, 1);
  CheckTrue(LClient1.Open);
  CheckEquals(LClient1.SessionHandle, 1);

//  LServer1 := CreateIPCServer;
//  LClient1 := CreateIPCClient;
//  for i := 0 to 1000 do
//  begin
//    Application.ProcessMessages;
//    CheckTrue(LServer1.Open('TestSessionHandle'+Inttostr(i)), 'LServer1.Open['+IntToStr(i)+']:');
//    CheckTrue(LClient1.Open('TestSessionHandle'+Inttostr(i)), 'LClient1.Open['+IntToStr(i)+']:');
//    if i mod 1000 = 0 then
//    begin
//      Status(IntToStr(i));
//    end;
//    LServer1.Close;
//    LClient1.Close;
//  end;
end;

procedure TIPCTest.SetUp;
begin
  inherited;
  if Name = 'TestThreadMessage1' then
  begin
    FServer := CreateIPCServer;
    FClient := CreateIPCClient;
  end;
end;

procedure TIPCTest.TearDown;
begin
  FLastMessage := nil;
  FServer := nil;
  FClient := nil;
  inherited;
end;

procedure TIPCTest.TestBase;
var
  LServer: IIPCServer;
  LClient: IIPCClient;
  sMsg, sClientInfos: WideString;
  ms1, ms2: TMemoryStream;
  LMessage: IIPCMessage;
begin
  LServer := CreateIPCServer('Test');
  LClient := CreateIPCClient('Test');
  LServer.OnMessage := DoServerMessage1;
  LClient.OnMessage := DoClientMessage1;

  CheckTrue(LServer.Open);
  CheckTrue(LClient.Open);
  CheckNotEquals(LServer.ID, 0);
  CheckNotEquals(LClient.ID, 0);
  CheckTrue(LServer.IsConnect(LClient.ID));

  sClientInfos := LServer.ClientInfos;
  CheckEquals(sClientInfos, '[ { clientID: ' + IntToStr(LClient.ID) + ' } ]');

  sMsg := 'Hello 你好';
  CheckTrue(LClient.Send(sMsg));
  CheckEquals(LServer.LastClientID, LClient.ID);
  CheckNotNull(FLastMessage);
  CheckEquals(FLastMessage.S, sMsg);
  CheckEquals(FLastMessage.SenderID, LClient.ID);
  LServer.Send(LServer.LastClientID, '你好，我是服务端');
  CheckNotNull(FLastMessage);
  CheckEquals(FLastMessage.S, '你好，我是服务端');
  CheckEquals(FLastMessage.SenderID, LServer.ID);
  
  CheckTrue(LServer.Send(LServer.LastClientID, 1));
  CheckEquals(Integer(FLastMessage.DataType), Integer(mdtInteger));
  CheckEquals(FLastMessage.I, 1);

  CheckTrue(LServer.Send(LServer.LastClientID, 1.1));
  CheckEquals(Integer(FLastMessage.DataType), Integer(mdtDouble));
  CheckEquals(FLastMessage.D, 1.1, 0.00001);

  CheckTrue(LServer.SendC(LServer.LastClientID, 1.2));
  CheckEquals(Integer(FLastMessage.DataType), Integer(mdtCurrency));
  CheckEquals(FLastMessage.C, 1.2);

  CheckTrue(LServer.SendDT(LServer.LastClientID, Date));
  CheckEquals(Integer(FLastMessage.DataType), Integer(mdtDateTime));
  CheckEquals(FLastMessage.DT, Date);

  DeleteFile(ExtractFilePath(ParamStr(0))+'TestFile_Client.txt');
  CheckTrue(LServer.SendFile(LClient.ID, ExtractFilePath(ParamStr(0))+'TestFile_Server.txt'));
  CheckEquals(Integer(FLastMessage.DataType), Integer(mdtFile));
  CheckTrue(FileExists(ExtractFilePath(ParamStr(0))+'TestFile_Client.txt'));
  ms1 := TMemoryStream.Create;
  ms2 := TMemoryStream.Create;
  try
    ms1.LoadFromFile(ExtractFilePath(ParamStr(0))+'TestFile_Server.txt');
    CheckEquals(ms1.Size, FLastMessage.DataSize);
    CheckTrue(CompareMem(ms1.Memory, FLastMessage.Data, ms1.Size));

    ms2.LoadFromFile(ExtractFilePath(ParamStr(0))+'TestFile_Client.txt');
    CheckEquals(ms1.Size, ms2.Size);
    CheckTrue(CompareMem(ms1.Memory, ms2.Memory, ms1.Size));
  finally
    ms1.Free;
    ms2.Free;
  end;

  LMessage := CreateIPCMessage;
  LMessage.S := '你好，';
  LMessage.Add('我是服务端。');
  LMessage.Topic := 123;
  LServer.Send(LClient.ID, LMessage);
  CheckEquals(Integer(FLastMessage.DataType), Integer(mdtString));
  CheckEquals(FLastMessage.S, '你好，我是服务端。');
  CheckEquals(FLastMessage.Topic, 123);

  LMessage := CreateIPCMessage;
  LMessage.S := '你好，';
  LMessage.Add('我是客户端。');
  LMessage.Topic := 111;
  LClient.Send(LMessage);
  CheckEquals(FLastMessage.S, '你好，我是客户端。');
  CheckEquals(FLastMessage.Topic, 111);

  sMsg := '你好，这是广播消息';
  LServer.Broadcast(sMsg);
  CheckNotNull(FLastMessage);
  CheckEquals(FLastMessage.S, sMsg);

  LMessage := CreateIPCMessage;
  LMessage.S := '你好，';
  LMessage.Add('这是广播消息。');
  LMessage.Topic := 124;
  CheckTrue(LServer.Broadcast(LMessage));
  CheckEquals(FLastMessage.S, '你好，这是广播消息。');
  CheckEquals(FLastMessage.Topic, 124);

  CheckFalse(LClient.MethodExist('ShowMessage'));
  LServer.Dispatch := TObjectDispatch.Create(TIPCServerTest.Create);
  CheckTrue(LClient.MethodExist('ShowMessage'));
  CheckFalse(LClient.MethodExist('ShowMessageNotExist'));

  bIPCServerTestCalled := False;

  LMessage := LClient.Call('ShowMessage', ['你好啊']);
  CheckTrue(bIPCServerTestCalled);
  CheckNotNull(LMessage);
  CheckEquals(LMessage.DataType, mdtBoolean);
  CheckTrue(LMessage.B);

  bIPCServerTestCalled := False;
  sMsg := '你好啊';
  LMessage := CreateIPCMessage;
  LMessage.Add(Pointer(sMsg), Length(sMsg)*IPC_CHAR_SIZE);
  CheckEquals(LMessage.DataType, mdtUnknown);
  LMessage := LClient.Call('ShowMessage1', [LMessage]);
  CheckTrue(bIPCServerTestCalled);
  CheckNotNull(LMessage);
  CheckEquals(LMessage.DataType, mdtBoolean);
  CheckTrue(LMessage.B);

  LClient.Dispatch := TObjectDispatch.Create(TIPCClientTest.Create);
  bIPCClientTestCalled := False;
  LMessage := LServer.Call(LClient.ID, 'ShowMessage', ['你好啊']);
  CheckTrue(bIPCClientTestCalled);
  CheckNotNull(LMessage);
  CheckEquals(LMessage.DataType, mdtBoolean);
  CheckTrue(LMessage.B);

  CheckFalse(LServer.MethodExist(LClient.ID, 'ShowMessageNotExist'));

  LClient := nil;
  LServer := nil;
end;

procedure TIPCTest.TestFindMethods;
var
  LServer1, LServer2: IIPCServer;
  LClient1, LClient2: IIPCClient;
  F: PIPCSearchRec;
begin
  LServer1 := CreateIPCServer('Test1');
  LServer2 := CreateIPCServer('Test2');
  LClient1 := CreateIPCClient('Test1');
  LClient2 := CreateIPCClient('Test2');
  LServer1.OnMessage := DoServerMessage1;
  LClient1.OnMessage := DoClientMessage1;
  LServer2.OnMessage := DoServerMessage1;
  LClient2.OnMessage := DoClientMessage1;

  CheckTrue(LServer1.Open);
  CheckTrue(LServer2.Open);
  CheckTrue(LClient1.Open);
  CheckTrue(LClient2.Open);
  CheckEquals(LServer1.ClientCount, 1);
  CheckEquals(LServer2.ClientCount, 1);

  FLastMessage := nil;
  CheckTrue(IPCServerFindFirst('*', F));
  try
    CheckTrue((F.SessionName = LServer1.SessionName) or (F.SessionName = LServer2.SessionName));
    if F.SessionName = LServer1.SessionName then
      CheckEquals(F.SessionHandle, LServer1.SessionHandle)
    else
      CheckEquals(F.SessionHandle, LServer2.SessionHandle);
    CheckEquals(SendIPCMessage(0, F.FindID, F.SessionHandle, '你好，我是外部消息。'), 1);
    CheckNotNull(FLastMessage);
    CheckEquals(FLastMessage.S, '你好，我是外部消息。');

    FLastMessage := nil;
    CheckTrue(IPCFindNext(F));
    CheckEquals(SendIPCMessage(0, F.FindID, F.SessionHandle, '你好，我是外部消息。'), 1);
    CheckNotNull(FLastMessage);
    CheckEquals(FLastMessage.S, '你好，我是外部消息。');
    CheckTrue((F.SessionName = LServer1.SessionName) or (F.SessionName = LServer2.SessionName));
    if F.SessionName = LServer1.SessionName then
      CheckEquals(F.SessionHandle, LServer1.SessionHandle)
    else
      CheckEquals(F.SessionHandle, LServer2.SessionHandle);  
    CheckFalse(IPCFindNext(F));
  finally
    IPCFindClose(F);
  end;
  CheckTrue(IPCServerFindFirst('*st1', F));
  try
    CheckTrue(F.SessionName = LServer1.SessionName);
    CheckFalse(IPCFindNext(F));
  finally
    IPCFindClose(F);
  end;
  CheckTrue(IPCServerFindFirst('*2', F));
  try
    CheckTrue(F.SessionName = LServer2.SessionName);
    CheckFalse(IPCFindNext(F));
  finally
    IPCFindClose(F);
  end;

  CheckTrue(IPCClientFindFirst('*', F));
  try
    CheckTrue((F.SessionName = LClient1.SessionName) or (F.SessionName = LClient2.SessionName));
    CheckTrue(IPCFindNext(F));
    CheckTrue((F.SessionName = LClient1.SessionName) or (F.SessionName = LClient2.SessionName));
    CheckFalse(IPCFindNext(F));
  finally
    IPCFindClose(F);
  end;
  CheckTrue(IPCClientFindFirst('*st1', F));
  try
    CheckTrue(F.SessionName = LClient1.SessionName);
    CheckFalse(IPCFindNext(F));
  finally
    IPCFindClose(F);
  end;
  CheckTrue(IPCClientFindFirst('*2', F));
  try
    CheckTrue(F.SessionName = LClient2.SessionName);
    CheckFalse(IPCFindNext(F));
  finally
    IPCFindClose(F);
  end;
end;

procedure TIPCTest.TestMessageQueue;
var
  LServer: IIPCServer;
  LClient: IIPCClient;
  sMsg: WideString;
  LMessage: IIPCMessage;
begin
  LServer := CreateIPCServer('Test');
  LClient := CreateIPCClient('Test');
  LClient.ReciveMessageToQueue := True;
  LServer.ReciveMessageToQueue := True;
  LServer.OnMessage := DoServerMessage1;
  LClient.OnMessage := DoClientMessage1;

  CheckTrue(LServer.Open);
  CheckTrue(LClient.Open);
  CheckNotEquals(LServer.ID, 0);
  CheckNotEquals(LClient.ID, 0);
  CheckTrue(LServer.IsConnect(LClient.ID));

  sMsg := 'Hello 你好';
  CheckTrue(LClient.Send(sMsg));
  CheckEquals(LServer.LastClientID, LClient.ID);
  CheckTrue(LServer.ReciveQueue.Count = 1);
  CheckTrue(LServer.ReciveQueue.Pop(LMessage));
  CheckTrue(LServer.ReciveQueue.Count = 0);
  CheckNotNull(LMessage);
  CheckEquals(LMessage.S, sMsg);
  CheckEquals(LMessage.SenderID, LClient.ID);

  sMsg := '你好，我是服务端';
  LServer.Send(LServer.LastClientID, sMsg);
  CheckTrue(LClient.ReciveQueue.Count = 1);
  CheckTrue(LClient.ReciveQueue.Pop(LMessage));
  CheckTrue(LClient.ReciveQueue.Count = 0);
  CheckNotNull(LMessage);
  CheckEquals(LMessage.S, sMsg);
  CheckEquals(LMessage.SenderID, LServer.ID);

  sMsg := 'Hello 你好';
  CheckTrue(LClient.Send(sMsg + '1'));
  CheckTrue(LClient.Send(sMsg + '2'));
  CheckEquals(LServer.LastClientID, LClient.ID);
  CheckTrue(LServer.ReciveQueue.Count = 2);
  CheckTrue(LServer.ReciveQueue.Pop(LMessage));
  CheckTrue(LServer.ReciveQueue.Count = 1);
  CheckNotNull(LMessage);
  CheckEquals(LMessage.S, sMsg + '1');
  CheckEquals(LMessage.SenderID, LClient.ID);
  CheckTrue(LServer.ReciveQueue.Pop(LMessage));
  CheckTrue(LServer.ReciveQueue.Count = 0);
  CheckNotNull(LMessage);
  CheckEquals(LMessage.S, sMsg + '2');
  CheckEquals(LMessage.SenderID, LClient.ID);

  sMsg := '你好，我是服务端';
  LServer.Send(LServer.LastClientID, sMsg + '1');
  LServer.Send(LServer.LastClientID, sMsg + '2');
  CheckTrue(LClient.ReciveQueue.Count = 2);
  CheckTrue(LClient.ReciveQueue.Pop(LMessage));
  CheckTrue(LClient.ReciveQueue.Count = 1);
  CheckNotNull(LMessage);
  CheckEquals(LMessage.S, sMsg + '1');
  CheckEquals(LMessage.SenderID, LClient.ServerID);
  CheckTrue(LClient.ReciveQueue.Pop(LMessage));
  CheckTrue(LClient.ReciveQueue.Count = 0);
  CheckNotNull(LMessage);
  CheckEquals(LMessage.S, sMsg + '2');
  CheckEquals(LMessage.SenderID, LClient.ServerID);

  LClient := nil;
  LServer := nil;
end;

procedure TIPCTest.TestMultiClient;
var
  LServer: IIPCServer;
  LClient1, LClient2: IIPCClient;
  sMsg: WideString;
begin
  LServer := CreateIPCServer('Test');
  LClient1 := CreateIPCClient('Test');
  LClient2 := CreateIPCClient('Test');
  LServer.OnMessage := DoServerMessage1;
  LClient1.OnMessage := DoClientMessage1;
  LClient2.OnMessage := DoClientMessage1;

  LServer.Open;
  LClient1.Open;
  LClient2.Open;
  
  sMsg := 'Hello 你好';
  LClient1.Send(sMsg);
  CheckNotNull(FLastMessage);
  CheckEquals(FLastMessage.S, sMsg);
  
  LServer.Send(LServer.LastClientID, '你好，我是服务端');
  CheckNotNull(FLastMessage);
  CheckEquals(FLastMessage.S, '你好，我是服务端');

  sMsg := '你好，这是广播消息';
  LServer.Broadcast(sMsg);
  CheckNotNull(FLastMessage);
  CheckEquals(FLastMessage.S, sMsg);
  CheckNotNull(FLastMessage);
  CheckEquals(FLastMessage.S, sMsg);
end;

procedure TIPCTest.TestMultiServerAndClient;
var
  LServer1, LServer2: IIPCServer;
  LClient1, LClient2: IIPCClient;
begin
  LServer1 := CreateIPCServer('Test1');
  LClient1 := CreateIPCClient('Test1');
  LServer2 := CreateIPCServer('Test2');
  LClient2 := CreateIPCClient('Test2');
  LServer1.OnMessage := DoServerMessage1;
  LServer2.OnMessage := DoServerMessage1;
  LClient1.OnMessage := DoClientMessage1;
  LClient2.OnMessage := DoClientMessage1;

  CheckTrue(LServer1.Open);
  CheckTrue(LServer2.Open);
  CheckTrue(LClient1.Open);
  CheckTrue(LClient2.Open);
  CheckEquals(LServer1.ClientCount, 1);
  CheckEquals(LServer2.ClientCount, 1);

  CheckTrue(LClient1.Send('你好，我是客户端1'));
  CheckTrue(LClient2.Send('你好，我是客户端2'));
  CheckEquals(LServer1.LastClientID, LClient1.ID);
  CheckEquals(LServer2.LastClientID, LClient2.ID);

  CheckTrue(LServer1.Broadcast('你好，我是广播消息1'));
  CheckEquals(FLastMessage.S, '你好，我是广播消息1');
  CheckTrue(LServer2.Broadcast('你好，我是广播消息2'));
  CheckEquals(FLastMessage.S, '你好，我是广播消息2');
end;

procedure TIPCTest.TestSendPerformance;
var
  LServer: IIPCServer;
  LClient: IIPCClient;
  i: Integer;
  tick: Cardinal;
begin
  LServer := CreateIPCServer('Test');
  LClient := CreateIPCClient('Test');
  LServer.OnMessage := DoServerMessage2;
  LClient.OnMessage := DoClientMessage2;
  //LServer.ReciveMessageInThread := False;
  //LClient.ReciveMessageInThread := False;
  
  LServer.Open;
  LClient.Open;
  tick := GetTickCount;
  for i := 0 to 10000 do
  begin
    CheckTrue(LServer.Send(LClient.ID, '测试数据'+IntToStr(i)));
    CheckEquals(FLastMessage.S, '测试数据'+IntToStr(i));
  end;
  Status('发送10000条数据耗时：' + IntToStr(GetTickCount - tick));
end;

//procedure TIPCTest.TestThreadMessage1;
//var
//  tid, hHandle: Cardinal;
//begin
//  TestThreadMessageResult := False;
//  FMainThreadHang := True;
//  hHandle := BeginThread(nil, 0, @_TestThreadMessageProc, Pointer(Self), 0, tid);
//  try
//    //WaitForSingleObject(hHandle, INFINITE);
//    //CheckTrue(TestThreadMessageResult);
//  finally
//    CloseHandle(hHandle);
//  end;
//end;

procedure TIPCTest.TestThreadMessage2;
var
  tid, hHandle: Cardinal;
begin
  TestThreadMessageResult := False;
  hHandle := BeginThread(nil, 0, @_TestThreadMessageProc, Pointer(Self), 0, tid);
  try
    while WaitForSingleObject(hHandle, 0) <> WAIT_OBJECT_0 do //不能挂起主线程，否则无法在主线程里接收消息
      Application.ProcessMessages;
    CheckTrue(TestThreadMessageResult, FTag);
  finally
    if hHandle <> 0 then
      CloseHandle(hHandle);
  end;
end;

procedure TIPCTest.TestThreadMessage3;
var
  tid, hHandle: Cardinal;
begin
  TestThreadMessageResult := False;
  FMainThreadHang := True;
  hHandle := BeginThread(nil, 0, @_TestThreadMessageProc, Pointer(Self), 0, tid);
  try
    WaitForSingleObject(hHandle, INFINITE);
    FMainThreadHang := False;
    CheckTrue(TestThreadMessageResult, FTag);
  finally
    if hHandle <> 0 then
      CloseHandle(hHandle);
  end;
end;

{ TIPCServerTest }

function TIPCServerTest.ShowMessage(const AMsg: WideString): Boolean;
begin
  OutputDebugStringW(PWideChar('[TIPCServerTest]:'+ AMsg));
  bIPCServerTestCalled := True;
  Result := True;
end;

function TIPCServerTest.ShowMessage1(const AMsg: IIPCMessage): IIPCMessage;
begin
  bIPCServerTestCalled := True;
  OutputDebugStringW(PWideChar(AMsg.S));
  Result := CreateIPCMessage;
  Result.B := True;
end;

{ TIPCClientTest }

function TIPCClientTest.ShowMessage(const AMsg: WideString): Boolean;
begin
  OutputDebugStringW(PWideChar('[TIPCClientTest]:'+AMsg));
  bIPCClientTestCalled := True;
  Result := True;
end;

initialization
  TestFrameWork.RegisterTest('IPC测试', TIPCTest.Suite);

end.
