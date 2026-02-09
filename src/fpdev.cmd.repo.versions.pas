unit fpdev.cmd.repo.versions;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, DateUtils, fpjson, jsonparser, fphttpclient, openssl,
  fpdev.command.intf, fpdev.command.registry, fpdev.config.interfaces,
  fpdev.toolchain.manifest, fpdev.utils.fs,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TRepoVersionsCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TRepoVersionsCommand.Name: string; begin Result := 'versions'; end;
function TRepoVersionsCommand.Aliases: TStringArray; begin Result := nil; end;
function TRepoVersionsCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TRepoVersionsCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
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
  FTime: TDateTime;

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

  function ReadManifestFromPathOrHttp(const PathOrURL: string; out AText: string): Boolean;
  begin
    Result := False; AText := '';
    try
      if FileExists(PathOrURL) then
      begin
        with TStringList.Create do
        try
          LoadFromFile(PathOrURL);
          AText := Text;
          Result := True;
        finally
          Free;
        end;
      end
      else if (Pos('http://', LowerCase(PathOrURL))=1) or (Pos('https://', LowerCase(PathOrURL))=1) then
      begin
        Cli := TFPHTTPClient.Create(nil);
        try
          AText := Cli.Get(PathOrURL);
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
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_REPO));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_OS));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_ARCH));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_JSON));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_OFFLINE));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_REFRESH));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_HELP));
    Exit(EXIT_OK);
  end;

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
      Settings := Ctx.Config.GetSettingsManager.GetSettings;
      if Settings.DefaultRepo<>'' then RepoArg := Settings.DefaultRepo;
    end;

    if RepoArg<>'' then
    begin
      // 直接 URL 或 名称
      if Pos('http', LowerCase(RepoArg))=1 then URL := RepoArg else URL := Ctx.Config.GetRepositoryManager.GetRepository(RepoArg);
      if URL='' then
      begin
        Ctx.Err.WriteLn(_Fmt(CMD_REPO_NOT_FOUND, [RepoArg]));
        Exit(EXIT_USAGE_ERROR);
      end;
      // 计算缓存文件
      CacheDir := IncludeTrailingPathDelimiter(Ctx.Config.GetSettingsManager.GetSettings.InstallRoot) + 'cache' + PathDelim + 'repos';
      if not DirectoryExists(CacheDir) then EnsureDir(CacheDir);
      CacheFile := IncludeTrailingPathDelimiter(CacheDir) + SanitizeFileName(URL) + '.json';

      if Offline and FileExists(CacheFile) then
      begin
        SL := TStringList.Create; try SL.LoadFromFile(CacheFile); S := SL.Text; finally SL.Free; end;
      end
      else if (not Refresh) and FileExists(CacheFile) and (FileAge(CacheFile, FTime)) and (Now - FTime < 1) then
      begin
        // 缓存小于24小时
        SL := TStringList.Create; try SL.LoadFromFile(CacheFile); S := SL.Text; finally SL.Free; end;
      end
      else
      begin
        if not Offline then
        begin
          if not ReadManifestFromPathOrHttp(URL, S) then
          begin
            Ctx.Err.WriteLn(_Fmt(CMD_REPO_VERSIONS_FAILED, [URL]));
            Exit(EXIT_NOT_FOUND);
          end;
          // 写缓存
          with TStringList.Create do
          try
            Text := S; SaveToFile(CacheFile);
          finally
            Free;
          end;
        end
        else
        begin
          Ctx.Err.WriteLn(_Fmt(CMD_REPO_VERSIONS_OFFLINE_NO_CACHE, [URL]));
          Exit(EXIT_NOT_FOUND);
        end;
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
        else
        begin
          Ctx.Err.WriteLn(_Fmt(CMD_REPO_VERSIONS_PARSE_FAILED, [URL]));
          Exit(EXIT_ALREADY_EXISTS);
        end;
      end;
    end
    else
    begin
      // 遍历配置里的所有仓库
      Names := Ctx.Config.GetRepositoryManager.ListRepositories;
      for j := 0 to High(Names) do
      begin
        RepoName := Names[j]; URL := Ctx.Config.GetRepositoryManager.GetRepository(RepoName);
        if URL='' then Continue;
        CacheDir := IncludeTrailingPathDelimiter(Ctx.Config.GetSettingsManager.GetSettings.InstallRoot) + 'cache' + PathDelim + 'repos';
        if not DirectoryExists(CacheDir) then EnsureDir(CacheDir);
        CacheFile := IncludeTrailingPathDelimiter(CacheDir) + SanitizeFileName(URL) + '.json';

        S := '';
        if Offline and FileExists(CacheFile) then
        begin
          SL := TStringList.Create; try SL.LoadFromFile(CacheFile); S := SL.Text; finally SL.Free; end;
        end
        else if (not Refresh) and FileExists(CacheFile) and (FileAge(CacheFile, FTime)) and (Now - FTime < 1) then
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
      Ctx.Out.Write('{"versions":[');
      Count := 0;
      for i := 0 to VersSet.Count-1 do
      begin
        if (Limit>0) and (Count>=Limit) then Break;
        if Count>0 then Ctx.Out.Write(',');
        Ctx.Out.Write('"' + VersSet[i] + '"');
        Inc(Count);
      end;
      Ctx.Out.WriteLn('],"count":' + IntToStr(Count) + '}');
    end
    else
    begin
      Count := 0;
      for i := 0 to VersSet.Count-1 do
      begin
        if (Limit>0) and (Count>=Limit) then Break;
        Ctx.Out.WriteLn(VersSet[i]);
        Inc(Count);
      end;
    end;
  finally
    VersSet.Free;
  end;
end;

function RepoVersionsFactory: ICommand;
begin
  Result := TRepoVersionsCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['repo','versions'], @RepoVersionsFactory, []);

end.
