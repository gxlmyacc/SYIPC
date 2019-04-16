program IPCClient;

uses
 {$IF CompilerVersion >= 18.5}
  SimpleShareMem,
 {$ELSE}
  FastMM4,
 {$IFEND}
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  SYIPCIntf in '..\..\Public\SYIPCIntf.pas',
  IPCServerTest in 'IPCServerTest.pas';

{$R *.res}
{.$R UAC.res}

begin
 {$IF CompilerVersion >= 18.5}
   ReportMemoryLeaksOnShutdown := True;
 {$IFEND};

  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
