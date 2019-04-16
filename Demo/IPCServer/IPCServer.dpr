program IPCServer;

uses
 {$IF CompilerVersion >= 18.5}
  SimpleShareMem,
 {$ELSE}
  FastMM4,
 {$IFEND}
  Forms,
  Unit2 in 'Unit2.pas' {Form2},
  SYIPCIntf in '..\..\Public\SYIPCIntf.pas';

{$R *.res}
{$R UAC.res}

begin
 {$IF CompilerVersion >= 18.5}
   ReportMemoryLeaksOnShutdown := True;
 {$IFEND};

  Application.Initialize;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
