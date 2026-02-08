unit fpdev.cmd.fpc.install;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.config.interfaces, fpdev.cmd.fpc, fpdev.types,
  fpdev.i18n, fpdev.i18n.strings, fpdev.build.cache, fpdev.exitcodes;

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
  LVer, LJobs, LFrom, LPrefix, LCacheDir, LInstallPath, LInstallRoot: string;
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
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    Ctx.Err.WriteLn(_(HELP_FPC_INSTALL_USAGE));
    Exit(EXIT_USAGE_ERROR);
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
      Exit(EXIT_USAGE_ERROR);
    end;
  end
  else if HasFlag(AParams, 'from-source') then
    LMode := imSource
  else if HasFlag(AParams, 'from-binary') then
    LMode := imBinary;

  // Parse other flags
  if GetFlagValue(AParams, 'jobs', LJobs) then
  begin
    LSettings := Ctx.Config.GetSettingsManager.GetSettings;
    if TryStrToInt(LJobs, LSettings.ParallelJobs) then
      Ctx.Config.GetSettingsManager.SetSettings(LSettings);
  end;
  if not GetFlagValue(AParams, 'prefix', LPrefix) then LPrefix := '';

  // Initialize cache (use same directory as TFPCManager for consistency)
  LSettings := Ctx.Config.GetSettingsManager.GetSettings;
  LInstallRoot := LSettings.InstallRoot;
  if LInstallRoot = '' then
  begin
    {$IFDEF MSWINDOWS}
    LInstallRoot := GetEnvironmentVariable('USERPROFILE') + PathDelim + '.fpdev';
    {$ELSE}
    LInstallRoot := GetEnvironmentVariable('HOME') + PathDelim + '.fpdev';
    {$ENDIF}
  end;
  LCacheDir := LInstallRoot + PathDelim + 'cache' + PathDelim + 'builds';
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

        // Try to restore from cache (both binary and source use RestoreArtifacts now)
        // Binary installations now cache the installed directory, not the downloaded package
        Ctx.Out.WriteLn('[CACHE] Restoring from cache to: ' + LInstallPath);
        LOk := LCache.RestoreArtifacts(LVer, LInstallPath);

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
          Exit(EXIT_OK);
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
            Exit(EXIT_IO_ERROR);
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
      Exit(EXIT_IO_ERROR);
    end;

    // Show installation mode
    if LOfflineMode then
      Ctx.Out.WriteLn(_Fmt(CMD_FPC_INSTALL_START, [LVer]) + ' (mode: ' + InstallModeToString(LMode) + ', offline)')
    else if LNoCache then
      Ctx.Out.WriteLn(_Fmt(CMD_FPC_INSTALL_START, [LVer]) + ' (mode: ' + InstallModeToString(LMode) + ', no-cache)')
    else
      Ctx.Out.WriteLn(_Fmt(CMD_FPC_INSTALL_START, [LVer]) + ' (mode: ' + InstallModeToString(LMode) + ')');

    // Perform installation with auto-mode fallback logic
    LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
    try
      // Auto-mode: try binary first, fallback to source if binary fails
      if LMode = imAuto then
      begin
        Ctx.Out.WriteLn('Attempting binary installation first...');
        LOk := LMgr.InstallVersion(LVer, False, LPrefix, False);

        if not LOk then
        begin
          Ctx.Out.WriteLn('');
          Ctx.Out.WriteLn('Binary installation failed, falling back to source installation...');
          Ctx.Out.WriteLn('Note: Source installation requires a bootstrap compiler and may take longer');
          Ctx.Out.WriteLn('');
          LOk := LMgr.InstallVersion(LVer, True, LPrefix, False);

          if not LOk then
          begin
            Ctx.Err.WriteLn('');
            Ctx.Err.WriteLn('Both binary and source installation failed');
            Ctx.Err.WriteLn('Troubleshooting:');
            Ctx.Err.WriteLn('  1. Check network connectivity');
            Ctx.Err.WriteLn('  2. Verify version exists: fpdev fpc list --all');
            Ctx.Err.WriteLn('  3. For source builds, ensure bootstrap compiler is available');
            Exit(EXIT_ERROR);
          end;
        end;
      end
      else
      begin
        // Explicit mode: binary or source only
        LFromSource := (LMode = imSource);
        LOk := LMgr.InstallVersion(LVer, LFromSource, LPrefix, False);
      end;

      if LOk then
      begin
        // Note: Binary installations are now cached automatically by the installer
        // Source installations are cached by TFPCManager.InstallVersion
        // No need to call SaveArtifacts here anymore
        Exit(EXIT_OK);
      end
      else
      begin
        Ctx.Err.WriteLn(_Fmt(CMD_FPC_INSTALL_FAILED, [LVer]));
        Exit(EXIT_ERROR);
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

