unit SYIPCImportDef;

interface

const
  DLL_SYIPC        = 'SYIPC.dll';
  CLASSNAME_SYIPC  = 'guoxl.syipc.class';

  SYIPC_FuncsCount                  = 26;

  //function CreateIPCServer: IIPCServer;
  FuncIdx_CreateIPCServer           =  0;
  //function CreateIPCClient: IIPCClient;
  FuncIdx_CreateIPCClient           =  1;
  //function CreateIPCMessage(const ADataType: TIPCMessageDataType): IIPCMessage;
  FuncIdx_CreateIPCMessage          =  2;
  //function CreateIPCMessageReadOnly(const AData: TMessageData; const ADataSize: Cardinal; const ADataType: TIPCMessageDataType): IIPCMessage;
  FuncIdx_CreateIPCMessageReadOnly  =  3;
  //function  IPCServerFindFirst(const ASessionMask: WideString; out F: PIPCSearchRec): Boolean;
  FuncIdx_IPCServerFindFirst        =  4;
  //function  IPCClientFindFirst(const ASessionMask: WideString; out F: PIPCSearchRec): Boolean;
  FuncIdx_IPCClientFindFirst        =  5;
  //function  IPCFindNext(var F: PIPCSearchRec): Boolean;
  FuncIdx_IPCFindNext               =  6;
  //procedure IPCFindClose(var F: PIPCSearchRec);
  FuncIdx_IPCFindClose              =  7;
  //function EnumIPCServers(const AEnumFunc: TEnumIPCProc; ATag: Pointer): LongBool;
  FuncIdx_EnumIPCServers            =  8;
  //function EnumIPCClients(const ASessionName: WideString; const AEnumFunc: TEnumIPCProc; ATag: Pointer): LongBool;
  FuncIdx_EnumIPCClients            =  9;
  //function SendIPCMessage(const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  //  const AData: Pointer; const ADataLen: Cardinal;
  //  const ADataType: TIPCMessageDataType; const ATimeOut: Cardinal;
  //  const ATopic: Byte): Integer; 
  FuncIdx_SendIPCMessageP           = 10;
  //function SendIPCMessage(
  //  const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  //  const AData: IIPCMessage; const ATimeOut: Cardinal): Integer; overload;
  FuncIdx_SendIPCMessageM           = 11;
  //function SendIPCMessage(const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  //  const AData: WideString; const ATimeOut: Cardinal): Integer; overload;
  FuncIdx_SendIPCMessageS           = 12;
  //function BroadcastIPCServer(const ASenderID: Cardinal; const AData: Pointer;
  //  const ADataLen: Cardinal; const ADataType: TIPCMessageDataType;
  //  const ATimeOut: Cardinal; const ATopic: Byte): Integer;
  FuncIdx_BroadcastIPCServerP       = 13;
  //function BroadcastIPCServer(const ASenderID: Cardinal; const AData: IIPCMessage; const ATimeOut: Cardinal): Integer;
  FuncIdx_BroadcastIPCServerM       = 14;
  //function BroadcastIPCServer(const ASenderID: Cardinal; const AData: WideString; const ATimeOut: Cardinal): Integer;
  FuncIdx_BroadcastIPCServerS       = 15;
  //function GetIPCServerCount: Integer;
  FuncIdx_GetIPCServerCount         = 16;
  //function IPCServerExist(const ASessionName: WideString): Boolean;
  FuncIdx_IPCServerExist            = 17;
  //function IPCClientExist(const AClientID: Cardinal): Boolean;
  FuncIdx_IPCClientExist            = 18;
  //function GetIPCServerID(const ASessionName: WideString): Cardinal;
  FuncIdx_GetIPCServerID            = 19;
  //function GetIPCServerSessionHandle(const ASessionName: WideString): Cardinal;
  FuncIdx_GetIPCServerSessionHandle = 20;
  //function GetIPCServerProcessId(const ASessionName: WideString): Cardinal;
  FuncIdx_GetIPCServerProcessIdS    = 21;
  //function GetIPCServerProcessId(const ASessionName: WideString): Cardinal;
  FuncIdx_GetIPCServerProcessIdI    = 22;
  //function GetIPCClientProcessId(const AClientID: Cardinal): Cardinal;
  FuncIdx_GetIPCClientProcessId     = 23;
  //function GetProcessFileName(const ProcessID: Cardinal): WideString;
  FuncIdx_GetProcessFileName        = 24;
  //function CreateShareMemFile(const ShareName: WideString; ASize, ACCESS: Cardinal): IShareMemoryFile;
  FuncIdx_CreateShareMemFile        = 25;
  
type
  PDynPointerArray = ^TDynPointerArray;
  TDynPointerArray = array of Pointer;

  PPSYIPCApi = ^PSYIPCApi;
  PSYIPCApi = ^TSYIPCApi;
  TSYIPCApi = record
    Flags: array[0..2] of AnsiChar;
    Instance: HMODULE;
    InitProc: procedure (const Api: PPointer; const Instance: HINST);
    FinalProc: procedure (const Api: PPointer; const Instance: HINST);
    FuncsCount: Integer;
    Funcs: TDynPointerArray;
  end;

function IPCEnabled: Boolean;
function IPCAPI: PSYIPCApi;

{$IFNDEF SYIPC}
function  LoadSYIPC(const ADllPath: string = DLL_SYIPC): Boolean;
procedure UnloadSYIPC;
{$ENDIF}

implementation


uses
{$IFDEF SYIPC}
  SYIPCExportDef;
{$ELSE}
  SysUtils, Windows;
{$ENDIF}

var
  varApi: PSYIPCApi = nil;
{$IFNDEF SYIPC}
  varDLLHandle: THandle;
{$ENDIF}

function IPCEnabled: Boolean;
begin
  Result := varApi <> nil;
end;

function IPCAPI: PSYIPCApi;
begin
  Result := varApi;
end;

{$IFNDEF SYIPC}
function  LoadSYIPC(const ADllPath: string): Boolean;
var
  wc: TWndClassA;
begin
  Result := False;
  try
    if IPCEnabled then
    begin
      Result := True;
      Exit;
    end;
    if GetClassInfoA(SysInit.HInstance, CLASSNAME_SYIPC, wc) then
    begin
      varApi := PSYIPCApi(wc.lpfnWndProc);
      varApi.InitProc(@varApi, SysInit.HInstance);
      Result := True;
      Exit;
    end;
    if not FileExists(ADllPath) then
    begin
      OutputDebugString(PChar('[' + ADllPath + ']加载失败：['+ADllPath+']不存在！'));
      Exit;
    end;
    varDLLHandle := LoadLibrary(PChar(ADllPath));
    if varDLLHandle < 32 then
    begin
      OutputDebugString(PChar('[' + ADllPath + ']加载失败：'+ SysErrorMessage(GetLastError)));
      Exit;
    end;
    try
      if GetClassInfoA(SysInit.HInstance, CLASSNAME_SYIPC, wc) then
      begin
        varApi := PSYIPCApi(wc.lpfnWndProc);
        varApi.InitProc(@varApi, SysInit.HInstance);
      end
      else
      begin
        OutputDebugString(PChar('[' + ADllPath + ']加载失败：未找到全局注册信息！'));
        Exit;
      end;
      Result := True;
    finally
      if not Result then
      begin
        FreeLibrary(varDLLHandle);
        varDLLHandle := 0;
      end;
    end;
  except
    on E: Exception do
      OutputDebugString(PChar('[LoadSYIPC]'+E.Message));
  end;
end;

procedure UnloadSYIPC;
begin
  try
    if varDLLHandle > 0 then
    begin
      if varApi <> nil then
      try
        varApi.FinalProc(@varApi, SysInit.HInstance);
      except
        on E: Exception do
          OutputDebugString(PChar('[UnloadSYIPC]'+E.Message));
      end;
      varApi := nil;
      FreeLibrary(varDLLHandle);
      varDLLHandle := 0;
    end;
  except
    on E: Exception do
    begin
      OutputDebugString(PChar('[UnloadSYIPC]'+E.Message));
    end
  end;
end;
{$ENDIF}

initialization
{$IFDEF SYIPC}
  varApi := @SYIPCExportDef.varApi;
{$ELSE}
  if FileExists(DLL_SYIPC) then
    LoadSYIPC(DLL_SYIPC);
{$ENDIF}

finalization
{$IFDEF SYIPC}
{$ELSE}
  UnloadSYIPC;
{$ENDIF}

end.
