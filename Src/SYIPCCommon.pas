unit SYIPCCommon;

interface

uses
  Windows, SysUtils, Variants, Classes, SYIPCIntf;

const
  IPCServerDisconneting = 'IPCServerDisconneting';
  IPCClientDisconneting = 'IPCClientDisconneting';
  IPCConnectRequest     = 'IPCConnectRequest';
  IPCConnectRespose     = 'IPCConnectRespose';

  IPCWindowClassName               = 'SYIPCWindowClass.6E51CD65FF7F';
  IPCWindowNameServerPrefix        = 'syipc.ipcserver.h:00000000.s:';
  IPCWindowNameServerHandlePrefix  = 'syipc.ipcserver.h:';
  IPCWindowNameServerHandleLength  =  8;
  IPCWindowNameServerFmt           = 'syipc.ipcserver.h:%.8d.s:%s';
  IPCWindowNameServerMask          = 'syipc.ipcserver.h:[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].s:%s';
  
  IPCWindowNameClientPrefix        = 'syipc.ipcclient.h:00000000.s:';
  IPCWindowNameClientHandlePrefix  = 'syipc.ipcclient.h:';
  IPCWindowNameClientHandleLength  =  8;
  IPCWindowNameClientFmt           = 'syipc.ipcclient.h:%.8d.s:%s';
  IPCWindowNameClientMask          = 'syipc.ipcclient.h:[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].s:%s';

  IPCMethod_MethodExist            = 'syipc.internalmethod.methodexist';

  IPCConnectCheckInterval          = 500;

  IPCSessionTableName              = 'syipc.sessiontable';
  
type
  ESYIPCExection = class(Exception);
  EOleError = class(Exception);

  PMethod = ^TMethod;
  PIPCMessageStruct = ^TIPCMessageStruct;
  TIPCMessageStruct = record
    Sender:   TObject;
    State:    TIPCState;
    SenderID: Cardinal;
    Message:  IIPCMessage;
  end;

type
  PSYIPCData = ^TSYIPCData;
  TSYIPCData = packed record
    Size:  Cardinal;
    Type_: TIPCMessageDataType;
    { Data: Pointer; }
  end;
  PSYIPCParams = ^TSYIPCParams;
  TSYIPCParams = packed record
    Length: Cardinal;
    { Data: TSYIPCData; }
  end;
  PSYIPCCallMethod = ^TSYIPCCallMethod;
  TSYIPCCallMethod = packed record
    ResTopic: Byte;
    MethodName: array[0..IPC_CALLMETHOD_SIZE] of WideChar;
    Params: TSYIPCParams;
  end;
  PSYIPCCallReturn = ^TSYIPCCallReturn;
  TSYIPCCallReturn = packed record
    ResTopic: Byte;
    Data: TSYIPCData; 
  end;

function  AllocateIPCHWnd(const Method: TWndMethod; const AWindowName: WideString): HWND;
procedure DeallocateIPCHWnd(const Wnd: HWND);

function SendMessageTimeout(hWnd: HWND; Msg: UINT; wParam: WPARAM;
  lParam: LPARAM; uTimeout: UINT): LRESULT;
procedure AllowMeesageForVistaAbove(uMessageID: Cardinal; bAllow: Boolean);

function _DispatchMethodExist(const Dispatch: IDispatch; const MethodName: WideString): Boolean;
function _DispatchInvoke(const Dispatch: IDispatch; const MethodName: WideString;
  const AParams: array of OleVariant): OleVariant;

implementation

type
  TDispID = Longint;
  POleStr = PWideChar;
const
  GUID_NULL: TGUID = '{00000000-0000-0000-0000-000000000000}';
type
  PVariantArgList = ^TVariantArgList;
  TVariantArgList = array[0..65535] of TVarData;

  PDispIDList = ^TDispIDList;
  TDispIDList = array[0..65535] of TDispID;
  
  PDispParams = ^TDispParams;
  tagDISPPARAMS = record
    rgvarg: PVariantArgList;
    rgdispidNamedArgs: PDispIDList;
    cArgs: Longint;
    cNamedArgs: Longint;
  end;
  TDispParams = tagDISPPARAMS;
  DISPPARAMS = TDispParams;
  
  PExcepInfo = ^TExcepInfo;
  TFNDeferredFillIn = function(ExInfo: PExcepInfo): HResult stdcall;
  tagEXCEPINFO = record
    wCode: Word;
    wReserved: Word;
    bstrSource: WideString;
    bstrDescription: WideString;
    bstrHelpFile: WideString;
    dwHelpContext: Longint;
    pvReserved: Pointer;
    pfnDeferredFillIn: TFNDeferredFillIn;
    scode: HResult;
  end;
  TExcepInfo = tagEXCEPINFO;

var
  SYIPCWindowClass: TWndClass = (
    style: 0;
    lpfnWndProc: @DefWindowProc;
    cbClsExtra: 0;
    cbWndExtra: 0;
    hInstance: 0;
    hIcon: 0;
    hCursor: 0;
    hbrBackground: 0;
    lpszMenuName: nil;
    lpszClassName: IPCWindowClassName
  );

function  AllocateIPCHWnd(const Method: TWndMethod; const AWindowName: WideString): HWND;
var
  TempClass: TWndClass;
  ClassRegistered: Boolean;
begin
  ClassRegistered := GetClassInfo(HInstance, IPCWindowClassName, TempClass);
  if not ClassRegistered or (TempClass.lpfnWndProc <> @DefWindowProc) then
  begin
    if ClassRegistered then
      Windows.UnregisterClass(IPCWindowClassName, HInstance);
    SYIPCWindowClass.hInstance  := HInstance;
    Windows.RegisterClass(SYIPCWindowClass);
  end;
  Result := CreateWindowExW(WS_EX_TOOLWINDOW, IPCWindowClassName,
    PWideChar(AWindowName), WS_POPUP {!0}, 0, 0, 0, 0, 0, 0, HInstance, nil);
  if Assigned(Method) then
    SetWindowLong(Result, GWL_WNDPROC, Longint(MakeObjectInstance(Method)));
end;

procedure DeallocateIPCHWnd(const Wnd: HWND);
begin
  Classes.DeallocateHWnd(Wnd);
end;

function SendMessageTimeout(hWnd: HWND; Msg: UINT; wParam: WPARAM;
  lParam: LPARAM; uTimeout: UINT): LRESULT;
var
  dwResult: {$IF CompilerVersion > 18.5}DWORD_PTR{$ELSE}DWORD{$IFEND};
begin
  {$IF CompilerVersion > 18.5}
  Result := Windows.SendMessageTimeout(hWnd, Msg, wParam, lParam, SMTO_NORMAL or SMTO_ABORTIFHUNG, uTimeout, @dwResult);
  {$ELSE}
  Result := Windows.SendMessageTimeout(hWnd, Msg, wParam, lParam, SMTO_NORMAL or SMTO_ABORTIFHUNG, uTimeout, dwResult);
  {$IFEND}
end;

var
  ChangeWindowMessageFilter: function(msg: UINT; dwFlag: DWORD): BOOL; stdcall;
procedure AllowMeesageForVistaAbove(uMessageID: Cardinal; bAllow: Boolean);
var
  hUserMod: Cardinal;
begin
  if @ChangeWindowMessageFilter = nil then
  begin
    hUserMod := GetModuleHandle('user32.dll');
    if hUserMod = 0  then
      Exit;
    @ChangeWindowMessageFilter := GetProcAddress(hUserMod,'ChangeWindowMessageFilter');
    if @ChangeWindowMessageFilter = nil then
      Exit;
  end;
  if bAllow then
    ChangeWindowMessageFilter(uMessageID, 1)
  else
    ChangeWindowMessageFilter(uMessageID, 2); //MSGFLT_ADD: 1, MSGFLT_REMOVE: 2
end;

procedure OleCheck(Result: HResult);
begin
  if not Succeeded(Result) then
    raise ESYIPCExection.Create(SysErrorMessage(Result));
end;
  
function _DispatchMethodExist(const Dispatch: IDispatch; const MethodName: WideString): Boolean;
var
  pDispIds: array[0..0] of TDispID;
  pNames: array[0..0] of POleStr;
begin
  pNames[0] := PWideChar(MethodName);
  Result := Succeeded(Dispatch.GetIDsOfNames(GUID_NULL, @pNames, 1, LOCALE_USER_DEFAULT, @pDispIds));
end;

function _DispatchInvoke(const Dispatch: IDispatch; const MethodName: WideString;
  const AParams: array of OleVariant): OleVariant;
const
  INVOKE_FUNC           = 1;
var
  Argc: integer;
  ArgErr: integer;
  ExcepInfo: TExcepInfo;
  Flags: Word;
  i: integer;
  j: integer;
  Params: DISPPARAMS;
  pArgs: PVariantArgList;
  pDispIds: array[0..0] of TDispID;
  pNames: array[0..0] of POleStr;
  VarResult: Variant;
begin
  Result := Unassigned;
  Flags := INVOKE_FUNC;
  Argc := High(AParams) + 1;
  if Argc < 0 then Argc := 0;
  // Method DISPID
  pNames[0] := PWideChar(MethodName);
  OleCheck(Dispatch.GetIDsOfNames(GUID_NULL, @pNames, 1, LOCALE_USER_DEFAULT, @pDispIds));
  try
    GetMem(pArgs, sizeof(TVarData) * Argc);
    try
      j := 0;
      for i := High(AParams) downto Low(AParams) do
      begin
        pArgs[j] := TVarData(AParams[i]);
        j := j + 1;
      end;
      Params.rgvarg := pArgs;
      Params.cArgs := Argc;
      params.cNamedArgs := 0;
      params.rgdispidNamedArgs := nil;
      OleCheck(Dispatch.Invoke(pDispIds[0], GUID_NULL, LOCALE_USER_DEFAULT, Flags, TDispParams(Params), @VarResult, @ExcepInfo, @ArgErr));
      Result := VarResult;
    finally
      FreeMem(pArgs, sizeof(TVarData) * Argc);
    end;
  except
    on E: EOleError do
    begin
      raise ESYIPCExection.CreateFmt('OLE Error code %d: %s', [ExcepInfo.wCode, ExcepInfo.bstrDescription]);
    end;
  end;
end;

end.
