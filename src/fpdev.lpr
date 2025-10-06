program fpdev;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  Classes,
  fpdev.utils,
  fpdev.toolchain,
  fpdev.toolchain.manifest,
  fpdev.toolchain.fetcher,
  fpdev.toolchain.extract,
  fpdev.paths,
  fpdev.source, // ensure-source/import-bundle 将使用

  fpdev.cmd,
  fpdev.cmd.help,
  fpdev.cmd.help.root,
  fpdev.cmd.version,
  fpdev.cmd.fpc,
  fpdev.cmd.lazarus,
  fpdev.cmd.package,
  fpdev.cmd.cross,
  fpdev.cmd.project,

  // 强引用：FPC/Lazarus 子命令对象（确保 initialization 注册生效）
  fpdev.cmd.fpc.install,
  fpdev.cmd.fpc.list,
  fpdev.cmd.fpc.use,
  fpdev.cmd.fpc.doctor,
  fpdev.cmd.fpc.current,
  fpdev.cmd.fpc.show,
  fpdev.cmd.fpc.test,
  fpdev.cmd.fpc.update,
  fpdev.cmd.fpc.root2,

  fpdev.cmd.lazarus.root,
  fpdev.cmd.lazarus.list,
  fpdev.cmd.lazarus.current,
  fpdev.cmd.lazarus.use,
  fpdev.cmd.lazarus.run,

  // 新的命令注册表与上下文
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.command.context,

  // 版本管理模块
  fpdev.fpc.source,
  fpdev.lazarus.source;

// 内部版本管理支持函数 (供现有命令模块使用)
function GetFPCSourceManager: TFPCSourceManager;
begin
  Result := TFPCSourceManager.Create;
end;

function GetLazarusSourceManager: TLazarusSourceManager;
begin
  Result := TLazarusSourceManager.Create;
end;

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
  LCtx: TDefaultCommandContext;
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
begin
  try
    if ParamCount = 0 then
    begin
      fpdev.cmd.help.execute([]);
    end
    else
    begin
      LParam  := ParamStr(1);

      // 内置体检/策略校验开关（零副作用）
      if LParam = '--check-toolchain' then
      begin
        WriteLn(BuildToolchainReportJSON);
        Exit;
      end
      else if (LParam = '--check-policy') then
      begin
        LSrc := 'main';
        if ParamCount>=2 then LSrc := ParamStr(2);
        if CheckFPCVersionPolicy(LSrc, S,R,Min,Rec,Cur) then
        begin
          WriteLn('Policy ', S, ': src=', LSrc, ' current=', Cur, ' min=', Min, ' rec=', Rec, ' reason=', R);
          ExitCode := 0;
        end
        else
        begin
          WriteLn('Policy ', S, ': src=', LSrc, ' current=', Cur, ' min=', Min, ' rec=', Rec, ' reason=', R);
          ExitCode := 2;
        end;
        Exit;
      end;

      LParams := make_params;

      // 额外 CLI：fetch/extract（按需拉取）
      if LParam = '--fetch-tool' then
      begin
        // fpdev --fetch-tool <name> <version> <os> <arch> [--manifest <path>] [--dest <zip>]
        if ParamCount < 5 then begin WriteLn('用法: fpdev --fetch-tool <name> <version> <os> <arch> [--manifest <path>] [--dest <zip>]'); ExitCode:=2; Exit; end;
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
          if ManifestPath='' then begin WriteLn('未指定 --manifest'); ExitCode:=2; Exit; end;
          if not FileExists(ManifestPath) then begin WriteLn('清单不存在: ', ManifestPath); ExitCode:=2; Exit; end;
          J.LoadFromFile(ManifestPath);
          if not ParseManifestJSON(J.Text, M) then begin WriteLn('清单解析失败'); ExitCode:=2; Exit; end;
          if not FindComponent(M, Name, Ver, OS, Arch, C) then begin WriteLn('未找到组件'); ExitCode:=2; Exit; end;
          if Dest='' then Dest := IncludeTrailingPathDelimiter(GetCacheDir)+'toolchain'+PathDelim+Name+'-'+Ver+'.zip';
          Opt.DestDir := ExtractFileDir(Dest); Opt.SHA256 := C.Sha256; Opt.TimeoutMS := 30000;
          Ok := FetchWithMirrors(C.URLs, Dest, Opt, Err);
          if Ok then begin WriteLn('下载成功: ', Dest); ExitCode:=0; end
          else begin WriteLn('下载失败: ', Err); ExitCode:=2; end;
        finally
          J.Free;
        end;
        Exit;
      end
      else if LParam = '--extract-zip' then
      begin
        // fpdev --extract-zip <zip> <dest>
        if ParamCount < 3 then begin WriteLn('用法: fpdev --extract-zip <zip> <dest>'); ExitCode:=2; Exit; end;
        Zip := ParamStr(2);
        Dest := ParamStr(3);
        if ZipExtract(Zip, Dest, Err) then begin WriteLn('解压成功: ', Dest); ExitCode:=0; end
        else begin WriteLn('解压失败: ', Err); ExitCode:=2; end;
        Exit;
      end
      else if LParam = '--ensure-source' then
      begin
        // fpdev --ensure-source <name> <version> --local <dir|zip> [--sha256 <hex>] [--strict]
        if ParamCount < 4 then begin WriteLn('用法: fpdev --ensure-source <name> <version> --local <dir|zip> [--sha256 <hex>] [--strict]'); ExitCode:=2; Exit; end;
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
        else begin WriteLn('缺少 --local <dir|zip>'); ExitCode:=2; Exit; end;
        if Ok then begin WriteLn('Source ready at: ', DestPath); ExitCode:=0; end
        else begin WriteLn('Ensure source failed: ', Err); ExitCode:=2; end;
        Exit;
      end
      else if LParam = '--import-bundle' then
      begin
        // fpdev --import-bundle <dir|zip>
        if ParamCount < 2 then begin WriteLn('用法: fpdev --import-bundle <dir|zip>'); ExitCode:=2; Exit; end;
        P := ParamStr(2);
        if ImportBundle(P, Err) then begin WriteLn('Bundle imported.'); ExitCode:=0; end
        else begin WriteLn('Import bundle failed: ', Err); ExitCode:=2; end;
        Exit;
      end;

      // 纯注册表分发
      LCtx := TDefaultCommandContext.Create;
      try
        // 拼接 LParam + LParams => LArgs
        SetLength(LArgs, Length(LParams)+1);
        LArgs[0] := LParam;
        for LI := 0 to High(LParams) do LArgs[LI+1] := LParams[LI];
        ExitCode := GlobalCommandRegistry.Dispatch(LArgs, LCtx);
        if ExitCode <> 0 then
        begin
          WriteLn('错误: 未知或执行失败的命令: ', LParam);
          WriteLn('使用 "fpdev help" 查看帮助信息');
        end;
      finally
        LCtx.Free;
      end;
    end;
  except
    on E: Exception do
    begin
      WriteLn('错误: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.










































































































