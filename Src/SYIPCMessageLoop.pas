unit SYIPCMessageLoop;

interface

uses
  Windows, Messages, SysUtils, Classes, SYIPCCommon, ShareMemFile;

type
  TMyThread = class
  private
    FHandle: THandle;
    FThreadID: THandle;
    FFinished: Boolean;
    FSuspended: Boolean;
    FTerminated: Boolean;
    FFreeOnTerminate: Boolean;
    FReturnValue: Integer;
  protected
    procedure Execute; virtual; abstract;

    property Terminated: Boolean read FTerminated;
    property ReturnValue: Integer read FReturnValue write FReturnValue;
  public
    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;

    procedure Resume;
    procedure Suspend;
    procedure Terminate;

    property ThreadID: THandle read FThreadID;
    property FreeOnTerminate: Boolean read FFreeOnTerminate write FFreeOnTerminate;
  end;
  
  TMessageLoopThread = class(TMyThread)
  private
    FOwner: TObject;
    FThreadWnd: HWND;
    FAllocateMethod: TWndMethod;
    FAllocateWndName: WideString;
    FThreadWndCreateEvent: Cardinal;
  protected
    procedure ThreadWndProc(var AMsg: TMessage);
    procedure Execute; override;
  public
    constructor Create(CreateSuspended: Boolean; AOwner: TObject);
    destructor Destroy; override;
    function  AllocateThreadHWnd(const Method: TWndMethod; const AWindowName: WideString): HWND;
    procedure DeallocateThreadHWnd(Wnd: HWND);
  end;

  TMainThreadWindow = class
  private
    FMainThreadWnd: HWND;
    FSessionTable: TShareMemoryFile;
    procedure MainThreadWndProc(var AMsg: TMessage);
  public
    constructor Create;
    destructor Destroy; override;

    function  AllocSession(const ASessionName: WideString): Cardinal;
    procedure DeallocSession(const ASessionHandle: Cardinal);
    
    function  CreateMessageLoop(CreateSuspended: Boolean; AOwner: TObject): TMessageLoopThread;
    procedure FreeMessageLoop(var AMessageLoop: TMessageLoopThread);
    procedure DoIPCMessage(const ASender: TObject; const AData: PIPCMessageStruct);
  end;

var
  MainThreadWindow: TMainThreadWindow;

procedure _ThreadServerTimerProc(hwnd:HWND; uMsg, idEvent: UINT; dwTime: DWORD); stdcall;
procedure _ThreadClientTimerProc(hwnd:HWND; uMsg, idEvent: UINT; dwTime: DWORD); stdcall;
  
implementation

uses
  SYIPCClient, SYIPCServer, SYIPCBase, SYIPCIntf;

const
  WM_AllocateHWND      = WM_USER + 1;
  WM_DeallocateHWND    = WM_USER + 2;
  WM_DoIPCMessage      = WM_USER + 3;

  SessionTableItemCount = $3FFF - 1;

type
  TIPCServerAccess = class(TIPCServer);
  TIPCClientAccess = class(TIPCClient);
  TIPCBaseAccess = class(TIPCBase);

  PSessionTableItem = ^TSessionTableItem;
  TSessionTableItem = packed record
    Used: Boolean;
    RefCount: Integer;
    Name: array[0..IPC_SESSIONNAME_SIZE-1] of WideChar;
  end;
  TSessionTableArray = array[0..SessionTableItemCount-1] of TSessionTableItem;
  PSessionTableArray = ^TSessionTableArray;

procedure _ThreadServerTimerProc(hwnd:HWND; uMsg, idEvent: UINT; dwTime: DWORD); stdcall;
var
  LServer: TIPCServerAccess;
  LList: TList;
  i: Integer;
  LClients: array of Cardinal;
begin
  try
    LServer := TIPCServerAccess(idEvent);
    if not LServer.FActive then
      Exit;
    LList := LServer.FClientList.LockList;
    try
      SetLength(LClients, LList.Count);
      for i := 0 to LList.Count - 1 do
        LClients[i] := Cardinal(LList[i]);
    finally
      LServer.FClientList.UnlockList;
    end;
    for i := 0 to High(LClients) do
    begin
      if not IsWindow(LClients[i]) then
        LServer.DoRemoveClient(LClients[i]);
    end;
  except
    on E: Exception do
      OutputDebugString(PChar('[_ThreadServerTimerProc]'+E.Message));
  end;
end;

procedure _ThreadClientTimerProc(hwnd:HWND; uMsg, idEvent: UINT; dwTime: DWORD); stdcall;
var
  LClient: TIPCClientAccess;
begin
  try
    LClient := TIPCClientAccess(idEvent);
    if not LClient.FActive then
      Exit;
    if LClient.FServerID = 0 then
      Exit;
    if not IsWindow(LClient.ID) then
      Exit;
    if IsWindow(LClient.FServerID) then
      Exit;
    PostMessage(LClient.ID, LClient.FServerDisconnetHwnd, LClient.FSessionHandle, LClient.FServerID);
  except
    on E: Exception do
      OutputDebugString(PChar('[_ThreadClientTimerProc]'+E.Message));
  end;
end;

{ TMessageLoopThread }

function TMessageLoopThread.AllocateThreadHWnd(const Method: TWndMethod; const AWindowName: WideString): HWND;
begin
  Assert(FThreadWnd <> 0);
  FAllocateWndName := AWindowName;
  FAllocateMethod := Method;
  Result := SendMessage(FThreadWnd, WM_AllocateHWND, 0, 0);
end;

constructor TMessageLoopThread.Create(CreateSuspended: Boolean; AOwner: TObject);
begin
  FOwner := AOwner;
  inherited Create(CreateSuspended);
  FThreadWndCreateEvent := CreateEvent(nil, True, False, nil);
end;

procedure TMessageLoopThread.DeallocateThreadHWnd(Wnd: HWND);
begin
  Assert(FThreadWnd <> 0);
  SendMessage(FThreadWnd, WM_DeallocateHWND, Integer(Wnd), 0)
end;

destructor TMessageLoopThread.Destroy;
begin
  if FThreadWnd <> 0 then
    PostThreadMessage(ThreadID, WM_QUIT, 0, 0);
  Terminate;
  inherited;
  if FThreadWndCreateEvent <> 0 then
    CloseHandle(FThreadWndCreateEvent);
end;

procedure TMessageLoopThread.Execute;
var
  msg: TMsg;
begin
  FThreadWnd := Classes.AllocateHWnd(ThreadWndProc);
  try
    if FOwner.ClassType = TIPCServer then
      SetTimer(FThreadWnd, Cardinal(FOwner), IPCConnectCheckInterval, @_ThreadServerTimerProc)
    else
    if FOwner.ClassType = TIPCClient then
      SetTimer(FThreadWnd, Cardinal(FOwner), IPCConnectCheckInterval, @_ThreadClientTimerProc);
    SetEvent(FThreadWndCreateEvent);
    while (not Terminated) and (FThreadWnd<>0) do
    begin
      if not GetMessage(msg, 0, 0, 0) then
        Break;
      TranslateMessage(msg);
      DispatchMessage(msg);
    end;
  finally
    if FThreadWnd <> 0 then
    begin
      KillTimer(FThreadWnd, Cardinal(FOwner));
      Classes.DeallocateHWnd(FThreadWnd);
      FThreadWnd := 0;
    end;
  end;
end;

procedure TMessageLoopThread.ThreadWndProc(var AMsg: TMessage);
begin
  case AMsg.Msg of
    WM_AllocateHWND:
      AMsg.Result := AllocateIPCHWnd(FAllocateMethod, FAllocateWndName);
    WM_DeallocateHWND:
    begin
      if (AMsg.WParam <> 0) and IsWindow(AMsg.WParam) then
        DeallocateIPCHWnd(AMsg.WParam);
    end;
  else
    AMsg.Result := DefWindowProc(FThreadWnd, AMsg.Msg, AMsg.WParam, AMsg.LParam);
    if AMsg.Msg = WM_DESTROY then
    begin
      FThreadWnd := 0;
    end;
  end;
end;

{ TMainThreadWindow }

constructor TMainThreadWindow.Create;
begin
  FMainThreadWnd := Classes.AllocateHWnd(MainThreadWndProc);
  FSessionTable := TShareMemoryFile.Create(IPCSessionTableName, SizeOf(TSessionTableArray));
end;

function TMainThreadWindow.CreateMessageLoop(CreateSuspended: Boolean;
  AOwner: TObject): TMessageLoopThread;
begin
  Result := TMessageLoopThread.Create(CreateSuspended, AOwner);
  WaitForSingleObject(TMessageLoopThread(Result).FThreadWndCreateEvent, INFINITE);
  if TMessageLoopThread(Result).FThreadWndCreateEvent <> 0 then
  begin
    CloseHandle(TMessageLoopThread(Result).FThreadWndCreateEvent);
    TMessageLoopThread(Result).FThreadWndCreateEvent := 0;
  end;
end;

destructor TMainThreadWindow.Destroy;
begin
  if FMainThreadWnd <> 0 then
    Classes.DeallocateHWnd(FMainThreadWnd);
  if FSessionTable <> nil then
    FreeAndNil(FSessionTable);
  inherited;
end;

procedure TMainThreadWindow.DoIPCMessage(const ASender: TObject; const AData: PIPCMessageStruct);
begin
  Assert(FMainThreadWnd <> 0);
  SendMessage(FMainThreadWnd, WM_DoIPCMessage, Integer(ASender), Integer(AData))
end;

procedure TMainThreadWindow.FreeMessageLoop(
  var AMessageLoop: TMessageLoopThread);
begin
  FreeAndNil(AMessageLoop)
end;

function TMainThreadWindow.AllocSession(
  const ASessionName: WideString): Cardinal;
var
  i: Cardinal;
  LTable: PSessionTableArray;
  LItem: PSessionTableItem;
begin
  Result := 0;
  if not FSessionTable.Lock then
    Exit;
  try
    LTable := FSessionTable.Memory;
    for i := 0 to SessionTableItemCount - 1 do
    begin
      LItem := @LTable[i];
      if  LItem.Used then
      begin
        if lstrcmpW(PWideChar(ASessionName), @LItem.Name[0]) = 0 then
        begin
          LItem.RefCount := LItem.RefCount + 1;
          Result := i + 1;
          Exit;
        end;
        Continue;
      end
      else
      begin
        LItem.Used := True;
        Move(PWideChar(ASessionName)^, LItem.Name[0], Length(ASessionName)*IPC_CHAR_SIZE);
        LItem.RefCount := 1;
        Result := i + 1;
        Exit;
      end;
    end;
  finally
    FSessionTable.Unlock;
  end;   
  //Result := RegisterWindowMessageW(PWideChar(ASessionName));
end;

procedure TMainThreadWindow.DeallocSession(const ASessionHandle: Cardinal);
var
  LTable: PSessionTableArray;
  LItem: PSessionTableItem;
begin
  if (ASessionHandle = 0) or (ASessionHandle > SessionTableItemCount) then
    Exit;
  if not FSessionTable.Lock then
    Exit;
  try
    LTable := FSessionTable.Memory;
    LItem := @LTable[ASessionHandle-1];
    if not LItem.Used then
      Exit;
    LItem.RefCount := LItem.RefCount - 1;
    if LItem.RefCount <= 0 then
    begin
      ZeroMemory(@LItem.Name[0], IPC_SESSIONNAME_SIZE*IPC_CHAR_SIZE);
      LItem.Used := False;
    end;
  finally
    FSessionTable.Unlock;
  end; 
end;

procedure TMainThreadWindow.MainThreadWndProc(var AMsg: TMessage);
begin
  case AMsg.Msg of
    WM_DoIPCMessage:
      with PIPCMessageStruct(AMsg.LParam)^ do
        TIPCBaseAccess(AMsg.WParam).DoMessage(TIPCBase(Sender), State, SenderID, Message);
  else
    AMsg.Result := DefWindowProc(FMainThreadWnd, AMsg.Msg, AMsg.WParam, AMsg.LParam);
    if AMsg.Msg = WM_DESTROY then
      FMainThreadWnd := 0;
  end;
end;

{ TMyThread }
function _ThreadProc(Thread: TMyThread): Integer;
var
  FreeThread: Boolean;
begin
  try
    if not Thread.Terminated then
    try
      Thread.Execute;
    except
      on E: Exception do
        OutputDebugString(PChar('[ThreadProc]'+E.Message));
    end;
  finally
    FreeThread := Thread.FFreeOnTerminate;
    Result := Thread.FReturnValue;
    Thread.FFinished := True;
    if FreeThread then Thread.Free;
    EndThread(Result);
  end;
end;
constructor TMyThread.Create(CreateSuspended: Boolean);
begin
  FSuspended := CreateSuspended;
  FHandle := BeginThread(nil, 0, @_ThreadProc, Pointer(Self), CREATE_SUSPENDED, FThreadID);
  if FHandle = 0 then
    raise ESYIPCExection.CreateFmt('Thread creation error: %s', [SysErrorMessage(GetLastError)]);
  if not CreateSuspended then
    Resume;
end;

destructor TMyThread.Destroy;
begin
  if FHandle <> 0 then
  begin
    if not FFinished then
      TerminateThread(FHandle, 0);
    CloseHandle(FHandle);
  end;
  inherited Destroy;
end;

procedure TMyThread.Resume;
var
  SuspendCount: Integer;
begin
  SuspendCount := ResumeThread(FHandle);
  if SuspendCount = 1 then
    FSuspended := False;
end;

procedure TMyThread.Suspend;
begin
  if Integer(SuspendThread(FHandle)) >= 0 then
    FSuspended := True;
end;

procedure TMyThread.Terminate;
begin
  FTerminated := True;
  Sleep(0);
end;

initialization
  AllowMeesageForVistaAbove(WM_COPYDATA, True);
  Assert(MainThreadID = GetCurrentThreadId);
  MainThreadWindow := TMainThreadWindow.Create;

finalization
  Assert(MainThreadID = GetCurrentThreadId);
  MainThreadWindow.Free;


end.
