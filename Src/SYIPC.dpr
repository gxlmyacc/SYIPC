library SYIPC;

{$IF CompilerVersion >= 18.5}
{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$IFEND}

uses
  ShareFastMM in 'ShareFastMM.pas',
  SYIPCIntf in '..\Public\SYIPCIntf.pas',
  SYIPCUtils in '..\Public\SYIPCUtils.pas',
  SYIPCImportDef in '..\Public\SYIPCImportDef.pas',
  SYIPCExportDef in 'SYIPCExportDef.pas',
  SYIPCMasks in 'SYIPCMasks.pas',
  SYIPCCommon in 'SYIPCCommon.pas',
  SYIPCMessage in 'SYIPCMessage.pas',
  SYIPCBase in 'SYIPCBase.pas',
  SYIPCClient in 'SYIPCClient.pas',
  SYIPCServer in 'SYIPCServer.pas',
  SYIPCUtilsImpl in 'SYIPCUtilsImpl.pas',
  SYIPCMessageLoop in 'SYIPCMessageLoop.pas',
  SYIPCMessageQueue in 'SYIPCMessageQueue.pas',
  ShareMemFile in 'ShareMemFile.pas';

{$R *.res}

begin

end.
