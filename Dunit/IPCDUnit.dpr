// Uncomment the following directive to create a console application
// or leave commented to create a GUI application... 
// {$APPTYPE CONSOLE}

program IPCDUnit;

uses
 {$IF CompilerVersion >= 18.5}
  SimpleShareMem,
 {$ELSE}
  FastMM4,
 {$IFEND}
  SysUtils,
  TestFramework {$IFDEF LINUX},
  QForms,
  QGUITestRunner {$ELSE},
  Forms,
  GUITestRunner {$ENDIF},
  TextTestRunner,
  SYIPCIntf in '..\Public\SYIPCIntf.pas',
  IPCTests in 'IPCTests.pas',
  TestPublic in 'TestPublic.pas';

{$R *.RES}

begin
 {$IF CompilerVersion >= 18.5}
   ReportMemoryLeaksOnShutdown := True;
 {$IFEND};

  Application.Initialize;

  {$IF CompilerVersion >= 18.5}
   Application.MainFormOnTaskBar := True;
 {$IFEND};

{$IFDEF LINUX}
  QGUITestRunner.RunRegisteredTests;
{$ELSE}
  if System.IsConsole then
    TextTestRunner.RunRegisteredTests
  else
    GUITestRunner.RunRegisteredTests;
{$ENDIF}

end.

 