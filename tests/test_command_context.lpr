program test_command_context;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.command.context,
  fpdev.command.intf,
  fpdev.config.interfaces,
  fpdev.config.managers,
  fpdev.logger.intf,
  fpdev.output.intf,
  test_cli_helpers,
  test_temp_paths;

type
  TSpyLogger = class(TInterfacedObject, ILogger)
  public
    LastLevel: TLogLevel;
    LastMessage: string;
    CallCount: Integer;
    procedure Log(const ALevel: TLogLevel; const Msg: string);
    procedure Debug(const Msg: string);
    procedure Info(const Msg: string);
    procedure Warn(const Msg: string);
    procedure Error(const Msg: string);
  end;

procedure TSpyLogger.Log(const ALevel: TLogLevel; const Msg: string);
begin
  LastLevel := ALevel;
  LastMessage := Msg;
  Inc(CallCount);
end;

procedure TSpyLogger.Debug(const Msg: string);
begin
  Log(llDebug, Msg);
end;

procedure TSpyLogger.Info(const Msg: string);
begin
  Log(llInfo, Msg);
end;

procedure TSpyLogger.Warn(const Msg: string);
begin
  Log(llWarn, Msg);
end;

procedure TSpyLogger.Error(const Msg: string);
begin
  Log(llError, Msg);
end;

procedure TestInjectedConfigManagerIsReused;
var
  TempDir: string;
  ConfigPath: string;
  Config: IConfigManager;
  Ctx: IContext;
  Settings: TFPDevSettings;
begin
  TempDir := CreateUniqueTempDir('fpdev-command-context');
  try
    ConfigPath := IncludeTrailingPathDelimiter(TempDir) + 'config.json';
    Config := TConfigManager.Create(ConfigPath);
    Config.CreateDefaultConfig;
    Config.LoadConfig;

    Settings := Config.GetSettingsManager.GetSettings;
    Settings.ParallelJobs := 17;
    Config.GetSettingsManager.SetSettings(Settings);

    Ctx := TDefaultCommandContext.CreateWithConfig(Config);

    Settings := Ctx.Config.GetSettingsManager.GetSettings;
    Check('context reuses injected config manager state', Settings.ParallelJobs = 17);
    Check('context preserves injected config path',
      ExpandFileName(Ctx.Config.GetConfigPath) = ExpandFileName(ConfigPath));
  finally
    CleanupTempDir(TempDir);
  end;
end;

procedure TestInjectedLoggerIsReused;
var
  TempDir: string;
  ConfigPath: string;
  Config: IConfigManager;
  StdOut: IOutput;
  StdErr: IOutput;
  SpyLogger: TSpyLogger;
  Ctx: IContext;
begin
  TempDir := CreateUniqueTempDir('fpdev-command-context-logger');
  try
    ConfigPath := IncludeTrailingPathDelimiter(TempDir) + 'config.json';
    Config := TConfigManager.Create(ConfigPath);
    Config.CreateDefaultConfig;
    Config.LoadConfig;

    StdOut := TStringOutput.Create;
    StdErr := TStringOutput.Create;
    SpyLogger := TSpyLogger.Create;

    Ctx := TDefaultCommandContext.CreateWithConfig(Config, StdOut, StdErr, SpyLogger);
    Ctx.Logger.Info('hello context');

    Check('context uses injected logger instance', SpyLogger.CallCount = 1);
    Check('context forwards logger message to injected logger',
      SpyLogger.LastMessage = 'hello context');
    Check('context keeps injected stdout', Ctx.Out = StdOut);
    Check('context keeps injected stderr', Ctx.Err = StdErr);
  finally
    CleanupTempDir(TempDir);
  end;
end;

procedure TestSharedTestContextProvidesProductionLikeLogger;
var
  TempDir: string;
  StdOutBuf: TStringOutput;
  StdErrBuf: TStringOutput;
  Ctx: IContext;
begin
  TempDir := CreateUniqueTempDir('fpdev-test-context');
  try
    Ctx := CreateTestContext(TempDir, StdOutBuf, StdErrBuf);
    Check('shared test context exposes a logger', Ctx.Logger <> nil);

    if Ctx.Logger <> nil then
      Ctx.Logger.Warn('shared helper warning');

    Check('shared test context routes logger output to stderr',
      StdErrBuf.Contains('[WARN] shared helper warning'));
    Check('shared test context keeps logger output out of stdout',
      not StdOutBuf.Contains('[WARN] shared helper warning'));
  finally
    CleanupTempDir(TempDir);
  end;
end;

begin
  TestInjectedConfigManagerIsReused;
  TestInjectedLoggerIsReused;
  TestSharedTestContextProvidesProductionLikeLogger;
  Halt(PrintTestSummary);
end.
