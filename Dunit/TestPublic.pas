unit TestPublic;

interface

uses
  Classes, Windows, SysUtils;

procedure StrSaveToFile(const AStr, AFileName: string);
procedure EmptyDirectory(ADir: string; ARecursive: Boolean = True);
procedure CopyDirectory(ASourceDir, ATargetDir: string);
procedure DirFileToList(ADir: string; const AList: TStrings; AMask: string = '*.*');

implementation

uses
  Masks;

procedure StrSaveToFile(const AStr, AFileName: string);
var
  ss: TStringStream;
  fs: TFileStream;
begin
  ss := TStringStream.Create(AStr);
  fs := TFileStream.Create(AFileName, fmCreate or fmOpenWrite);
  try
    ss.Position := 0;
    fs.CopyFrom(ss, ss.Size);
  finally
    ss.Free;
    fs.Free;
  end;   
end;

procedure EmptyDirectory(ADir: string; ARecursive: Boolean = True);
var
  SearchRec: TSearchRec;
  Res: Integer;
begin
  if ADir = EmptyStr then Exit;
  
  ADir := IncludeTrailingPathDelimiter(ADir);
  Res := FindFirst(ADir + '*.*', faAnyFile, SearchRec);
  try
    while Res = 0 do
    begin
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        if ((SearchRec.Attr and faDirectory) > 0) and ARecursive then
        begin
          EmptyDirectory(ADir + SearchRec.Name, True);
          RemoveDirectory(PChar(string(ADir + SearchRec.Name)));
        end
        else
        begin
          DeleteFile(PChar(string(ADir + SearchRec.Name)))
        end;
      end;
      Res := FindNext(SearchRec);
    end;
  finally
    FindClose(SearchRec);
  end;
end;

procedure CopyDirectory(ASourceDir, ATargetDir: string);
var
  LFileList: TStrings;
  i: Integer;
  sTargetFile, sSourceFile: string;
begin
  LFileList := TStringList.Create;
  try
    DirFileToList(ASourceDir, LFileList);
    for i := 0 to LFileList.Count -1 do
    begin
      sSourceFile := LFileList[i];
      sTargetFile := StringReplace(sSourceFile, ASourceDir, ATargetDir, [rfReplaceAll, rfIgnoreCase]);
      ForceDirectories(ExtractFileDir(sTargetFile));
      CopyFile(PChar(sSourceFile), PChar(sTargetFile), False);
    end;
  finally
    LFileList.Free;
  end;   
end;

procedure DirFileToList(ADir: string; const AList: TStrings; AMask: string = '*.*');
var
  fileName: TFileName;
  oSearchRec: TSearchRec;
  dirPathList: TStringList;
  nDirIndex: integer;
  procedure CheckDirectorySuffix(var ADirPath: string);
  begin
    if Copy(ADirPath, Length(ADirPath), 1) <> '\' then
      ADirPath := ADirPath + '\'
    else
      ADirPath := ADirPath;
  end;
begin
  if ADir = '' then
    Exit;
  if not DirectoryExists(ADir) then
    Exit;
  ADir := IncludeTrailingPathDelimiter(ADir);

  dirPathList := TStringList.Create;
  try
    if FindFirst(ADir + '*.*', faAnyFile, oSearchRec) = 0 then
    begin
      repeat
        fileName := oSearchRec.Name;
        if (fileName = '.') or (fileName = '..') then
          continue;

        //处理目录
        if (oSearchRec.Attr and faDirectory) <> 0 then
        begin
          dirPathList.Add(fileName);
          continue;
        end;

        //处理文件
        if MatchesMask(fileName, AMask) then
          AList.Add(ADir + fileName);
      until FindNext(oSearchRec) <> 0;
      FindClose(oSearchRec);

      //递归遍历所有的子目录
      for nDirIndex := 0 to dirPathList.Count - 1 do
        DirFileToList(ADir + dirPathList[nDirIndex], AList, AMask);
    end;
  finally
    dirPathList.Free;
  end;
end;

end.
