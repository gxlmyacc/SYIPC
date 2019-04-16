unit SYIPCExportDef;

interface

uses
  Windows, SYIPCImportDef;

var
  varApi: TSYIPCApi;

procedure _RegIPCClass;
procedure _UnregIPCClass;
procedure _InitIPCApi(const Api: PPointer; const Instance: HINST);
procedure _FinalIPCApi(const Api: PPointer; const Instance: HINST);


implementation

uses
  SYIPCUtilsImpl;

var
  varWC: TWndClassA;

procedure _RegIPCClass;
begin
  varApi.Flags      := 'IPC';
  varApi.Instance   := SysInit.HInstance;
  varApi.InitProc   := _InitIPCApi;
  varApi.FinalProc  := _FinalIPCApi;
  varApi.FuncsCount := SYIPC_FuncsCount;
  SetLength(varApi.Funcs, SYIPC_FuncsCount);
  varApi.Funcs[FuncIdx_CreateIPCServer]          := @__CreateIPCServer;
  varApi.Funcs[FuncIdx_CreateIPCClient]          := @__CreateIPCClient;
  varApi.Funcs[FuncIdx_CreateIPCMessage]         := @__CreateIPCMessage;
  varApi.Funcs[FuncIdx_CreateIPCMessageReadOnly] := @__CreateIPCMessageReadOnly;
  varApi.Funcs[FuncIdx_IPCServerFindFirst]       := @__IPCServerFindFirst;
  varApi.Funcs[FuncIdx_IPCClientFindFirst]       := @__IPCClientFindFirst;
  varApi.Funcs[FuncIdx_IPCFindNext]              := @__IPCFindNext;
  varApi.Funcs[FuncIdx_IPCFindClose]             := @__IPCFindClose;
  varApi.Funcs[FuncIdx_EnumIPCServers]           := @__EnumIPCServers;
  varApi.Funcs[FuncIdx_EnumIPCClients]           := @__EnumIPCClients;
  varApi.Funcs[FuncIdx_SendIPCMessageP]          := @__SendIPCMessageP;
  varApi.Funcs[FuncIdx_SendIPCMessageM]          := @__SendIPCMessageM;
  varApi.Funcs[FuncIdx_SendIPCMessageS]          := @__SendIPCMessageS;
  varApi.Funcs[FuncIdx_BroadcastIPCServerP]      := @__BroadcastIPCServerP;
  varApi.Funcs[FuncIdx_BroadcastIPCServerM]      := @__BroadcastIPCServerM;
  varApi.Funcs[FuncIdx_BroadcastIPCServerS]      := @__BroadcastIPCServerS;
  varApi.Funcs[FuncIdx_GetIPCServerCount]        := @__GetIPCServerCount;
  varApi.Funcs[FuncIdx_IPCServerExist]           := @__IPCServerExist;
  varApi.Funcs[FuncIdx_IPCClientExist]           := @__IPCClientExist;
  varApi.Funcs[FuncIdx_GetIPCServerID]           := @__GetIPCServerID;
  varApi.Funcs[FuncIdx_GetIPCServerSessionHandle]:= @__GetIPCServerSessionHandle;
  varApi.Funcs[FuncIdx_GetIPCServerProcessIdS]   := @__GetIPCServerProcessIdS;
  varApi.Funcs[FuncIdx_GetIPCServerProcessIdI]   := @__GetIPCServerProcessIdI;
  varApi.Funcs[FuncIdx_GetIPCClientProcessId]    := @__GetIPCClientProcessId;
  varApi.Funcs[FuncIdx_GetProcessFileName]       := @__GetProcessFileName;
  varApi.Funcs[FuncIdx_CreateShareMemFile]       := @__CreateShareMemFile;
                                                
  FillChar(varWC, SizeOf(varWC), 0);
  varWC.lpszClassName := CLASSNAME_SYIPC;
  varWC.style         := CS_GLOBALCLASS;
  varWC.hInstance     := SysInit.HInstance;
  varWC.lpfnWndProc   := @varApi;
  if Windows.RegisterClassA(varWC)=0 then
    Halt;
end;

procedure _UnregIPCClass;
begin
  Windows.UnregisterClassA(CLASSNAME_SYIPC, SysInit.HInstance);
end;

procedure _InitIPCApi(const Api: PPointer; const Instance: HINST);
begin

end;

procedure _FinalIPCApi(const Api: PPointer; const Instance: HINST);
begin

end;

initialization
  _RegIPCClass;

finalization
  _UnregIPCClass;

end.
