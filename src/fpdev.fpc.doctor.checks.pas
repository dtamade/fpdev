unit fpdev.fpc.doctor.checks;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.intf;

function ExecuteFPCDoctorChecksCore(const Ctx: IContext): Integer;

implementation

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.doctor.runtime,
  fpdev.paths;

function ExecuteFPCDoctorChecksCore(const Ctx: IContext): Integer;
var
  LOut: string;
  LErr: string;
  LOk: Boolean;
  LRoot: string;
  LToolchains: TStringArray;
  LInfo: TToolchainInfo;
  LActivateScript: string;
  LDefaultToolchain: string;
  I: Integer;
  LFPCPath: string;
  LCfgPath: string;
  LLibPath: string;
  LCacheDir: string;
  LDiskFree: Int64;
begin
  Result := 0;

  Ctx.Out.WriteLn('FPC Doctor - Checking your FPC environment...');
  Ctx.Out.WriteLn('');

  Ctx.Out.WriteLn('[1/11] Checking write permissions...');
  LRoot := GetToolchainsDir;
  LOk := CheckDoctorWriteableDirCore(LRoot, LErr);
  if LOk then
    Ctx.Out.WriteLn('  OK: ' + LRoot + ' is writable')
  else
  begin
    Ctx.Out.WriteLn('  ERROR: ' + LRoot + ' - ' + LErr);
    Inc(Result);
  end;

  Ctx.Out.WriteLn('[2/11] Checking git...');
  LOk := RunDoctorToolVersionCore('git', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn('  OK: ' + Trim(LOut))
  else
  begin
    Ctx.Out.WriteLn('  WARNING: git not found');
    Ctx.Out.WriteLn('    Hint: Install git for source builds');
  end;

  Ctx.Out.WriteLn('[3/11] Checking make...');
  LOk := RunDoctorToolVersionCore('make', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn('  OK: ' + Copy(Trim(LOut), 1, 50))
  else
  begin
    Ctx.Out.WriteLn('  WARNING: make not found');
    Ctx.Out.WriteLn('    Hint: Install make for source builds');
  end;

  Ctx.Out.WriteLn('[4/11] Checking system FPC...');
  LOk := RunDoctorToolVersionCore('fpc', '-iV', LOut);
  if LOk then
    Ctx.Out.WriteLn('  OK: System FPC version ' + Trim(LOut))
  else
    Ctx.Out.WriteLn('  INFO: No system FPC found (will use fpdev-managed versions)');

  Ctx.Out.WriteLn('[5/11] Checking installed toolchains...');
  LToolchains := Ctx.Config.GetToolchainManager.ListToolchains;
  if Length(LToolchains) = 0 then
    Ctx.Out.WriteLn('  INFO: No FPC toolchains installed via fpdev')
  else
  begin
    Ctx.Out.WriteLn('  Found ' + IntToStr(Length(LToolchains)) + ' toolchain(s):');
    for I := 0 to High(LToolchains) do
      if Ctx.Config.GetToolchainManager.GetToolchain(LToolchains[I], LInfo) then
      begin
        if DirectoryExists(LInfo.InstallPath) then
        begin
          {$IFDEF MSWINDOWS}
          LFPCPath := LInfo.InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
          {$ELSE}
          LFPCPath := LInfo.InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
          {$ENDIF}
          if FileExists(LFPCPath) then
            Ctx.Out.WriteLn('    - ' + LToolchains[I] + ' [OK]')
          else
          begin
            Ctx.Out.WriteLn('    - ' + LToolchains[I] + ' [BROKEN: fpc binary missing]');
            Inc(Result);
          end;
        end
        else
        begin
          Ctx.Out.WriteLn('    - ' + LToolchains[I] + ' [BROKEN: directory missing]');
          Inc(Result);
        end;
      end;
  end;

  Ctx.Out.WriteLn('[6/11] Checking default toolchain...');
  LDefaultToolchain := Ctx.Config.GetToolchainManager.GetDefaultToolchain;
  if LDefaultToolchain <> '' then
  begin
    Ctx.Out.WriteLn('  Default: ' + LDefaultToolchain);
    if not Ctx.Config.GetToolchainManager.GetToolchain(LDefaultToolchain, LInfo) then
    begin
      Ctx.Out.WriteLn('  ERROR: Default toolchain not found in config');
      Ctx.Out.WriteLn('    Hint: Run "fpdev fpc use <version>" to set a valid default');
      Inc(Result);
    end;
  end
  else
    Ctx.Out.WriteLn('  INFO: No default toolchain set');

  Ctx.Out.WriteLn('[7/11] Checking activation script...');
  LActivateScript := GetDataRoot + PathDelim + 'env' + PathDelim + 'activate.sh';
  if FileExists(LActivateScript) then
    Ctx.Out.WriteLn('  OK: ' + LActivateScript)
  else
    Ctx.Out.WriteLn('  INFO: No activation script (run "fpdev fpc use <version>" to create)');

  Ctx.Out.WriteLn('[8/11] Checking fpc.cfg configuration...');
  if Length(LToolchains) > 0 then
  begin
    for I := 0 to High(LToolchains) do
      if Ctx.Config.GetToolchainManager.GetToolchain(LToolchains[I], LInfo) then
      begin
        LCfgPath := LInfo.InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.cfg';
        if FileExists(LCfgPath) then
          Ctx.Out.WriteLn('  OK: fpc.cfg found for ' + LToolchains[I])
        else
        begin
          Ctx.Out.WriteLn('  WARNING: fpc.cfg missing for ' + LToolchains[I]);
          Ctx.Out.WriteLn('    Hint: Reinstall with "fpdev fpc install ' + LToolchains[I] + '"');
          Inc(Result);
        end;
      end;
  end
  else
    Ctx.Out.WriteLn('  INFO: No toolchains to check fpc.cfg for');

  Ctx.Out.WriteLn('[9/11] Checking library paths...');
  if Length(LToolchains) > 0 then
  begin
    for I := 0 to High(LToolchains) do
      if Ctx.Config.GetToolchainManager.GetToolchain(LToolchains[I], LInfo) then
      begin
        LLibPath := LInfo.InstallPath + PathDelim + 'lib' + PathDelim + 'fpc';
        if DirectoryExists(LLibPath) then
          Ctx.Out.WriteLn('  OK: library path exists for ' + LToolchains[I])
        else
        begin
          Ctx.Out.WriteLn('  WARNING: library path missing for ' + LToolchains[I]);
          Inc(Result);
        end;
      end;
  end
  else
    Ctx.Out.WriteLn('  INFO: No toolchains to check library paths for');

  Ctx.Out.WriteLn('[10/11] Checking cache health...');
  LCacheDir := GetDataRoot + PathDelim + 'cache';
  if DirectoryExists(LCacheDir) then
  begin
    LOk := CheckDoctorWriteableDirCore(LCacheDir, LErr);
    if LOk then
      Ctx.Out.WriteLn('  OK: cache directory is accessible (' + LCacheDir + ')')
    else
    begin
      Ctx.Out.WriteLn('  WARNING: cache directory not writable: ' + LErr);
      Inc(Result);
    end;
  end
  else
    Ctx.Out.WriteLn('  INFO: No cache directory yet (will be created on first install)');

  Ctx.Out.WriteLn('[11/11] Checking disk space...');
  try
    LDiskFree := DiskFree(0);
    if LDiskFree > 0 then
    begin
      if LDiskFree < 500 * 1024 * 1024 then
      begin
        Ctx.Out.WriteLn(
          '  WARNING: Low disk space (' + IntToStr(LDiskFree div (1024 * 1024)) + ' MB free)'
        );
        Ctx.Out.WriteLn('    Hint: FPC builds require at least 500 MB free space');
        Inc(Result);
      end
      else
        Ctx.Out.WriteLn(
          '  OK: ' + IntToStr(LDiskFree div (1024 * 1024)) + ' MB free disk space'
        );
    end
    else
      Ctx.Out.WriteLn('  INFO: Could not determine disk space');
  except
    on E: Exception do
      Ctx.Out.WriteLn('  INFO: Could not check disk space: ' + E.Message);
  end;
end;

end.
