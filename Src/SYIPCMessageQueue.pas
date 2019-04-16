unit SYIPCMessageQueue;

interface

uses
  Classes, SYIPCIntf;

type
  TIPCMessageQueue = class(TInterfacedObject, IIPCMessageQueue)
  private
    FList: TThreadList;
  protected
    function  GetCount: Integer;
    function  GetItem(const Index: Integer): IIPCMessage;
  public
    constructor Create();
    destructor Destroy; override;
    
    function  Push(const AItem: IIPCMessage): Integer;
    function  Pop(out AItem: IIPCMessage): Boolean;
    function  Peek: IIPCMessage;
    procedure Clear;

    property Count: Integer read GetCount;
    property Item[const Index: Integer]: IIPCMessage read GetItem; default;
  end;


implementation

{ TIPCMessageQueue }

procedure TIPCMessageQueue.Clear;
var
  I: Integer;
begin
  if FList <> nil then
  begin
    with FList.LockList do
    try
      for I := 0 to Count - 1 do
        IInterface(List[I]) := nil;
      Clear;
    finally
      Self.FList.UnlockList;
    end;
  end;
end;

constructor TIPCMessageQueue.Create;
begin
  FList := TThreadList.Create;
end;

destructor TIPCMessageQueue.Destroy;
begin
  Clear;
  FList.Free;
  inherited;
end;

function TIPCMessageQueue.GetCount: Integer;
begin
  with FList.LockList do
  try
    Result := Count;
  finally
    Self.FList.UnlockList;
  end;
end;

function TIPCMessageQueue.GetItem(const Index: Integer): IIPCMessage;
begin
  with FList.LockList do
  try
    if (Index < 0) or (Index >= Count) then
      Result := nil
    else
      Result := IIPCMessage(List[Index]);
  finally
    Self.FList.UnlockList;
  end;
end;

function TIPCMessageQueue.Peek: IIPCMessage;
begin
  with FList.LockList do
  try
    if Count > 0 then
      Result := nil
    else
      Result := IIPCMessage(List[0]);
  finally
    Self.FList.UnlockList;
  end;
end;

function TIPCMessageQueue.Pop(out AItem: IIPCMessage): Boolean;
begin
  with FList.LockList do
  try
    Result := Count > 0;
    if Result then
    begin
      AItem := IIPCMessage(List[0]);
      IIPCMessage(List[0]) := nil;
      Delete(0);      
    end
    else
      AItem := nil;
  finally
    Self.FList.UnlockList;
  end;
end;

function TIPCMessageQueue.Push(const AItem: IIPCMessage): Integer;
begin
  Assert(AItem<>nil);
  with FList.LockList do
  try
    Result := Add(nil);
    IIPCMessage(List[Result]) := AItem;
  finally
    Self.FList.UnlockList;
  end;
end;

end.
