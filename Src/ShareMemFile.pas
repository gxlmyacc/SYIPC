unit ShareMemFile;

interface

uses
  SysUtils, Windows, SYIPCUtils;

type
  TShareMemoryFile = class(TInterfacedObject, IShareMemoryFile)
  private
    FName: WideString;
    FMemory: Pointer;
    FSize: Cardinal;
    FFile: THandle;
    FEvent: THandle;
    FAlreadyExists: Boolean;
    FTag: Pointer;
    FTag2: IInterface;
  protected
    function GetName: WideString;
    function GetAlreadyExists: Boolean;
    function GetMemory: Pointer;
    function GetSize: Cardinal;
    function GetTag: Pointer;
    function GetTag2: IInterface;
    procedure SetTag(const Value: Pointer);
    procedure SetTag2(const Value: IInterface);
  public
    constructor Create(const ShareName: WideString;
      ASize: Cardinal = ShareMemorySizeDefault;
      ACCESS: Cardinal = FILE_MAP_ALL_ACCESS);
    destructor Destroy; override;

    function Lock(ATimeOut: Cardinal = INFINITE): Boolean;
    procedure Unlock;

    property Name: WideString read GetName;
    property Memory: Pointer read GetMemory;
    property Size: Cardinal read GetSize;
    property AlreadyExists: Boolean read GetAlreadyExists;
    property Tag: Pointer read GetTag write SetTag;
    property Tag2: IInterface read GetTag2 write SetTag2;
  end;

implementation

procedure InitSecAttr(var sa: TSecurityAttributes; var sd: TSecurityDescriptor);
begin
  sa.nLength := sizeOf(sa);
  sa.lpSecurityDescriptor := @sd;
  sa.bInheritHandle := False;
  InitializeSecurityDescriptor(@sd, SECURITY_DESCRIPTOR_REVISION);
  SetSecurityDescriptorDacl(@sd, True, nil, False);
end;

{ TShareMemoryFile }

constructor TShareMemoryFile.Create(const ShareName: WideString; ASize, ACCESS: Cardinal);
var
  sa: TSecurityAttributes;
  sd: TSecurityDescriptor;
  lProtect: Cardinal;
begin
  FName := ShareName;
  FSize := ASize;

  FEvent := CreateEventW(nil, True, True, PWideChar('sharememoryfile.' + FName));
  Assert(FEvent<>0, SysErrorMessage(GetLastError));
  
  InitSecAttr(sa, sd);
  ACCESS := ACCESS and (not SECTION_MAP_EXECUTE);
  lProtect := PAGE_READWRITE;
  if (ACCESS and FILE_MAP_WRITE) = FILE_MAP_WRITE then
    lProtect := PAGE_READWRITE
  else
  if (ACCESS and FILE_MAP_READ) = FILE_MAP_READ then
    lProtect := PAGE_READONLY
  else
  if (ACCESS and FILE_MAP_COPY) = FILE_MAP_COPY then
    lProtect := PAGE_WRITECOPY;

  FFile := CreateFileMappingW(INVALID_HANDLE_VALUE, @sa, lProtect, 0, FSize, PWideChar(FName));
  Assert(FFile<>0, SysErrorMessage(GetLastError));
  FAlreadyExists := GetLastError = ERROR_ALREADY_EXISTS;

  FMemory := MapViewOfFile(FFile, ACCESS, 0, 0, 0);
  Assert(FMemory<>nil, SysErrorMessage(GetLastError));
  if not FAlreadyExists then
    ZeroMemory(FMemory, FSize);
end;

destructor TShareMemoryFile.Destroy;
begin
  if FMemory <> nil then
  begin
    UnmapViewOfFile(FMemory);
    FMemory := nil;
    FSize := 0;
  end;
  if FFile <> 0 then
  begin
    CloseHandle(FFile);
    FFile := 0;
  end;
  if FEvent <> 0 then
  begin
    CloseHandle(FEvent);
    FEvent := 0;
  end;
  inherited;
end;


function TShareMemoryFile.GetAlreadyExists: Boolean;
begin
  Result := FAlreadyExists;
end;

function TShareMemoryFile.GetMemory: Pointer;
begin
  Result := FMemory;
end;

function TShareMemoryFile.GetName: WideString;
begin
  Result := FName;
end;

function TShareMemoryFile.GetSize: Cardinal;
begin
  Result := FSize;
end;

function TShareMemoryFile.GetTag: Pointer;
begin
  Result := FTag;
end;

function TShareMemoryFile.GetTag2: IInterface;
begin
  Result := FTag2;
end;

function TShareMemoryFile.Lock(ATimeOut: Cardinal): Boolean;
begin
  Result := WaitForSingleObject(FEvent, ATimeOut) = WAIT_OBJECT_0;
  if Result then
    ResetEvent(FEvent);
end;

procedure TShareMemoryFile.SetTag(const Value: Pointer);
begin
  FTag := Value;
end;

procedure TShareMemoryFile.SetTag2(const Value: IInterface);
begin
  FTag2 := Value;
end;

procedure TShareMemoryFile.Unlock;
begin
  Windows.SetEvent(FEvent);
end;

end.
