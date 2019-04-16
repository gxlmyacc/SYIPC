unit SYIPCUtils;

interface

uses
  SYIPCIntf, Windows;

const
  ShareMemorySizeDefault = 1024 * 1024;

type
  PIPCSearchRec = ^TIPCSearchRec;
  TIPCSearchRec = record
    FindID:      Cardinal;
    FindMask:    WideString;
    FindName:    WideString;
    IsServer:    Boolean;
    SessionMask: WideString;
    SessionName: WideString;
    SessionHandle: Cardinal;
  end;
  PIPCEnumRec = ^TIPCEnumRec;
  TIPCEnumRec = record
    EnumID: Cardinal;
    IsServer: Boolean;
    SessionName: WideString;
    SessionHandle: Cardinal;
  end;
  TEnumIPCProc = function (const EnumRec: PIPCEnumRec; Tag: Pointer): LongBool; stdcall;

  IShareMemoryFile = interface
  ['{80F92525-9B87-4ACA-820E-DF63C07C8C27}']
    function GetName: WideString;
    function GetAlreadyExists: Boolean;
    function GetMemory: Pointer;
    function GetSize: Cardinal;
    function GetTag: Pointer;
    function GetTag2: IInterface;
    procedure SetTag(const Value: Pointer);
    procedure SetTag2(const Value: IInterface);

    function Lock(ATimeOut: Cardinal = INFINITE): Boolean;
    procedure Unlock;

    property Name: WideString read GetName;
    property Memory: Pointer read GetMemory;
    property Size: Cardinal read GetSize;
    property AlreadyExists: Boolean read GetAlreadyExists;
    property Tag: Pointer read GetTag write SetTag;
    property Tag2: IInterface read GetTag2 write SetTag2;
  end;

function  IPCServerFindFirst(const ASessionMask: WideString; out F: PIPCSearchRec): Boolean;
function  IPCClientFindFirst(const ASessionMask: WideString; out F: PIPCSearchRec): Boolean;
function  IPCFindNext(var F: PIPCSearchRec): Boolean;
procedure IPCFindClose(var F: PIPCSearchRec);

function EnumIPCServers(const AEnumFunc: TEnumIPCProc; ATag: Pointer): LongBool;
function EnumIPCClients(const ASessionName: WideString; const AEnumFunc: TEnumIPCProc; ATag: Pointer): LongBool;

function SendIPCMessage(
  const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  const AData: Pointer; const ADataLen: Cardinal;
  const ADataType: TIPCMessageDataType = mdtUnknown;
  const ATimeOut: Cardinal = IPC_TIMEOUT;
  const ATopic: Byte = 0): Integer; overload; 
function SendIPCMessage(
  const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  const AData: IIPCMessage; const ATimeOut: Cardinal = IPC_TIMEOUT): Integer; overload;
function SendIPCMessage(const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  const AData: WideString; const ATimeOut: Cardinal = IPC_TIMEOUT): Integer; overload;

function BroadcastIPCServer(const ASenderID: Cardinal; const AData: Pointer;
  const ADataLen: Cardinal; const ADataType: TIPCMessageDataType;
  const ATimeOut: Cardinal = IPC_TIMEOUT; const ATopic: Byte = 0): Integer; overload;
function BroadcastIPCServer(const ASenderID: Cardinal; const AData: IIPCMessage;
  const ATimeOut: Cardinal = IPC_TIMEOUT): Integer; overload;
function BroadcastIPCServer(const ASenderID: Cardinal; const AData: WideString;
  const ATimeOut: Cardinal = IPC_TIMEOUT): Integer; overload;

function GetIPCServerCount: Integer;
function IPCServerExist(const ASessionName: WideString): Boolean;
function IPCClientExist(const AClientID: Cardinal): Boolean;
function GetIPCServerID(const ASessionName: WideString): Cardinal;
function GetIPCServerSessionHandle(const ASessionName: WideString): Cardinal;
function GetIPCServerProcessId(const ASessionName: WideString): Cardinal; overload;
function GetIPCServerProcessId(const AServerID: Cardinal): Cardinal; overload;
function GetIPCClientProcessId(const AClientID: Cardinal): Cardinal;
function GetProcessFileName(const ProcessID: Cardinal): WideString;

function CreateShareMemFile(const AShareName: WideString;
  ASize: Cardinal = ShareMemorySizeDefault;
  ACCESS: Cardinal = FILE_MAP_ALL_ACCESS): IShareMemoryFile;

implementation

uses
  SYIPCImportDef;

function  IPCServerFindFirst(const ASessionMask: WideString; out F: PIPCSearchRec): Boolean;
type
  TIPCServerFindFirst = function  (const ASessionMask: WideString; out F: PIPCSearchRec): Boolean;
begin
  Result := TIPCServerFindFirst(IPCAPI.Funcs[FuncIdx_IPCServerFindFirst])(ASessionMask, F);
end;

function  IPCClientFindFirst(const ASessionMask: WideString; out F: PIPCSearchRec): Boolean;
type
  TIPCClientFindFirst = function  (const ASessionMask: WideString; out F: PIPCSearchRec): Boolean;
begin
  Result := TIPCClientFindFirst(IPCAPI.Funcs[FuncIdx_IPCClientFindFirst])(ASessionMask, F);
end;

function  IPCFindNext(var F: PIPCSearchRec): Boolean;
type
  TIPCFindNext = function (var F: PIPCSearchRec): Boolean;
begin
  Result := TIPCFindNext(IPCAPI.Funcs[FuncIdx_IPCFindNext])(F);
end;

procedure IPCFindClose(var F: PIPCSearchRec);
type
  TIPCFindClose = procedure (var F: PIPCSearchRec);
begin
  TIPCFindClose(IPCAPI.Funcs[FuncIdx_IPCFindClose])(F);
end;

function EnumIPCServers(const AEnumFunc: TEnumIPCProc; ATag: Pointer): LongBool;
type
  TEnumIPCServers = function (const AEnumFunc: TEnumIPCProc; ATag: Pointer): LongBool;
begin
  Result := TEnumIPCServers(IPCAPI.Funcs[FuncIdx_EnumIPCServers])(AEnumFunc, ATag);
end;

function EnumIPCClients(const ASessionName: WideString; const AEnumFunc: TEnumIPCProc; ATag: Pointer): LongBool;
type
  TEnumIPCClients = function (const ASessionName: WideString; const AEnumFunc: TEnumIPCProc; ATag: Pointer): LongBool;
begin
  Result := TEnumIPCClients(IPCAPI.Funcs[FuncIdx_EnumIPCClients])(ASessionName, AEnumFunc, ATag);
end;

function SendIPCMessage(
  const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  const AData: Pointer; const ADataLen: Cardinal;
  const ADataType: TIPCMessageDataType; const ATimeOut: Cardinal;
  const ATopic: Byte): Integer;
type
  TSendIPCMessage = function (
    const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
    const AData: Pointer; const ADataLen: Cardinal;
    const ADataType: TIPCMessageDataType; const ATimeOut: Cardinal;
    const ATopic: Byte): Integer;
begin
  Result := TSendIPCMessage(IPCAPI.Funcs[FuncIdx_SendIPCMessageP])(ASenderID, AID,
    ASessionHandle, AData, ADataLen, ADataType, ATimeOut, ATopic);
end;

function SendIPCMessage(
  const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  const AData: IIPCMessage; const ATimeOut: Cardinal): Integer;
type
  TSendIPCMessage = function (
    const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
    const AData: IIPCMessage; const ATimeOut: Cardinal): Integer;
begin
  Result := TSendIPCMessage(IPCAPI.Funcs[FuncIdx_SendIPCMessageM])(ASenderID, AID,
    ASessionHandle, AData, ATimeOut);
end;

function SendIPCMessage(const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  const AData: WideString; const ATimeOut: Cardinal): Integer;
type
  TSendIPCMessage = function (
    const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
    const AData: WideString; const ATimeOut: Cardinal): Integer;
begin
  Result := TSendIPCMessage(IPCAPI.Funcs[FuncIdx_SendIPCMessageS])(ASenderID, AID,
    ASessionHandle, AData, ATimeOut);
end;

function BroadcastIPCServer(const ASenderID: Cardinal; const AData: Pointer;
  const ADataLen: Cardinal; const ADataType: TIPCMessageDataType;
  const ATimeOut: Cardinal; const ATopic: Byte): Integer;
type
  TBroadcastIPCServer = function (const ASenderID: Cardinal; const AData: Pointer;
    const ADataLen: Cardinal; const ADataType: TIPCMessageDataType;
    const ATimeOut: Cardinal; const ATopic: Byte): Integer;
begin
  Result := TBroadcastIPCServer(IPCAPI.Funcs[FuncIdx_BroadcastIPCServerP])(ASenderID,
    AData, ADataLen, ADataType, ATimeOut, ATopic);
end;

function BroadcastIPCServer(const ASenderID: Cardinal; const AData: IIPCMessage; const ATimeOut: Cardinal): Integer;
type
  TBroadcastIPCServer = function (const ASenderID: Cardinal; const AData: IIPCMessage; const ATimeOut: Cardinal): Integer;
begin
  Result := TBroadcastIPCServer(IPCAPI.Funcs[FuncIdx_BroadcastIPCServerM])(ASenderID, AData, ATimeOut);
end;

function BroadcastIPCServer(const ASenderID: Cardinal; const AData: WideString; const ATimeOut: Cardinal): Integer;
type
  TBroadcastIPCServer = function (const ASenderID: Cardinal; const AData: WideString; const ATimeOut: Cardinal): Integer;
begin
  Result := TBroadcastIPCServer(IPCAPI.Funcs[FuncIdx_BroadcastIPCServerS])(ASenderID, AData, ATimeOut);
end;

function GetIPCServerCount: Integer;
type
  TGetIPCServerCount = function (): Integer;
begin
  Result := TGetIPCServerCount(IPCAPI.Funcs[FuncIdx_GetIPCServerCount]);
end;

function IPCServerExist(const ASessionName: WideString): Boolean;
type
  TIPCServerExist = function (const ASessionName: WideString): Boolean;
begin
  Result := TIPCServerExist(IPCAPI.Funcs[FuncIdx_IPCServerExist])(ASessionName);
end;

function IPCClientExist(const AClientID: Cardinal): Boolean;
type
  TIPCClientExist = function (const AClientID: Cardinal): Boolean;
begin
  Result := TIPCClientExist(IPCAPI.Funcs[FuncIdx_IPCClientExist])(AClientID);
end;

function GetIPCServerID(const ASessionName: WideString): Cardinal;
type
  TGetIPCServerID = function (const ASessionName: WideString): Cardinal;
begin
  Result := TGetIPCServerID(IPCAPI.Funcs[FuncIdx_GetIPCServerID])(ASessionName);
end;

function GetIPCServerSessionHandle(const ASessionName: WideString): Cardinal;
type
  TGetIPCServerSessionHandle = function (const ASessionName: WideString): Cardinal;
begin
  Result := TGetIPCServerSessionHandle(IPCAPI.Funcs[FuncIdx_GetIPCServerSessionHandle])(ASessionName);
end;

function GetIPCServerProcessId(const ASessionName: WideString): Cardinal;
type
  TGetIPCServerProcessId = function (const ASessionName: WideString): Cardinal;
begin
  Result := TGetIPCServerProcessId(IPCAPI.Funcs[FuncIdx_GetIPCServerProcessIdS])(ASessionName);
end;

function GetIPCServerProcessId(const AServerID: Cardinal): Cardinal;
type
  TGetIPCServerProcessId = function (const AServerID: Cardinal): Cardinal;
begin
  Result := TGetIPCServerProcessId(IPCAPI.Funcs[FuncIdx_GetIPCServerProcessIdI])(AServerID);
end;

function GetIPCClientProcessId(const AClientID: Cardinal): Cardinal;
type
  TGetIPCClientProcessId = function (const AClientID: Cardinal): Cardinal;
begin
  Result := TGetIPCClientProcessId(IPCAPI.Funcs[FuncIdx_GetIPCClientProcessId])(AClientID);
end;

function GetProcessFileName(const ProcessID: Cardinal): WideString;
type
  TGetProcessFileName = function(const ProcessID: Cardinal): WideString;
begin
  Result := TGetProcessFileName(IPCAPI.Funcs[FuncIdx_GetProcessFileName])(ProcessID);
end;

function CreateShareMemFile(const AShareName: WideString;
  ASize, ACCESS: Cardinal): IShareMemoryFile;
type
  TCreateShareMemFile = function (const AShareName: WideString; ASize, ACCESS: Cardinal): IShareMemoryFile;
begin
  Result := TCreateShareMemFile(IPCAPI.Funcs[FuncIdx_CreateShareMemFile])(AShareName, ASize, ACCESS);
end;


end.
