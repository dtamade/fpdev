unit fpdev.cmd.fpc.install;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.config.interfaces, fpdev.cmd.fpc, fpdev.types,
  fpdev.i18n, fpdev.i18n.strings, fpdev.build.cache;

type
  { TFPCInstallCommand }
  TFPCInstallCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.registry, fpdev.cmd.utils;

function TFPCInstallCommand.Name: string; begin Result := 'install'; end;

function TFPCInstallCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCInstallCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function FPCInstallFactory: ICommand;
begin
  Result := TFPCInstallCommand.Create;
end;



function TFPCInstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer, LJobs, LFrom, LPrefix, LCacheDir, LInstallPath: string;
  LMode: TInstallMode;
  LFromSource, LOfflineMode, LNoCache: Boolean;
  LSettings: TFPDevSettings;
  LOk: Boolean;
  LMgr: TFPCManager;
  LCache: TBuildCache;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_SOURCE));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_BINARY));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_FROM));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_JOBS));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_PREFIX));
    Ctx.Out.WriteLn('  --offline         Force offline mode (use cache only)');
    Ctx.Out.WriteLn('  --no-cache        Ignore cache, force re-download');
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    Ctx.Err.WriteLn(_(HELP_FPC_INSTALL_USAGE));
    Exit(2);
  end;
  LVer := AParams[0];

  // Parse cache-related flags
  LOfflineMode := HasFlag(AParams, 'offline');
  LNoCache := HasFlag(AParams, 'no-cache');

  // Parse install mode using type-safe enum
  LMode := imAuto;  // Default mode
  if GetFlagValue(AParams, 'from', LFrom) then
  begin
    if not TryStringToInstallMode(LFrom, LMode) then
    begin
      Ctx.Err.WriteLn(_Fmt(ERR_INVALID_INSTALL_MODE, [LFrom]));
      Ctx.Err.WriteLn(_(ERR_VALID_INSTALL_MODES));
      Exit(2);
    end;
  end
  else if HasFlag(AParams, 'from-source') then
    LMode := imSource
  else if HasFlag(AParams, 'from-binary') then
    LMode := imBinary;

  // Convert mode to boolean for TFPCManager
  LFromSource := (LMode = imSource);

  // Parse other flags
  if GetFlagValue(AParams, 'jobs', LJobs) then
  begin
    LSettings := Ctx.Config.GetSettingsManager.GetSettings;
    if TryStrToInt(LJobs, LSettings.ParallelJobs) then
      Ctx.Config.GetSettingsManager.SetSettings(LSettings);
  end;
  if not GetFlagValue(AParams, 'prefix', LPrefix) then LPrefix := '';

  // Initialize cache
  LCacheDir := GetAppConfigDir(False) + '.fpdev' + PathDelim + 'cache';
  LCache := TBuildCache.Create(LCacheDir);
  try
    // Check cache before installation (unless --no-cache is specified)
    if not LNoCache and LCache.HasArtifacts(LVer) then
    begin
      Ctx.Out.WriteLn('[CACHE HIT] Found cached artifact for FPC ' + LVer);

      // Calculate installation path and create manager for SetupEnvironment
      LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
      try
        LInstallPath := LMgr.GetVersionInstallPath(LVer);
        if LPrefix <> '' then
          LInstallPath := ExpandFileName(LPrefix);

        // Try to restore from cache (use correct artifact type based on install mode)
        Ctx.Out.WriteLn('[CACHE] Restoring from cache to: ' + LInstallPath);
        if LFromSource then
          LOk := LCache.RestoreArtifacts(LVer, LInstallPath)
        else
          LOk := LCache.RestoreBinaryArtifact(LVer, LInstallPath);

        if LOk then
        begin
          // Register toolchain in config after cache restore (Fix: missing SetupEnvironment)
          if LMgr.SetupEnvironment(LVer, LInstallPath) then
            Ctx.Out.WriteLn('[OK] Toolchain registered successfully')
          else
            Ctx.Out.WriteLn('[WARN] Failed to register toolchain (non-fatal)');

          Ctx.Out.WriteLn('[OK] Installation complete (from cache)');
          Ctx.Out.WriteLn('');
          Ctx.Out.WriteLn('Next steps:');
          Ctx.Out.WriteLn('  fpdev fpc use ' + LVer);
          Exit(0);
        end
        else
        begin
          // Fix: Offline mode bypass - fail if offline and cache restore failed
          if LOfflineMode then
          begin
            Ctx.Err.WriteLn('[FAIL] Cache restoration failed in offline mode');
            Ctx.Err.WriteLn('[HINT] The cached artifact may be corrupted. Try:');
            Ctx.Err.WriteLn('[HINT]   fpdev fpc cache clean ' + LVer);
            Ctx.Err.WriteLn('[HINT]   fpdev fpc install ' + LVer + '  (without --offline)');
            Exit(4);
          end;
          Ctx.Out.WriteLn('[WARN] Cache restoration failed, proceeding with download...');
          // Continue with normal installation
        end;
      finally
        LMgr.Free;
      end;
    end
    else if LOfflineMode then
    begin
      // Offline mode: cache miss is an error
      Ctx.Err.WriteLn('[FAIL] Cache miss for FPC ' + LVer);
      Ctx.Err.WriteLn('[HINT] Network disabled by --offline flag');
      Ctx.Err.WriteLn('[HINT] Run without --offline to download, or use ''fpdev fpc cache list'' to see available versions');
      Exit(4);
    end;

    // Show installation mode
    if LOfflineMode then
      Ctx.Out.WriteLn(_Fmt(CMD_FPC_INSTALL_START, [LVer]) + ' (mode: ' + InstallModeToString(LMode) + ', offline)')
    else if LNoCache then
      Ctx.Out.WriteLn(_Fmt(CMD_FPC_INSTALL_START, [LVer]) + ' (mode: ' + InstallModeToString(LMode) + ', no-cache)')
    else
      Ctx.Out.WriteLn(_Fmt(CMD_FPC_INSTALL_START, [LVer]) + ' (mode: ' + InstallModeToString(LMode) + ')');

    // Perform installation
    LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
    try
      LOk := LMgr.InstallVersion(LVer, LFromSource, LPrefix, False);
      if LOk then
      begin
        // Save to cache after successful installation (unless --no-cache)
        if not LNoCache then
        begin
          // Get installation path
          LInstallPath := LMgr.GetVersionInstallPath(LVer);
          if LPrefix <> '' then
            LInstallPath := ExpandFileName(LPrefix);

          // Save installed directory to cache
          Ctx.Out.WriteLn('[CACHE] Saving installation to cache...');
          if LCache.SaveArtifacts(LVer, LInstallPath) then
            Ctx.Out.WriteLn('[CACHE] Installation cached successfully')
          else
            Ctx.Out.WriteLn('[WARN] Failed to cache installation (non-fatal)');
        end;

        Exit(0);
      end
      else
      begin
        Ctx.Err.WriteLn(_Fmt(CMD_FPC_INSTALL_FAILED, [LVer]));
        Exit(3);
      end;
    finally
      LMgr.Free;
    end;
  finally
    LCache.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','install'], @FPCInstallFactory, []);

end.

