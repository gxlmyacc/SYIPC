unit SYIPCUtilsImpl;

interface

uses
  SysUtils, Windows, Messages, SYIPCIntf, SYIPCUtils;

function __CreateIPCServer: IIPCServer;
function __CreateIPCClient: IIPCClient;
function __CreateIPCMessage(const ADataType: TIPCMessageDataType): IIPCMessage;
function __CreateIPCMessageReadOnly(const AData: TMessageData;
  const ADataSize: Cardinal; const ADataType: TIPCMessageDataType): IIPCMessage;

function GetIPCServerName(const ASessionName: WideString; const ASessionHandle: Cardinal): WideString;
function GetIPCClientName(const ASessionName: WideString; const ASessionHandle: Cardinal): WideString;

function  ___IPCFindFirst(const ASessionMask: WideString; out F: PIPCSearchRec; const bIsServer: Boolean): Boolean;
function  __IPCServerFindFirst(const ASessionMask: WideString; out F: PIPCSearchRec): Boolean;
function  __IPCClientFindFirst(const ASessionMask: WideString; out F: PIPCSearchRec): Boolean;
function  __IPCFindNext(var F: PIPCSearchRec): Boolean;
procedure __IPCFindClose(var F: PIPCSearchRec);

function __EnumIPCServers(const AEnumFunc: TEnumIPCProc; ATag: Pointer): LongBool;
function __EnumIPCClients(const ASessionName: WideString; const AEnumFunc: TEnumIPCProc; ATag: Pointer): LongBool;

function __SendIPCMessageP(
  const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  const AData: Pointer; const ADataLen: Cardinal;
  const ADataType: TIPCMessageDataType; const ATimeOut: Cardinal;
  const ATopic: Byte): Integer; 
function __SendIPCMessageM(
  const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  const AData: IIPCMessage; const ATimeOut: Cardinal): Integer;
function __SendIPCMessageS(const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  const AData: WideString; const ATimeOut: Cardinal): Integer;

function __BroadcastIPCServerM(const ASenderID: Cardinal; const AData: IIPCMessage; const ATimeOut: Cardinal): Integer;
function __BroadcastIPCServerP(const ASenderID: Cardinal; const AData: Pointer;
  const ADataLen: Cardinal; const ADataType: TIPCMessageDataType;
  const ATimeOut: Cardinal; const ATopic: Byte): Integer;
function __BroadcastIPCServerS(const ASenderID: Cardinal; const AData: WideString; const ATimeOut: Cardinal): Integer;

function __GetIPCServerCount: Integer;
function __IPCServerExist(const ASessionName: WideString): Boolean;
function __IPCClientExist(const AClientID: Cardinal): Boolean;
function __GetIPCServerID(const ASessionName: WideString): Cardinal;
function __GetIPCServerSessionHandle(const ASessionName: WideString): Cardinal;
function __GetIPCServerProcessIdS(const ASessionName: WideString): Cardinal;
function __GetIPCServerProcessIdI(const AServerID: Cardinal): Cardinal;
function __GetIPCClientProcessId(const AClientID: Cardinal): Cardinal;
function __GetProcessFileName(const ProcessID: Cardinal): WideString;

function __CreateShareMemFile(const ShareName: WideString; ASize, ACCESS: Cardinal): IShareMemoryFile;
           
implementation

uses
  SYIPCCommon, SYIPCClient, SYIPCServer, SYIPCMasks, SYIPCMessage, ShareMemFile;

function EnumProcessModules(hProcess: THandle; lphModule: LPDWORD; cb: DWORD;
  var lpcbNeeded: DWORD): BOOL stdcall; external 'PSAPI.dll';
function GetModuleFileNameExW(hProcess: THandle; hModule: HMODULE;
    lpFilename: PWideChar; nSize: DWORD): DWORD stdcall; external 'PSAPI.dll';

function __CreateIPCServer: IIPCServer;
begin
  Result := TIPCServer.Create;
end;

function __CreateIPCClient: IIPCClient;
begin
  Result := TIPCClient.Create;
end;

function __CreateIPCMessage(const ADataType: TIPCMessageDataType): IIPCMessage;
begin
  Result := TIPCMessage.Create(nil, ADataType);
end;

function __CreateIPCMessageReadOnly(const AData: TMessageData;
  const ADataSize: Cardinal; const ADataType: TIPCMessageDataType): IIPCMessage;
begin
  Result := TIPCMessage.CreateReadOnly(nil, AData, ADataSize, ADataType, 0);
end;

function GetIPCServerName(const ASessionName: WideString; const ASessionHandle: Cardinal): WideString;
begin
  Result := WideFormat(IPCWindowNameServerFmt, [ASessionHandle, ASessionName]);
end;

function GetIPCClientName(const ASessionName: WideString; const ASessionHandle: Cardinal): WideString;
begin
  Result := WideFormat(IPCWindowNameClientFmt, [ASessionHandle, ASessionName]);
end;

function  ___IPCFindFirst(const ASessionMask: WideString; out F: PIPCSearchRec; const bIsServer: Boolean): Boolean;
var
  hFindHandle: Cardinal;
  bufWindowName: PWideChar;
  LMask: TMask;
begin
  Result := False;
  F := nil;   
  hFindHandle := FindWindowA(IPCWindowClassName, nil);
  if hFindHandle = 0 then
    Exit;
  bufWindowName := AllocMem(256 * IPC_CHAR_SIZE);
  LMask := TMask.Create(ASessionMask);
  try
    while hFindHandle <> 0 do
    begin
      if GetWindowTextW(hFindHandle, bufWindowName, 256) > 0 then
      begin
        Result := LMask.Matches(bufWindowName);
        if Result then
        begin
          New(F);
          F.FindMask   := ASessionMask;
          F.FindName   := bufWindowName;
          F.FindID     := hFindHandle;
          F.IsServer := bIsServer;
          if bIsServer then
          begin
            F.SessionName := Copy(F.FindName, Length(IPCWindowNameClientPrefix)+1, MaxInt);
            F.SessionHandle := StrToInt(Copy(F.FindName, Length(IPCWindowNameServerHandlePrefix)+1, IPCWindowNameServerHandleLength));
          end
          else
          begin
            F.SessionName := Copy(F.FindName, Length(IPCWindowNameClientPrefix)+1, MaxInt);
            F.SessionHandle := StrToInt(Copy(F.FindName, Length(IPCWindowNameClientHandlePrefix)+1, IPCWindowNameClientHandleLength));
          end;
          Exit;
        end;     
      end;
      hFindHandle := FindWindowExW(0, hFindHandle, IPCWindowClassName, nil);
    end;
  finally
    LMask.Free;
    FreeMem(bufWindowName);
  end;
end;

function  __IPCServerFindFirst(const ASessionMask: WideString; out F: PIPCSearchRec): Boolean;
begin
  Result := ___IPCFindFirst(WideFormat(IPCWindowNameServerMask, [ASessionMask]), F, True);
  if Result then
  begin
    F.SessionMask := ASessionMask;
  end;
end;

function  __IPCClientFindFirst(const ASessionMask: WideString; out F: PIPCSearchRec): Boolean;
begin
  Result := ___IPCFindFirst(WideFormat(IPCWindowNameClientMask, [ASessionMask]), F, False);
  if Result then
  begin
    F.SessionMask := ASessionMask;
  end;
end;

function  __IPCFindNext(var F: PIPCSearchRec): Boolean;
var
  hFindHandle: Cardinal;
  bufWindowName: PWideChar;
  LMask: TMask;
begin
  Result := False;
  if F = nil then
    Exit;
  hFindHandle := FindWindowExW(0, F.FindID, IPCWindowClassName, nil);
  bufWindowName := AllocMem(256 * IPC_CHAR_SIZE);
  LMask := TMask.Create(F.FindMask);
  try
    while hFindHandle <> 0 do
    begin
      if GetWindowTextW(hFindHandle, bufWindowName, 256) > 0 then
      begin
        Result := LMask.Matches(bufWindowName);
        if Result then
        begin
          F.FindID     := hFindHandle;
          F.FindName   := bufWindowName;
          if F.IsServer then
          begin
            F.SessionName := Copy(F.FindName, Length(IPCWindowNameClientPrefix)+1, MaxInt);
            F.SessionHandle := StrToInt(Copy(F.FindName, Length(IPCWindowNameServerHandlePrefix)+1, IPCWindowNameServerHandleLength));
          end
          else
          begin
            F.SessionName := Copy(F.FindName, Length(IPCWindowNameClientPrefix)+1, MaxInt);
            F.SessionHandle := StrToInt(Copy(F.FindName, Length(IPCWindowNameClientHandlePrefix)+1, IPCWindowNameClientHandleLength));          
          end;
          Exit;
        end;
      end;
      hFindHandle := FindWindowExW(0, hFindHandle, IPCWindowClassName, nil);
    end;
  finally
    LMask.Free;
    FreeMem(bufWindowName);
  end;
end;

procedure __IPCFindClose(var F: PIPCSearchRec);
begin
  if F = nil then
    Exit;
  Dispose(F);
  F := nil;
end;

function __EnumIPCServers(const AEnumFunc: TEnumIPCProc; ATag: Pointer): LongBool;
var
  F: PIPCSearchRec;
  LEnumRec: TIPCEnumRec;
begin
  Result := IPCServerFindFirst('*', F);
  if not Result then
    Exit;
  try
    repeat
      LEnumRec.EnumID        := F.FindID;
      LEnumRec.IsServer      := F.IsServer;
      LEnumRec.SessionName   := F.SessionName;
      LEnumRec.SessionHandle := F.SessionHandle;
      if not AEnumFunc(@LEnumRec, ATag) then
        Exit;
    until not IPCFindNext(F);
  finally
    IPCFindClose(F);
  end;
end;

function __EnumIPCClients(const ASessionName: WideString; const AEnumFunc: TEnumIPCProc; ATag: Pointer): LongBool;
var
  F: PIPCSearchRec;
  LEnumRec: TIPCEnumRec;
begin
  Result := IPCClientFindFirst(ASessionName, F);
  if not Result then
    Exit;
  try
    repeat
      LEnumRec.EnumID        := F.FindID;
      LEnumRec.IsServer      := F.IsServer;
      LEnumRec.SessionName   := F.SessionName;
      LEnumRec.SessionHandle := F.SessionHandle;
      if not AEnumFunc(@LEnumRec, ATag) then
        Exit;
    until not IPCFindNext(F);
  finally
    IPCFindClose(F);
  end;
end;

function __SendIPCMessageP(
  const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  const AData: Pointer; const ADataLen: Cardinal;
  const ADataType: TIPCMessageDataType; const ATimeOut: Cardinal; const ATopic: Byte): Integer;
var
  LCopyData: TCopyDataStruct;
  WParamHi: Word;
  w: array[0..1] of Byte absolute WParamHi;
begin
  Assert(AID <> 0);
  LCopyData.dwData := ASenderID;
  LCopyData.lpData := AData;
  LCopyData.cbData := ADataLen;
  w[0] := Byte(ADataType);
  w[1] := ATopic;
  if ATimeOut <= 0 then
    Result := SendMessage(AID, WM_COPYDATA, MakeWParam(ASessionHandle, WParamHi), lParam(@LCopyData))
  else
    Result := SendMessageTimeout(AID, WM_COPYDATA, MakeWParam(ASessionHandle, WParamHi),
      lParam(@LCopyData), ATimeOut);
end;

function __SendIPCMessageM(
  const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  const AData: IIPCMessage; const ATimeOut: Cardinal): Integer;
begin
  Result := __SendIPCMessageP(ASenderID, AID, ASessionHandle, AData.Data,
    AData.DataSize, AData.DataType, ATimeOut, AData.Topic);
end;
function __SendIPCMessageS(const ASenderID, AID: Cardinal; const ASessionHandle: Cardinal;
  const AData: WideString; const ATimeOut: Cardinal): Integer;
begin
  Result := __SendIPCMessageP(ASenderID, AID, ASessionHandle, PWideChar(AData),
    Length(AData) * IPC_CHAR_SIZE, mdtString, ATimeOut, 0);
end;

function __BroadcastIPCServerM(const ASenderID: Cardinal; const AData: IIPCMessage; const ATimeOut: Cardinal): Integer;
begin
  Result := __BroadcastIPCServerP(ASenderID, AData.Data, AData.DataSize, AData.DataType, ATimeOut, AData.Topic);
end;

function __BroadcastIPCServerP(const ASenderID: Cardinal; const AData: Pointer;
  const ADataLen: Cardinal; const ADataType: TIPCMessageDataType;
  const ATimeOut: Cardinal; const ATopic: Byte): Integer;
var
  F: PIPCSearchRec;
  tick: Cardinal;
begin
  Result := 1;
  if not IPCServerFindFirst('*', F) then
    Exit;
  try
    tick := GetTickCount;
    repeat
      __SendIPCMessageP(ASenderID, F.FindID, F.SessionHandle, AData, ADataLen, ADataType, ATimeOut, ATopic);
      if GetTickCount - tick > ATimeOut then
      begin
        Result := 0;
        Exit;
      end;
    until not IPCFindNext(F);
  finally
    IPCFindClose(F);
  end;
end;

function __BroadcastIPCServerS(const ASenderID: Cardinal; const AData: WideString; const ATimeOut: Cardinal): Integer;
begin
  Result := __BroadcastIPCServerP(ASenderID, PWideChar(AData), Length(AData) * IPC_CHAR_SIZE, mdtString, ATimeOut, 0);
end;

function __GetIPCServerCount: Integer;
var
  F: PIPCSearchRec;
begin
  Result := 0;
  if __IPCServerFindFirst('*', F) then
  try
    repeat
      Result := Result + 1;
    until not __IPCFindNext(F);
  finally
    __IPCFindClose(F);
  end;
end;

function __IPCServerExist(const ASessionName: WideString): Boolean;
var
  F: PIPCSearchRec;
begin
  Result := __IPCServerFindFirst(ASessionName, F);
  if Result then
    __IPCFindClose(F);
end;

function __IPCClientExist(const AClientID: Cardinal): Boolean;
begin
  Result := IsWindow(AClientID);
end;

function __GetIPCServerID(const ASessionName: WideString): Cardinal;
var
  F: PIPCSearchRec;
begin
  if __IPCServerFindFirst(ASessionName, F) then
  try
    Result := F.FindID;
  finally
    __IPCFindClose(F);
  end
  else
    Result := 0;
end;

function __GetIPCServerSessionHandle(const ASessionName: WideString): Cardinal;
var
  F: PIPCSearchRec;
begin
  if __IPCServerFindFirst(ASessionName, F) then
  try
    Result := F.SessionHandle;
  finally
    __IPCFindClose(F);
  end
  else
    Result := 0;
end;

function __GetIPCServerProcessIdS(const ASessionName: WideString): Cardinal;
var
  F: PIPCSearchRec;
begin
  if __IPCServerFindFirst(ASessionName, F) then
  try
    GetWindowThreadProcessId(F.FindID, @Result);
  finally
    __IPCFindClose(F);
  end
  else
    Result := 0;
end;

function __GetIPCServerProcessIdI(const AServerID: Cardinal): Cardinal;
begin
  GetWindowThreadProcessId(AServerID, @Result);
end;

function __GetIPCClientProcessId(const AClientID: Cardinal): Cardinal;
begin
  GetWindowThreadProcessId(AClientID, @Result);
end;

function __GetProcessFileName(const ProcessID: Cardinal): WideString;
var
  Hand: THandle;
  ModName: array[0..Max_Path-1] of WideChar;
  hMod: HModule;
  n: DWORD;
begin
  Result := '';
  Hand := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ,False,ProcessID);
  if Hand > 0 then
  begin
    EnumProcessModules(Hand, @hMod, Sizeof(hMod), n);
    if GetModuleFileNameExW(Hand, hMod, ModName, Sizeof(ModName))>0 then
      Result := ModName;
    CloseHandle(Hand);
  end;
end;

function __CreateShareMemFile(const ShareName: WideString; ASize, ACCESS: Cardinal): IShareMemoryFile;
begin
  Result := TShareMemoryFile.Create(ShareName, ASize, ACCESS);
end;


end.
