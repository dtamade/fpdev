unit fpdev.cmd.repo.versions;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, DateUtils, fpjson, jsonparser, fphttpclient, openssl,
  fpdev.command.intf, fpdev.command.registry, fpdev.config,
  fpdev.toolchain.manifest, fpdev.paths;

type
  TRepoVersionsCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

function TRepoVersionsCommand.Name: string; begin Result := 'versions'; end;
function TRepoVersionsCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TRepoVersionsCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

function GetFlagValue(const Params: array of string; const Key: string; out Value: string): Boolean;
var i,p: Integer; s,k: string;
begin
  Result := False; Value := '';
  k := '--'+Key+'=';
  for i := Low(Params) to High(Params) do begin s:=Params[i]; p:=Pos(k,s); if p=1 then begin Value:=Copy(s,Length(k)+1,MaxInt); Exit(True); end; end;
end;

function HasFlag(const Params: array of string; const Flag: string): Boolean;
var i: Integer;
begin
  Result := False;
  for i := Low(Params) to High(Params) do
    if (Params[i]='--'+Flag) or (Params[i]='-'+Flag) then Exit(True);
end;

procedure TRepoVersionsCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  RepoArg, OsArg, ArchArg, LimitStr: string;
  AsJson, Offline, Refresh: Boolean;
  Limit, i, Count: Integer;
  Names: TStringArray;
  RepoName, URL: string;
  SL: TStringList;
  M: TManifest;
  VersSet: TStringList;
  j: Integer;
  S: string;
  Cli: TFPHTTPClient;
  Settings: TFPDevSettings;
  CacheDir, CacheFile: string;
  FTime: Longint;

  function SanitizeFileName(const S: string): string;
  var k: Integer; c: Char; R: string;
  begin
    R := '';
    for k := 1 to Length(S) do
    begin
      c := S[k];
      if (c in ['A'..'Z','a'..'z','0'..'9','_','-','.']) then R := R + c else R := R + '_';
    end;
    Result := R;
  end;

  function ReadManifestFromPathOrHttp(const PathOrURL: string; out Text: string): Boolean;
  begin
    Result := False; Text := '';
    try
      if FileExists(PathOrURL) then
      begin
        with TStringList.Create do
        try
          LoadFromFile(PathOrURL);
          Text := Self.Text;
          Result := True;
        finally
          Free;
        end;
      end
      else if (Pos('http://', LowerCase(PathOrURL))=1) or (Pos('https://', LowerCase(PathOrURL))=1) then
      begin
        Cli := TFPHTTPClient.Create(nil);
        try
          Text := Cli.Get(PathOrURL);
          Result := True;
        finally
          Cli.Free;
        end;
      end;
    except
      Exit;
    end;
  end;
begin
  GetFlagValue(AParams, 'repo', RepoArg);
  GetFlagValue(AParams, 'os', OsArg);
  GetFlagValue(AParams, 'arch', ArchArg);
  AsJson := HasFlag(AParams, 'json');
  Offline := HasFlag(AParams, 'offline');
  Refresh := HasFlag(AParams, 'refresh');
  if not GetFlagValue(AParams, 'limit', LimitStr) then LimitStr := '';
  Limit := StrToIntDef(LimitStr, 0);

  VersSet := TStringList.Create;
  VersSet.Sorted := True; VersSet.Duplicates := dupIgnore;
  try
    // 默认仓库优先
    if RepoArg='' then
    begin
      Settings := Ctx.Config.GetSettings;
      if Settings.DefaultRepo<>'' then RepoArg := Settings.DefaultRepo;
    end;

    if RepoArg<>'' then
    begin
      // 直接 URL 或 名称
      if Pos('http', LowerCase(RepoArg))=1 then URL := RepoArg else URL := Ctx.Config.GetRepository(RepoArg);
      if URL='' then Exit; // 未找到
      // 计算缓存文件
      CacheDir := IncludeTrailingPathDelimiter(Ctx.Config.GetSettings.InstallRoot) + 'cache' + PathDelim + 'repos';
      if not DirectoryExists(CacheDir) then ForceDirectories(CacheDir);
      CacheFile := IncludeTrailingPathDelimiter(CacheDir) + SanitizeFileName(URL) + '.json';

      if Offline and FileExists(CacheFile) then
      begin
        SL := TStringList.Create; try SL.LoadFromFile(CacheFile); S := SL.Text; finally SL.Free; end;
      end
      else if (not Refresh) and FileExists(CacheFile) and (FileAge(CacheFile, FTime)) and (Now - FileDateToDateTime(FTime) < 1) then
      begin
        // 缓存小于24小时
        SL := TStringList.Create; try SL.LoadFromFile(CacheFile); S := SL.Text; finally SL.Free; end;
      end
      else
      begin
        if not Offline then
        begin
          if not ReadManifestFromPathOrHttp(URL, S) then begin ExitCode := 10; Exit; end;
          // 写缓存
          with TStringList.Create do
          try
            Text := S; SaveToFile(CacheFile);
          finally
            Free;
          end;
        end
        else begin ExitCode := 10; Exit; end;
      end;

      if S<>'' then
      begin
        if ParseManifestJSON(S, M) then
        begin
          for i := 0 to High(M.Components) do
            if SameText(M.Components[i].Name, 'fpc') then
              if ((OsArg='') or SameText(M.Components[i].OS, LowerCase(OsArg))) and
                 ((ArchArg='') or SameText(M.Components[i].Arch, LowerCase(ArchArg))) then
                VersSet.Add(M.Components[i].Version);
        end
        else begin ExitCode := 11; Exit; end;
      end;
    end
    else
    begin
      // 遍历配置里的所有仓库
      Names := Ctx.Config.ListRepositories;
      for j := 0 to High(Names) do
      begin
        RepoName := Names[j]; URL := Ctx.Config.GetRepository(RepoName);
        if URL='' then Continue;
        CacheDir := IncludeTrailingPathDelimiter(Ctx.Config.GetSettings.InstallRoot) + 'cache' + PathDelim + 'repos';
        if not DirectoryExists(CacheDir) then ForceDirectories(CacheDir);
        CacheFile := IncludeTrailingPathDelimiter(CacheDir) + SanitizeFileName(URL) + '.json';

        S := '';
        if Offline and FileExists(CacheFile) then
        begin
          SL := TStringList.Create; try SL.LoadFromFile(CacheFile); S := SL.Text; finally SL.Free; end;
        end
        else if (not Refresh) and FileExists(CacheFile) and (FileAge(CacheFile, FTime)) and (Now - FileDateToDateTime(FTime) < 1) then
        begin
          SL := TStringList.Create; try SL.LoadFromFile(CacheFile); S := SL.Text; finally SL.Free; end;
        end
        else if not Offline then
        begin
          if not ReadManifestFromPathOrHttp(URL, S) then Continue;
          with TStringList.Create do
          try Text := S; SaveToFile(CacheFile); finally Free; end;
        end;

        if S<>'' then
          if ParseManifestJSON(S, M) then
          begin
            for i := 0 to High(M.Components) do
              if SameText(M.Components[i].Name, 'fpc') then
                if ((OsArg='') or SameText(M.Components[i].OS, LowerCase(OsArg))) and
                   ((ArchArg='') or SameText(M.Components[i].Arch, LowerCase(ArchArg))) then
                  VersSet.Add(M.Components[i].Version);
          end;
      end;
    end;

    // 输出
    if AsJson then
    begin
      Write('{"items":[');
      Count := 0;
      for i := 0 to VersSet.Count-1 do
      begin
        if (Limit>0) and (Count>=Limit) then Break;
        if Count>0 then Write(',');
        Write('{"version":"', VersSet[i], '"}');
        Inc(Count);
      end;
      WriteLn(']}');
    end
    else
    begin
      Count := 0;
      for i := 0 to VersSet.Count-1 do
      begin
        if (Limit>0) and (Count>=Limit) then Break;
        WriteLn(VersSet[i]);
        Inc(Count);
      end;
    end;
  finally
    VersSet.Free;
  end;
end;

function RepoVersionsFactory: IFpdevCommand;
begin
  Result := TRepoVersionsCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['repo','versions'], @RepoVersionsFactory, []);

end.
