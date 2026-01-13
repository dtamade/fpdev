program fpdev;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  Classes,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.toolchain,
  fpdev.toolchain.manifest,
  fpdev.toolchain.fetcher,
  fpdev.toolchain.extract,
  fpdev.paths,
  fpdev.source, // ensure-source/import-bundle 将使用

  fpdev.cmd.help,
  fpdev.cmd.help.root,
  fpdev.cmd.version,
  fpdev.cmd.fpc,
  fpdev.cmd.lazarus,
  fpdev.cmd.cross,
  fpdev.cmd.project,

  // Force reference: FPC/Lazarus subcommand objects (ensure initialization registration)
  fpdev.cmd.fpc.root,
  fpdev.cmd.fpc.install,
  fpdev.cmd.fpc.list,
  fpdev.cmd.fpc.use,
  fpdev.cmd.fpc.doctor,
  fpdev.cmd.fpc.current,
  fpdev.cmd.fpc.show,
  fpdev.cmd.fpc.test,
  fpdev.cmd.fpc.update,
  fpdev.cmd.fpc.uninstall,
  fpdev.cmd.fpc.help,

  // Repo commands
  fpdev.cmd.repo.root,
  fpdev.cmd.repo.add,
  fpdev.cmd.repo.list,
  fpdev.cmd.repo.remove,
  fpdev.cmd.repo.default,
  fpdev.cmd.repo.show,
  fpdev.cmd.repo.versions,
  fpdev.cmd.repo.help,

  // Lazarus commands
  fpdev.cmd.lazarus.root,
  fpdev.cmd.lazarus.list,
  fpdev.cmd.lazarus.current,
  fpdev.cmd.lazarus.use,
  fpdev.cmd.lazarus.run,
  fpdev.cmd.lazarus.test,
  fpdev.cmd.lazarus.install,
  fpdev.cmd.lazarus.uninstall,
  fpdev.cmd.lazarus.show,
  fpdev.cmd.lazarus.configure,
  fpdev.cmd.lazarus.doctor,
  fpdev.cmd.lazarus.update,
  fpdev.cmd.lazarus.help,

  // Cross commands
  fpdev.cmd.cross.root,
  fpdev.cmd.cross.list,
  fpdev.cmd.cross.show,
  fpdev.cmd.cross.enable,
  fpdev.cmd.cross.disable,
  fpdev.cmd.cross.test,
  fpdev.cmd.cross.install,
  fpdev.cmd.cross.uninstall,
  fpdev.cmd.cross.configure,
  fpdev.cmd.cross.doctor,
  fpdev.cmd.cross.help,

  // Package commands
  fpdev.cmd.package.root,
  fpdev.cmd.package.install,
  fpdev.cmd.package.list,
  fpdev.cmd.package.search,
  fpdev.cmd.package.info,
  fpdev.cmd.package.uninstall,
  fpdev.cmd.package.update,
  fpdev.cmd.package.clean,
  fpdev.cmd.package.install_local,
  fpdev.cmd.package.create,
  fpdev.cmd.package.publish,
  fpdev.cmd.package.repo.root,
  fpdev.cmd.package.repo.add,
  fpdev.cmd.package.repo.remove,
  fpdev.cmd.package.repo.update,
  fpdev.cmd.package.repo.list,
  fpdev.cmd.package.help,

  // Project commands
  fpdev.cmd.project.root,
  fpdev.cmd.project.new,
  fpdev.cmd.project.list,
  fpdev.cmd.project.info,
  fpdev.cmd.project.build,
  fpdev.cmd.project.clean,
  fpdev.cmd.project.test,
  fpdev.cmd.project.run,
  fpdev.cmd.project.help,

  // 新的命令注册表与上下文
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.command.context,

  fpdev.output.intf,
  fpdev.output.console,

  // 版本管理模块
  fpdev.fpc.source,
  fpdev.lazarus.source;

function make_params:TStringArray;
var
  LCount :Integer;
  i: integer;
begin
  Initialize(Result);
  LCount := ParamCount;
  if LCount >1 then
  begin
    SetLength(Result,LCount-1);
    for i := 2 to LCount do
      Result[i-2] := ParamStr(i);
  end
  else
    SetLength(Result,0);
end;

var
  LParam: string;
  LParams: TStringArray;
  LArgs: TStringArray;
  LCtx: IContext;
  Outp: IOutput;
  Errp: IOutput;
  LI: Integer;
  // removed inline vars: declare here
  LSrc: string;
  S, R, Min, Rec, Cur: string;
  Name, Ver, OS, Arch: string;
  ManifestPath, Dest: string;
  M: TManifest; C: TManifestComponent; Ok: Boolean; Err: string;
  J: TStringList;
  Opt: TFetchOptions;
  Zip: string;
  LocalPath, Sha: string;
  Strict: Boolean;
  DestPath: string;
  P: string;

  // 检查是否有 --portable 参数
  procedure CheckPortableFlag;
  var
    I: Integer;
  begin
    for I := 1 to ParamCount do
    begin
      if ParamStr(I) = '--portable' then
      begin
        SetPortableMode(True);
        Exit;
      end;
    end;
  end;


begin
  // 首先检查便携模式（在任何其他操作之前）
  CheckPortableFlag;

  Outp := TConsoleOutput.Create(False) as IOutput;
  Errp := TConsoleOutput.Create(True) as IOutput;

  try
    if ParamCount = 0 then
    begin
      fpdev.cmd.help.execute([]);
    end
    else
    begin
      LParam  := ParamStr(1);

      // 内置体检/策略校验开关（零副作用）
      if (LParam = '--version') or (LParam = '-v') or (LParam = '-V') then
      begin
        Outp.WriteLn('fpdev version 2.0.0-beta');
        Outp.WriteLn('FreePascal Development Environment Manager');
        if IsPortableMode then
          Outp.WriteLn('Mode: Portable')
        else
          Outp.WriteLn('Mode: Standard');
        Outp.WriteLn('Data: ' + GetDataRoot);
        Exit;
      end
      else if LParam = '--portable' then
      begin
        // --portable 后面还有其他参数，继续处理
        if ParamCount > 1 then
        begin
          LParam := ParamStr(2);
          // 重新构建参数列表（跳过 --portable）
          Initialize(LParams);
          SetLength(LParams, 0);
          if ParamCount > 2 then
          begin
            SetLength(LParams, ParamCount - 2);
            for LI := 3 to ParamCount do
              LParams[LI - 3] := ParamStr(LI);
          end;
          // 继续处理 LParam
          if (LParam = '--version') or (LParam = '-v') or (LParam = '-V') then
          begin
            Outp.WriteLn('fpdev version 2.0.0-beta');
            Outp.WriteLn('FreePascal Development Environment Manager');
            Outp.WriteLn('Mode: Portable');
            Outp.WriteLn('Data: ' + GetDataRoot);
            Exit;
          end
          else if LParam = '--data-root' then
          begin
            Outp.WriteLn(GetDataRoot);
            Exit;
          end;
          // 其他命令继续到下面的命令分发
        end
        else
        begin
          // --portable 单独使用时显示状态
          Outp.WriteLn('Portable mode: enabled');
          Outp.WriteLn('Data directory: ' + GetDataRoot);
          Exit;
        end;
      end
      else if LParam = '--data-root' then
      begin
        Outp.WriteLn(GetDataRoot);
        Exit;
      end
      else if LParam = '--check-toolchain' then
      begin
        Outp.WriteLn(BuildToolchainReportJSON);
        Exit;
      end
      else if (LParam = '--check-policy') then
      begin
        LSrc := 'main';
        if ParamCount>=2 then LSrc := ParamStr(2);
        if CheckFPCVersionPolicy(LSrc, S,R,Min,Rec,Cur) then
        begin
          Outp.WriteLnFmt('Policy %s: src=%s current=%s min=%s rec=%s reason=%s', [S, LSrc, Cur, Min, Rec, R]);
          ExitCode := 0;
        end
        else
        begin
          Outp.WriteLnFmt('Policy %s: src=%s current=%s min=%s rec=%s reason=%s', [S, LSrc, Cur, Min, Rec, R]);
          ExitCode := 2;
        end;
        Exit;
      end;

      LParams := make_params;

      // 额外 CLI：fetch/extract（按需拉取）
      if LParam = '--fetch-tool' then
      begin
        // fpdev --fetch-tool <name> <version> <os> <arch> [--manifest <path>] [--dest <zip>]
        if ParamCount < 5 then begin Errp.WriteLn('Usage: fpdev --fetch-tool <name> <version> <os> <arch> [--manifest <path>] [--dest <zip>]'); ExitCode:=2; Exit; end;
        Name := ParamStr(2);
        Ver := ParamStr(3);
        OS  := ParamStr(4);
        Arch:= ParamStr(5);
        ManifestPath := '';
        Dest := '';
        for LI := 6 to ParamCount do
        begin
          if (ParamStr(LI)='--manifest') and (LI+1<=ParamCount) then ManifestPath := ParamStr(LI+1);
          if (ParamStr(LI)='--dest') and (LI+1<=ParamCount) then Dest := ParamStr(LI+1);
        end;
        J := TStringList.Create;
        try
          if ManifestPath='' then begin Errp.WriteLn('--manifest not specified'); ExitCode:=2; Exit; end;
          if not FileExists(ManifestPath) then begin Errp.WriteLn('Manifest not found: ' + ManifestPath); ExitCode:=2; Exit; end;
          J.LoadFromFile(ManifestPath);
          if not ParseManifestJSON(J.Text, M) then begin Errp.WriteLn('Manifest parse failed'); ExitCode:=2; Exit; end;
          if not FindComponent(M, Name, Ver, OS, Arch, C) then begin Errp.WriteLn('Component not found'); ExitCode:=2; Exit; end;
          if Dest='' then Dest := IncludeTrailingPathDelimiter(GetCacheDir)+'toolchain'+PathDelim+Name+'-'+Ver+'.zip';
          Opt.DestDir := ExtractFileDir(Dest); Opt.SHA256 := C.Sha256; Opt.TimeoutMS := DEFAULT_DOWNLOAD_TIMEOUT_MS;
          Ok := FetchWithMirrors(C.URLs, Dest, Opt, Err);
          if Ok then begin Outp.WriteLn('Download successful: ' + Dest); ExitCode:=0; end
          else begin Errp.WriteLn('Download failed: ' + Err); ExitCode:=2; end;
        finally
          J.Free;
        end;
        Exit;
      end
      else if LParam = '--extract-zip' then
      begin
        // fpdev --extract-zip <zip> <dest>
        if ParamCount < 3 then begin Errp.WriteLn('Usage: fpdev --extract-zip <zip> <dest>'); ExitCode:=2; Exit; end;
        Zip := ParamStr(2);
        Dest := ParamStr(3);
        if ZipExtract(Zip, Dest, Err) then begin Outp.WriteLn('Extract successful: ' + Dest); ExitCode:=0; end
        else begin Errp.WriteLn('Extract failed: ' + Err); ExitCode:=2; end;
        Exit;
      end
      else if LParam = '--ensure-source' then
      begin
        // fpdev --ensure-source <name> <version> --local <dir|zip> [--sha256 <hex>] [--strict]
        if ParamCount < 4 then begin Errp.WriteLn('Usage: fpdev --ensure-source <name> <version> --local <dir|zip> [--sha256 <hex>] [--strict]'); ExitCode:=2; Exit; end;
        Name := ParamStr(2);
        Ver  := ParamStr(3);
        LocalPath := '';
        Sha := '';
        Strict := False;
        LI := 4;
        while LI <= ParamCount do
        begin
          if ParamStr(LI)='--local' then begin Inc(LI); if LI<=ParamCount then LocalPath := ParamStr(LI); end
          else if ParamStr(LI)='--sha256' then begin Inc(LI); if LI<=ParamCount then Sha := ParamStr(LI); end
          else if ParamStr(LI)='--strict' then Strict := True;
          Inc(LI);
        end;
        if (LocalPath<>'') and DirectoryExists(LocalPath) then
          Ok := EnsureSourceLocalDir(Name, Ver, LocalPath, Strict, DestPath, Err)
        else if (LocalPath<>'') and FileExists(LocalPath) then
          Ok := EnsureSourceLocalZip(Name, Ver, LocalPath, Sha, DestPath, Err)
        else begin Errp.WriteLn('Missing --local <dir|zip>'); ExitCode:=2; Exit; end;
        if Ok then begin Outp.WriteLn('Source ready at: ' + DestPath); ExitCode:=0; end
        else begin Errp.WriteLn('Ensure source failed: ' + Err); ExitCode:=2; end;
        Exit;
      end
      else if LParam = '--import-bundle' then
      begin
        // fpdev --import-bundle <dir|zip>
        if ParamCount < 2 then begin Errp.WriteLn('Usage: fpdev --import-bundle <dir|zip>'); ExitCode:=2; Exit; end;
        P := ParamStr(2);
        if ImportBundle(P, Err) then begin Outp.WriteLn('Bundle imported.'); ExitCode:=0; end
        else begin Errp.WriteLn('Import bundle failed: ' + Err); ExitCode:=2; end;
        Exit;
      end;

      // 纯注册表分发
      LCtx := TDefaultCommandContext.Create;
      try
        // 拼接 LParam + LParams => LArgs
        Initialize(LArgs);
        SetLength(LArgs, Length(LParams)+1);
        LArgs[0] := LParam;
        for LI := 0 to High(LParams) do LArgs[LI+1] := LParams[LI];
        ExitCode := GlobalCommandRegistry.Dispatch(LArgs, LCtx);
        // Note: Command registry handles error messages including "Did you mean?" suggestions
      finally
        LCtx := nil;
      end;
    end;
  except
    on E: Exception do
    begin
      Errp.WriteLn(_(MSG_ERROR) + ': ' + string(E.ClassName) + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.










































































































