unit IPCServerTest;

interface

uses
  SYIPCServerProxy, StdCtrls;

type
  TIPCServerTest = class(TIPCServerProxy)
  public
    constructor Create(const ASessionName: WideString);
    
    function ShowMessage(const AMsg: WideString): Boolean;
  end;

function CreateIPCServerTest(const ASessionName: WideString): TIPCServerTest;

implementation

function CreateIPCServerTest(const ASessionName: WideString): TIPCServerTest;
begin
  Result := TIPCServerTest.Create(ASessionName);
end;

{ TIPCServerTest }

constructor TIPCServerTest.Create(const ASessionName: WideString);
begin
  inherited Create(ASessionName);
end;

function TIPCServerTest.ShowMessage(const AMsg: WideString): Boolean;
begin
  Result := Client.Call('ShowMessage', [AMsg]).B;
end;

end.
