unit fpdev.pkg.repository;

{$mode objfpc}{$H+}

{
  TPackageRepositoryService - Package repository management service

  Extracted from TPackageManager to handle repository operations:
  - Add/remove repositories
  - Update repository indexes
  - List repositories
}

interface

uses
  SysUtils, Classes, fpjson, jsonparser, StrUtils,
  fpdev.config.interfaces, fpdev.output.intf,
  fpdev.toolchain.fetcher, fpdev.utils.fs,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TPackageRepositoryService }
  TPackageRepositoryService = class
  private
    FConfigManager: IConfigManager;
    FPackageRegistry: string;

    function SanitizeFileName(const S: string): string;
    function ReadIndexFromURL(const AUrl: string; out AText: string): Boolean;

  public
    constructor Create(AConfigManager: IConfigManager; const APackageRegistry: string);

    function AddRepository(const AName, AURL: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function RemoveRepository(const AName: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function UpdateRepositories(Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function ListRepositories(Outp: IOutput = nil): Boolean;
  end;

implementation

uses
  fphttpclient, openssl;

{ TPackageRepositoryService }

constructor TPackageRepositoryService.Create(AConfigManager: IConfigManager; const APackageRegistry: string);
begin
  inherited Create;
  FConfigManager := AConfigManager;
  FPackageRegistry := APackageRegistry;
end;

function TPackageRepositoryService.SanitizeFileName(const S: string): string;
var
  k: Integer;
  c: Char;
  R: string;
begin
  R := '';
  for k := 1 to Length(S) do
  begin
    c := S[k];
    if (c in ['A'..'Z','a'..'z','0'..'9','_','-','.']) then
      R := R + c
    else
      R := R + '_';
  end;
  Result := R;
end;

function TPackageRepositoryService.ReadIndexFromURL(const AUrl: string; out AText: string): Boolean;
var
  Cli: TFPHTTPClient;
begin
  Result := False;
  AText := '';
  try
    if FileExists(AUrl) then
    begin
      with TStringList.Create do
      try
        LoadFromFile(AUrl);
        AText := Text;
        Result := True;
      finally
        Free;
      end;
    end
    else if (Pos('http://', LowerCase(AUrl)) = 1) or (Pos('https://', LowerCase(AUrl)) = 1) then
    begin
      Cli := TFPHTTPClient.Create(nil);
      try
        AText := Cli.Get(AUrl);
        Result := True;
      finally
        Cli.Free;
      end;
    end;
  except
    // Silently fail on network errors
  end;
end;

function TPackageRepositoryService.AddRepository(const AName, AURL: string; Outp: IOutput; Errp: IOutput): Boolean;
begin
  Result := False;
  try
    Result := FConfigManager.GetRepositoryManager.AddRepository(AName, AURL);
    if Result then
    begin
      if Outp <> nil then
        Outp.WriteLn('Repository added: ' + AName);
    end
    else
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_REPO_ADD_FAILED, [AName]));
    end;
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_EXCEPTION, ['add repository', E.Message]));
      Result := False;
    end;
  end;
end;

function TPackageRepositoryService.RemoveRepository(const AName: string; Outp: IOutput; Errp: IOutput): Boolean;
begin
  Result := False;
  try
    if FConfigManager.GetRepositoryManager.RemoveRepository(AName) then
    begin
      Result := True;
      if Outp <> nil then
        Outp.WriteLn('Repository removed: ' + AName);
    end
    else
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_REPO_REMOVE_FAILED, [AName]));
    end;
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_EXCEPTION, ['remove repository', E.Message]));
      Result := False;
    end;
  end;
end;

function TPackageRepositoryService.UpdateRepositories(Outp: IOutput; Errp: IOutput): Boolean;
var
  Names: TStringArray;
  i, j: Integer;
  RepoURL: string;
  Combined: TJSONArray;
  Err: string;
  CacheDir, IndexPath, TmpPath: string;
  SL: TStringList;
  JSONData: TJSONData = nil;
  Arr: TJSONArray;
  Opt: TFetchOptions;
  URLs: array of string;
  IsFileURL: Boolean;
  LocalFile: string;
begin
  Result := False;
  URLs := nil;
  try
    // Target cache directory and index file
    CacheDir := FPackageRegistry;
    EnsureDir(CacheDir);
    IndexPath := CacheDir + PathDelim + 'index.json';
    TmpPath := CacheDir + PathDelim + 'index.json.tmp';

    Combined := TJSONArray.Create;
    try
      Names := FConfigManager.GetRepositoryManager.ListRepositories;

      for i := 0 to High(Names) do
      begin
        RepoURL := Trim(FConfigManager.GetRepositoryManager.GetRepository(Names[i]));
        if RepoURL = '' then
          Continue;

        // Assume repository URL points directly to JSON index
        if (RightStr(RepoURL, 5) <> '.json') then
          RepoURL := IncludeTrailingPathDelimiter(RepoURL) + 'index.json';

        // Support file:// local index; otherwise use HTTP(S) download
        IsFileURL := (LeftStr(LowerCase(RepoURL), 7) = 'file://');
        SL := TStringList.Create;
        try
          if IsFileURL then
          begin
            LocalFile := Copy(RepoURL, 8, MaxInt);
            // Windows may have file:///C:/... prefix
            while (Length(LocalFile) > 0) and ((LocalFile[1] = '/') or (LocalFile[1] = '\')) do
              Delete(LocalFile, 1, 1);
            LocalFile := StringReplace(LocalFile, '/', PathDelim, [rfReplaceAll]);
            if FileExists(LocalFile) then
              SL.LoadFromFile(LocalFile)
            else
              Continue;
          end
          else
          begin
            // Download to temp file
            SetLength(URLs, 1);
            URLs[0] := RepoURL;
            Opt.DestDir := CacheDir;
            Opt.SHA256 := '';
            Opt.TimeoutMS := 15000;
            if not EnsureDownloadedCached(URLs, TmpPath, Opt.SHA256, Opt.TimeoutMS, Err) then
              Continue;
            SL.LoadFromFile(TmpPath);
          end;

          // Read and merge packages array
          JSONData := GetJSON(SL.Text);
          Arr := nil;
          if JSONData.JSONType = jtArray then
            Arr := TJSONArray(JSONData)
          else if (JSONData.JSONType = jtObject) and Assigned(TJSONObject(JSONData).Arrays['packages']) then
            Arr := TJSONObject(JSONData).Arrays['packages'];

          if Arr <> nil then
          begin
            // Merge into Combined: clone each element
            for j := 0 to Arr.Count - 1 do
              Combined.Add(Arr.Items[j].Clone as TJSONData);
          end
          else
          begin
            // If object without packages array, try treating object as single package info
            if JSONData.JSONType = jtObject then
              Combined.Add(JSONData.Clone as TJSONData);
          end;
        finally
          if Assigned(JSONData) then
            JSONData.Free;
          SL.Free;
        end;
      end;

      // Write Combined to index.json
      SL := TStringList.Create;
      try
        SL.Text := Combined.FormatJSON;
        SL.SaveToFile(IndexPath);
      finally
        SL.Free;
      end;

      if Outp <> nil then
        Outp.WriteLn('Repository index updated: ' + IndexPath);
      Result := True;
    finally
      Combined.Free;
    end;
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_REPO_UPDATE_FAILED, [E.Message]));
      Result := False;
    end;
  end;
end;

function TPackageRepositoryService.ListRepositories(Outp: IOutput): Boolean;
var
  Names: TStringArray;
  i: Integer;
  URL: string;
begin
  Result := True;
  try
    Names := FConfigManager.GetRepositoryManager.ListRepositories;

    if Length(Names) = 0 then
      Exit(True);

    for i := 0 to High(Names) do
    begin
      URL := FConfigManager.GetRepositoryManager.GetRepository(Names[i]);
      if Outp <> nil then
        Outp.WriteLn(Names[i] + ' = ' + URL);
    end;
  except
    on E: Exception do
      Result := False;
  end;
end;

end.
