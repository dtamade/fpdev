program test_command_registry;

{$mode objfpc}{$H+}

{
  B053: Command Registry Contract Tests

  Tests command registration, alias resolution, and dispatch paths
  to prevent "command unreachable" regressions.
}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.help.commandflow,
  fpdev.config.interfaces,
  fpdev.config.managers,
  fpdev.paths,
  fpdev.exitcodes,
  fpdev.logger.intf,
  fpdev.output.intf,
  fpdev.utils.fs,
  // Import all command units to trigger registration
  fpdev.command.imports;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  GTempConfigRoot: string = '';
  GContextCounter: Integer = 0;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('  PASS: ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (expected: ' + AExpected + ', got: ' + AActual + ')');
end;

procedure AssertEquals(AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (expected: ' + IntToStr(AExpected) + ', got: ' + IntToStr(AActual) + ')');
end;

type
  { TBufferOutput - captures output to a string buffer for assertions }
  TBufferOutput = class(TInterfacedObject, IOutput)
  private
    FBuf: string;
  public
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
    function Text: string;
    procedure Clear;
  end;

  { TTestContext - minimal context for registry dispatch tests }
  TTestContext = class(TInterfacedObject, IContext)
  private
    FConfig: IConfigManager;
    FConfigPath: string;
    FOut: IOutput;
    FErr: IOutput;
  public
    constructor Create(const AOut, AErr: IOutput);
    function ConfigPath: string;
    function Config: IConfigManager;
    function Out: IOutput;
    function Err: IOutput;
    function Logger: ILogger;
    procedure SaveIfModified;
  end;

function EnsureTempConfigRoot: string;
begin
  if GTempConfigRoot = '' then
  begin
    GTempConfigRoot := IncludeTrailingPathDelimiter(GetTempDir(False))
      + 'fpdev-command-registry-' + IntToStr(GetTickCount64);
    ForceDirectories(GTempConfigRoot);
  end;
  Result := GTempConfigRoot;
end;

function AllocateConfigPath: string;
var
  ContextDir: string;
begin
  Inc(GContextCounter);
  ContextDir := IncludeTrailingPathDelimiter(EnsureTempConfigRoot)
    + 'ctx-' + IntToStr(GContextCounter);
  ForceDirectories(ContextDir);
  Result := IncludeTrailingPathDelimiter(ContextDir) + 'config.json';
end;

procedure TBufferOutput.Write(const S: string);
begin
  FBuf := FBuf + S;
end;

procedure TBufferOutput.WriteLn;
begin
  FBuf := FBuf + LineEnding;
end;

procedure TBufferOutput.WriteLn(const S: string);
begin
  FBuf := FBuf + S + LineEnding;
end;

procedure TBufferOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TBufferOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TBufferOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  if AColor = ccDefault then; // suppress unused parameter
  Write(S);
end;

procedure TBufferOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  if AColor = ccDefault then;
  WriteLn(S);
end;

procedure TBufferOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  if AColor = ccDefault then;
  if AStyle = csNone then;
  Write(S);
end;

procedure TBufferOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  if AColor = ccDefault then;
  if AStyle = csNone then;
  WriteLn(S);
end;

procedure TBufferOutput.WriteSuccess(const S: string);
begin
  WriteLn(S);
end;

procedure TBufferOutput.WriteError(const S: string);
begin
  WriteLn(S);
end;

procedure TBufferOutput.WriteWarning(const S: string);
begin
  WriteLn(S);
end;

procedure TBufferOutput.WriteInfo(const S: string);
begin
  WriteLn(S);
end;

function TBufferOutput.SupportsColor: Boolean;
begin
  Result := False;
end;

function TBufferOutput.Text: string;
begin
  Result := FBuf;
end;

procedure TBufferOutput.Clear;
begin
  FBuf := '';
end;

constructor TTestContext.Create(const AOut, AErr: IOutput);
begin
  inherited Create;
  FConfigPath := AllocateConfigPath;
  FConfig := TConfigManager.Create(FConfigPath) as IConfigManager;
  FConfig.CreateDefaultConfig;
  FConfig.LoadConfig;
  FOut := AOut;
  FErr := AErr;
end;

function TTestContext.ConfigPath: string;
begin
  Result := FConfigPath;
end;

function TTestContext.Config: IConfigManager;
begin
  Result := FConfig;
end;

function TTestContext.Out: IOutput;
begin
  Result := FOut;
end;

function TTestContext.Err: IOutput;
begin
  Result := FErr;
end;

function TTestContext.Logger: ILogger;
begin
  Result := nil;
end;

procedure TTestContext.SaveIfModified;
begin
  if (FConfig <> nil) and FConfig.IsModified then
    FConfig.SaveConfig;
end;

// ============================================================================
// Test: Contexts use isolated temporary config paths
// ============================================================================
procedure TestContextUsesIsolatedConfigPath;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  CtxObj: TTestContext;
  DefaultConfigPath: string;
begin
  WriteLn('[TEST] TestContextUsesIsolatedConfigPath');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  CtxObj := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  DefaultConfigPath := ExpandFileName(GetConfigPath);
  AssertTrue(Pos(IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False))),
    ExpandFileName(CtxObj.ConfigPath)) = 1,
    'context config lives under system temp');
  AssertTrue(ExpandFileName(CtxObj.ConfigPath) <> DefaultConfigPath,
    'context config should not use default user config path');
  AssertTrue(FileExists(CtxObj.ConfigPath), 'context config file is created');
end;

// ============================================================================
// Test: Root Commands Registered
// ============================================================================
procedure TestRootCommandsRegistered;
var
  Children: TStringArray;
  i: Integer;
  HasFPC, HasLazarus, HasPackage, HasCross, HasRepo, HasProject, HasSystem: Boolean;
  HasHelp, HasVersion, HasCache, HasDefault, HasDoctorRoot, HasShowRoot, HasShellHookRoot, HasResolveRoot: Boolean;
begin
  WriteLn('[TEST] TestRootCommandsRegistered');

  Children := GlobalCommandRegistry.ListChildren([]);

  HasFPC := False;
  HasLazarus := False;
  HasPackage := False;
  HasCross := False;
  HasRepo := False;
  HasProject := False;
  HasSystem := False;
  HasHelp := False;
  HasVersion := False;
  HasCache := False;
  HasDefault := False;
  HasDoctorRoot := False;
  HasShowRoot := False;
  HasShellHookRoot := False;
  HasResolveRoot := False;

  for i := 0 to High(Children) do
  begin
    case LowerCase(Children[i]) of
      'fpc': HasFPC := True;
      'lazarus': HasLazarus := True;
      'package', 'pkg': HasPackage := True;
      'cross': HasCross := True;
      'repo': HasRepo := True;
      'project': HasProject := True;
      'system': HasSystem := True;
      'help': HasHelp := True;
      'version': HasVersion := True;
      'cache': HasCache := True;
      'default': HasDefault := True;
      'doctor': HasDoctorRoot := True;
      'show': HasShowRoot := True;
      'shell-hook': HasShellHookRoot := True;
      'resolve-version': HasResolveRoot := True;
    end;
  end;

  AssertTrue(HasFPC, 'fpc command registered');
  AssertTrue(HasLazarus, 'lazarus command registered');
  AssertTrue(HasPackage, 'package command registered');
  AssertTrue(HasCross, 'cross command registered');
  AssertTrue(not HasRepo, 'repo command no longer registered at top level');
  AssertTrue(HasProject, 'project command registered');
  AssertTrue(HasSystem, 'system command registered');
  AssertTrue(not HasDefault, 'default command no longer registered at top level');
  AssertTrue(not HasDoctorRoot, 'doctor command no longer registered at top level');
  AssertTrue(not HasHelp, 'help command no longer registered at top level');
  AssertTrue(not HasVersion, 'version command no longer registered at top level');
  AssertTrue(not HasCache, 'cache command no longer registered at top level');
  AssertTrue(not HasShowRoot, 'show command no longer registered at top level');
  AssertTrue(not HasShellHookRoot, 'shell-hook command no longer registered at top level');
  AssertTrue(not HasResolveRoot, 'resolve-version command no longer registered at top level');
end;

// ============================================================================
// Test: FPC Subcommands Registered
// ============================================================================
procedure TestFPCSubcommandsRegistered;
var
  Children: TStringArray;
  i: Integer;
  HasInstall, HasList, HasUse, HasCurrent, HasShow, HasDoctor: Boolean;
  HasVerify, HasAutoInstall, HasUninstall, HasCache: Boolean;
begin
  WriteLn('[TEST] TestFPCSubcommandsRegistered');

  Children := GlobalCommandRegistry.ListChildren(['fpc']);

  HasInstall := False;
  HasList := False;
  HasUse := False;
  HasCurrent := False;
  HasShow := False;
  HasDoctor := False;
  HasVerify := False;
  HasAutoInstall := False;
  HasUninstall := False;
  HasCache := False;

  for i := 0 to High(Children) do
  begin
    case LowerCase(Children[i]) of
      'install': HasInstall := True;
      'list': HasList := True;
      'use', 'default': HasUse := True;
      'current': HasCurrent := True;
      'show': HasShow := True;
      'doctor': HasDoctor := True;
      'verify': HasVerify := True;
      'auto-install': HasAutoInstall := True;
      'uninstall': HasUninstall := True;
      'cache': HasCache := True;
    end;
  end;

  AssertTrue(HasInstall, 'fpc install registered');
  AssertTrue(HasList, 'fpc list registered');
  AssertTrue(HasUse, 'fpc use registered');
  AssertTrue(HasCurrent, 'fpc current registered');
  AssertTrue(HasShow, 'fpc show registered');
  AssertTrue(HasDoctor, 'fpc doctor registered');
  AssertTrue(HasVerify, 'fpc verify registered');
  AssertTrue(HasAutoInstall, 'fpc auto-install registered');
  AssertTrue(HasUninstall, 'fpc uninstall registered');
  AssertTrue(HasCache, 'fpc cache registered');
end;

// ============================================================================
// Test: Package Subcommands Registered
// ============================================================================
procedure TestPackageSubcommandsRegistered;
var
  Children: TStringArray;
  i: Integer;
  HasInstall, HasList, HasSearch, HasInfo, HasPublish: Boolean;
begin
  WriteLn('[TEST] TestPackageSubcommandsRegistered');

  Children := GlobalCommandRegistry.ListChildren(['package']);

  HasInstall := False;
  HasList := False;
  HasSearch := False;
  HasInfo := False;
  HasPublish := False;

  for i := 0 to High(Children) do
  begin
    case LowerCase(Children[i]) of
      'install': HasInstall := True;
      'list': HasList := True;
      'search': HasSearch := True;
      'info': HasInfo := True;
      'publish': HasPublish := True;
    end;
  end;

  AssertTrue(HasInstall, 'package install registered');
  AssertTrue(HasList, 'package list registered');
  AssertTrue(HasSearch, 'package search registered');
  AssertTrue(HasInfo, 'package info registered');
  AssertTrue(HasPublish, 'package publish registered');
end;

// ============================================================================
// Test: Repo Subcommands Registered
// ============================================================================
procedure TestRepoSubcommandsRegistered;
var
  Children: TStringArray;
  i: Integer;
  HasAdd, HasRemove, HasList, HasUse: Boolean;
begin
  WriteLn('[TEST] TestRepoSubcommandsRegistered');

  Children := GlobalCommandRegistry.ListChildren(['system', 'repo']);

  HasAdd := False;
  HasRemove := False;
  HasList := False;
  HasUse := False;

  for i := 0 to High(Children) do
  begin
    case LowerCase(Children[i]) of
      'add': HasAdd := True;
      'remove', 'rm': HasRemove := True;
      'list', 'ls': HasList := True;
      'use': HasUse := True;
    end;
  end;

  AssertTrue(HasAdd, 'system repo add registered');
  AssertTrue(HasRemove, 'system repo remove registered');
  AssertTrue(HasList, 'system repo list registered');
  AssertTrue(HasUse, 'system repo use registered');
end;

procedure TestSystemSubcommandsRegistered;
var
  Children: TStringArray;
  i: Integer;
  HasConfig, HasEnv, HasIndex, HasPerf, HasRepo, HasCache, HasDoctor: Boolean;
  HasHook, HasResolve, HasVars, HasPath, HasExport: Boolean;
  HasIndexStatus, HasIndexShow, HasIndexUpdate: Boolean;
  HasCacheStatus, HasCacheStats, HasCachePath: Boolean;
begin
  WriteLn('[TEST] TestSystemSubcommandsRegistered');

  Children := GlobalCommandRegistry.ListChildren(['system']);

  HasConfig := False;
  HasEnv := False;
  HasIndex := False;
  HasPerf := False;
  HasRepo := False;
  HasCache := False;
  HasDoctor := False;
  HasHook := False;
  HasResolve := False;
  HasVars := False;
  HasPath := False;
  HasExport := False;
  HasIndexStatus := False;
  HasIndexShow := False;
  HasIndexUpdate := False;
  HasCacheStatus := False;
  HasCacheStats := False;
  HasCachePath := False;

  for i := 0 to High(Children) do
  begin
    case LowerCase(Children[i]) of
      'config': HasConfig := True;
      'env': HasEnv := True;
      'index': HasIndex := True;
      'perf': HasPerf := True;
      'repo': HasRepo := True;
      'cache': HasCache := True;
      'doctor': HasDoctor := True;
    end;
  end;

  AssertTrue(HasConfig, 'system config registered');
  AssertTrue(HasEnv, 'system env registered');
  AssertTrue(HasIndex, 'system index registered');
  AssertTrue(HasPerf, 'system perf registered');
  AssertTrue(HasRepo, 'system repo registered');
  AssertTrue(HasCache, 'system cache registered');
  AssertTrue(HasDoctor, 'system doctor registered');

  Children := GlobalCommandRegistry.ListChildren(['system', 'env']);
  for i := 0 to High(Children) do
    case LowerCase(Children[i]) of
      'vars': HasVars := True;
      'path': HasPath := True;
      'export': HasExport := True;
      'hook': HasHook := True;
      'resolve': HasResolve := True;
    end;
  AssertTrue(HasVars, 'system env vars registered');
  AssertTrue(HasPath, 'system env path registered');
  AssertTrue(HasExport, 'system env export registered');
  AssertTrue(HasHook, 'system env hook registered');
  AssertTrue(HasResolve, 'system env resolve registered');

  Children := GlobalCommandRegistry.ListChildren(['system', 'index']);
  for i := 0 to High(Children) do
    case LowerCase(Children[i]) of
      'status': HasIndexStatus := True;
      'show': HasIndexShow := True;
      'update': HasIndexUpdate := True;
    end;
  AssertTrue(HasIndexStatus, 'system index status registered');
  AssertTrue(HasIndexShow, 'system index show registered');
  AssertTrue(HasIndexUpdate, 'system index update registered');

  Children := GlobalCommandRegistry.ListChildren(['system', 'cache']);
  for i := 0 to High(Children) do
    case LowerCase(Children[i]) of
      'status': HasCacheStatus := True;
      'stats': HasCacheStats := True;
      'path': HasCachePath := True;
    end;
  AssertTrue(HasCacheStatus, 'system cache status registered');
  AssertTrue(HasCacheStats, 'system cache stats registered');
  AssertTrue(HasCachePath, 'system cache path registered');
end;

// ============================================================================
// Test: Command Count (Regression Guard)
// ============================================================================
procedure TestCommandCount;
var
  RootChildren: TStringArray;
  FPCChildren: TStringArray;
  TotalCommands: Integer;
begin
  WriteLn('[TEST] TestCommandCount');

  RootChildren := GlobalCommandRegistry.ListChildren([]);
  FPCChildren := GlobalCommandRegistry.ListChildren(['fpc']);

  // Root should have at least 10 commands (fpc, lazarus, package, cross, repo, project, help, version, doctor, etc.)
  AssertTrue(Length(RootChildren) >= 6, 'Root has >= 6 commands (got ' + IntToStr(Length(RootChildren)) + ')');

  // FPC should have at least 10 subcommands
  AssertTrue(Length(FPCChildren) >= 10, 'FPC has >= 10 subcommands (got ' + IntToStr(Length(FPCChildren)) + ')');

  // Total registered commands should be >= 70 (baseline from B003)
  TotalCommands := Length(RootChildren) + Length(FPCChildren);
  // Note: This is partial count, actual total is higher
  AssertTrue(TotalCommands >= 20, 'Total partial count >= 20 (got ' + IntToStr(TotalCommands) + ')');
end;

// ============================================================================
// Test: Alias Resolution (rm -> remove)
// ============================================================================
procedure TestAliasResolution;
var
  RepoChildren: TStringArray;
  i: Integer;
  HasRm: Boolean;
begin
  WriteLn('[TEST] TestAliasResolution');

  RepoChildren := GlobalCommandRegistry.ListChildren(['system', 'repo']);

  HasRm := False;
  for i := 0 to High(RepoChildren) do
    if LowerCase(RepoChildren[i]) = 'rm' then
      HasRm := True;

  AssertTrue(not HasRm, 'system repo rm alias removed');
end;

// ============================================================================
// Test: Unknown command suggestion contract
// ============================================================================
procedure TestUnknownCommandSuggestion;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestUnknownCommandSuggestion');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'instal'], Ctx);
  AssertEquals(EXIT_ERROR, Code, 'fpc instal exits error');
  AssertTrue(Pos('Unknown command: instal', ErrBufObj.Text) > 0, 'fpc instal prints unknown command');
  AssertTrue(Pos('Did you mean "install"?', ErrBufObj.Text) > 0, 'fpc instal prints install suggestion');
  AssertTrue(Pos('Run "fpdev system help" for available commands.', ErrBufObj.Text) > 0,
    'fpc instal points to system help');
end;

// ============================================================================
// Test: Unknown command falls back to available commands
// ============================================================================
procedure TestUnknownCommandFallsBackToAvailableCommands;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestUnknownCommandFallsBackToAvailableCommands');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'zzzzzz'], Ctx);
  AssertEquals(EXIT_ERROR, Code, 'fpc zzzzzz exits error');
  AssertTrue(Pos('Unknown command: zzzzzz', ErrBufObj.Text) > 0, 'fpc zzzzzz prints unknown command');
  AssertTrue(Pos('Available commands:', ErrBufObj.Text) > 0, 'fpc zzzzzz lists available commands');
  AssertTrue(Pos('install', ErrBufObj.Text) > 0, 'fpc zzzzzz available commands include install');
end;

// ============================================================================
// Test: Root help output should not reference removed top-level help command
// ============================================================================
procedure TestRootHelpOutputUsesCurrentCLI;
var
  OutBufObj: TBufferOutput;
begin
  WriteLn('[TEST] TestRootHelpOutputUsesCurrentCLI');

  OutBufObj := TBufferOutput.Create;
  ExecuteHelpCore([], OutBufObj as IOutput);

  AssertTrue(Pos('fpdev help', OutBufObj.Text) = 0, 'root help should not mention removed top-level help command');
  AssertTrue(Pos('fpdev <command> --help', OutBufObj.Text) > 0, 'root help should recommend command --help');
end;

// ============================================================================
// Test: Version help path should use global switch syntax
// ============================================================================
procedure TestVersionHelpUsesGlobalSwitchSyntax;
var
  OutBufObj: TBufferOutput;
begin
  WriteLn('[TEST] TestVersionHelpUsesGlobalSwitchSyntax');

  OutBufObj := TBufferOutput.Create;
  ExecuteHelpCore(['version'], OutBufObj as IOutput);

  AssertTrue(Pos('Usage: fpdev system version', OutBufObj.Text) > 0, 'version help should use system version command');
  AssertTrue(Pos('Usage: fpdev --version', OutBufObj.Text) = 0, 'version help should not mention removed global version flag');
end;

// ============================================================================
// Test: Missing subcommand prints usage and available commands
// ============================================================================
procedure TestMissingSubcommandUsage;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestMissingSubcommandUsage');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system without subcommand exits usage error');
  AssertTrue(Pos('Usage: fpdev system <command>', ErrBufObj.Text) > 0, 'system without subcommand prints usage');
  AssertTrue(Pos('Available commands:', ErrBufObj.Text) > 0, 'system without subcommand lists available commands');
  AssertTrue(Pos('repo', ErrBufObj.Text) > 0, 'system without subcommand includes repo');
  AssertTrue(Pos('Use "fpdev system <command> --help" for more information.', ErrBufObj.Text) > 0,
    'system without subcommand prints help hint');
end;

// ============================================================================
// Test: Help Flags Dispatch Correctly (--help should not become positional "help")
// ============================================================================
procedure TestHelpFlagsDispatch;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestHelpFlagsDispatch');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  // Leaf command should see --help and print its own usage
  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'env', 'hook', '--help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'system env hook --help exits 0');
  AssertTrue(Pos('Usage: fpdev system env hook', OutBufObj.Text) > 0, 'system env hook --help prints usage');

  // Namespaced leaf commands should accept --help and print usage
  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'test', '--help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'fpc test --help exits 0');
  AssertTrue(Pos('Usage: fpdev fpc test', OutBufObj.Text) > 0, 'fpc test --help prints usage');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'test', '--help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'cross test --help exits 0');
  AssertTrue(Pos('Usage: fpdev cross test', OutBufObj.Text) > 0, 'cross test --help prints usage');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'run', '--help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'lazarus run --help exits 0');
  AssertTrue(Pos('Usage: fpdev lazarus run', OutBufObj.Text) > 0, 'lazarus run --help prints usage');

  // Standalone command should provide usage for --help
  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'env', 'resolve', '--help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'system env resolve --help exits 0');
  AssertTrue(Pos('Usage: fpdev system env resolve', OutBufObj.Text) > 0, 'system env resolve --help prints usage');
end;

// ============================================================================
// Test: "fpdev help <leaf>" Should Print Leaf Usage
// ============================================================================
procedure TestRootHelpHelperLeafFallback;
var
  OutBufObj: TBufferOutput;
begin
  WriteLn('[TEST] TestRootHelpHelperLeafFallback');

  OutBufObj := TBufferOutput.Create;

  OutBufObj.Clear;
  ExecuteHelpCore(['system', 'env', 'hook'], OutBufObj as IOutput);
  AssertTrue(Pos('Usage: fpdev system env hook', OutBufObj.Text) > 0, 'root help helper prints system env hook usage');

  OutBufObj.Clear;
  ExecuteHelpCore(['system', 'env'], OutBufObj as IOutput);
  AssertTrue(Pos('Usage: fpdev system env', OutBufObj.Text) > 0, 'root help helper prints system env usage');

  OutBufObj.Clear;
  ExecuteHelpCore(['system', 'env', 'resolve'], OutBufObj as IOutput);
  AssertTrue(Pos('Usage: fpdev system env resolve', OutBufObj.Text) > 0, 'root help helper prints system env resolve usage');

  OutBufObj.Clear;
  ExecuteHelpCore(['system', 'index', 'status'], OutBufObj as IOutput);
  AssertTrue(Pos('Usage: fpdev system index status', OutBufObj.Text) > 0, 'root help helper prints system index status usage');

  OutBufObj.Clear;
  ExecuteHelpCore(['system', 'cache', 'stats'], OutBufObj as IOutput);
  AssertTrue(Pos('Usage: fpdev system cache stats', OutBufObj.Text) > 0, 'root help helper prints system cache stats usage');

  OutBufObj.Clear;
  ExecuteHelpCore(['system', 'config', 'show'], OutBufObj as IOutput);
  AssertTrue(Pos('Usage: fpdev system config show', OutBufObj.Text) > 0, 'root help helper prints system config show usage');
end;

// ============================================================================
// Test: "fpdev help <domain...>" should route through live domain help/leaf help
// ============================================================================
procedure TestRootHelpHelperUsesDynamicDomainHelp;
var
  OutBufObj: TBufferOutput;
begin
  WriteLn('[TEST] TestRootHelpHelperUsesDynamicDomainHelp');

  OutBufObj := TBufferOutput.Create;

  OutBufObj.Clear;
  ExecuteHelpCore(['fpc'], OutBufObj as IOutput);
  AssertTrue(Pos('auto-install', LowerCase(OutBufObj.Text)) > 0,
    'root help helper prints live fpc help with auto-install');
  AssertTrue(Pos('update-manifest', LowerCase(OutBufObj.Text)) > 0,
    'root help helper prints live fpc help with update-manifest');
  AssertTrue(Pos('clean', LowerCase(OutBufObj.Text)) = 0,
    'root help helper should not print removed fpc clean entry');

  OutBufObj.Clear;
  ExecuteHelpCore(['fpc', 'verify'], OutBufObj as IOutput);
  AssertTrue(Pos('Usage: fpdev fpc verify', OutBufObj.Text) > 0,
    'root help helper prints live fpc verify usage');

  OutBufObj.Clear;
  ExecuteHelpCore(['fpc', 'cache'], OutBufObj as IOutput);
  AssertTrue(Pos('Usage: fpdev fpc cache <subcommand>', OutBufObj.Text) > 0,
    'root help helper prints live fpc cache usage');
end;

// ============================================================================
// Test: system maintenance commands replace removed global flags
// ============================================================================
procedure TestSystemMaintenanceCommands;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestSystemMaintenanceCommands');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'system help exits 0');
  AssertTrue(Pos('Usage: fpdev [command] [options]', OutBufObj.Text) > 0,
    'system help prints root help');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'version'], Ctx);
  AssertEquals(EXIT_OK, Code, 'system version exits 0');
  AssertTrue(Pos('fpdev version', LowerCase(OutBufObj.Text)) > 0,
    'system version prints banner');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'env', 'data-root'], Ctx);
  AssertEquals(EXIT_OK, Code, 'system env data-root exits 0');
  AssertTrue(Trim(OutBufObj.Text) <> '', 'system env data-root prints path');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'toolchain', 'check'], Ctx);
  AssertEquals(EXIT_OK, Code, 'system toolchain check exits 0');
  AssertTrue(Pos('"level"', OutBufObj.Text) > 0, 'system toolchain check prints report json');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'policy', 'check'], Ctx);
  AssertTrue((Code = EXIT_OK) or (Code = EXIT_USAGE_ERROR),
    'fpc policy check returns policy status code');
  AssertTrue(Pos('Policy ', OutBufObj.Text) > 0, 'fpc policy check prints policy summary');
end;

// ============================================================================
// Test: fpc help should cover all shipped fpc subcommands
// ============================================================================
procedure TestFPCHelpSubcommandsCoverage;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestFPCHelpSubcommandsCoverage');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'fpc help exits 0');
  AssertTrue(Pos('use, default', LowerCase(OutBufObj.Text)) = 0, 'fpc help should not mention default alias');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'help', 'verify'], Ctx);
  AssertEquals(EXIT_OK, Code, 'fpc help verify exits 0');
  AssertTrue(Pos('Usage: fpdev fpc verify', OutBufObj.Text) > 0, 'fpc help verify prints usage');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'help', 'auto-install'], Ctx);
  AssertEquals(EXIT_OK, Code, 'fpc help auto-install exits 0');
  AssertTrue(Pos('Usage: fpdev fpc auto-install', OutBufObj.Text) > 0, 'fpc help auto-install prints usage');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'help', 'update-manifest'], Ctx);
  AssertEquals(EXIT_OK, Code, 'fpc help update-manifest exits 0');
  AssertTrue(Pos('Usage: fpdev fpc update-manifest', OutBufObj.Text) > 0, 'fpc help update-manifest prints usage');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'help', 'cache'], Ctx);
  AssertEquals(EXIT_OK, Code, 'fpc help cache exits 0');
  AssertTrue(Pos('Usage: fpdev fpc cache <subcommand>', OutBufObj.Text) > 0, 'fpc help cache prints usage');
end;

// ============================================================================
// Test: cross help should cover all shipped cross subcommands
// ============================================================================
procedure TestCrossHelpSubcommandsCoverage;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestCrossHelpSubcommandsCoverage');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'help', 'update'], Ctx);
  AssertEquals(EXIT_OK, Code, 'cross help update exits 0');
  AssertTrue(Pos('Usage: fpdev cross update', OutBufObj.Text) > 0, 'cross help update prints usage');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'help', 'clean'], Ctx);
  AssertEquals(EXIT_OK, Code, 'cross help clean exits 0');
  AssertTrue(Pos('Usage: fpdev cross clean', OutBufObj.Text) > 0, 'cross help clean prints usage');
end;

procedure TestLazarusHelpContractDrift;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestLazarusHelpContractDrift');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'lazarus help exits 0');
  AssertTrue(Pos('use, default', LowerCase(OutBufObj.Text)) = 0, 'lazarus help should not mention default alias');
end;

// ============================================================================
// Test: package help should not advertise unregistered subcommands
// ============================================================================
procedure TestPackageHelpContractDrift;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestPackageHelpContractDrift');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['package', 'help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'package help exits 0');
  AssertTrue(Pos('  install-local', OutBufObj.Text) > 0, 'package help lists install-local');
  AssertTrue(Pos('  repo', OutBufObj.Text) > 0, 'package help lists repo');
  AssertTrue(Pos('  deps', OutBufObj.Text) > 0, 'package help lists deps');
  AssertTrue(Pos('  why', OutBufObj.Text) > 0, 'package help lists why');
  AssertTrue(Pos('dependency tree', OutBufObj.Text) > 0, 'package help deps description is shown');
  AssertTrue(Pos('dependency path', OutBufObj.Text) > 0, 'package help why description is shown');
  AssertTrue(Pos('  create', OutBufObj.Text) = 0, 'package help should not list create');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['package', 'help', 'create'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'package help create exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['package', 'help', 'deps'], Ctx);
  AssertEquals(EXIT_OK, Code, 'package help deps exits 0');
  AssertTrue(Pos('Usage: fpdev package deps', OutBufObj.Text) > 0, 'package help deps prints usage');
  AssertTrue(Pos('full options', OutBufObj.Text) > 0, 'package help deps prints hint');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['package', 'help', 'dependencies'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'package help dependencies exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['package', 'help', 'why'], Ctx);
  AssertEquals(EXIT_OK, Code, 'package help why exits 0');
  AssertTrue(Pos('Usage: fpdev package why', OutBufObj.Text) > 0, 'package help why prints usage');
  AssertTrue(Pos('for examples', OutBufObj.Text) > 0, 'package help why prints hint');
end;

// ============================================================================
// Test: removed shorthand aliases should stay removed in help routing
// ============================================================================
procedure TestHelpAliasPruningStaysEnforced;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestHelpAliasPruningStaysEnforced');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'repo', 'help', 'rm'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system repo help rm exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'repo', 'help', 'del'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system repo help del exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'repo', 'help', 'ls'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system repo help ls exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'help', 'config'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus help config exits usage error');
end;

// ============================================================================
// Test: Shell hook scripts should not hardcode $HOME/.fpdev paths
// ============================================================================
procedure TestShellHookNoHardcodedHomePath;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestShellHookNoHardcodedHomePath');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'env', 'hook', 'bash'], Ctx);
  AssertEquals(EXIT_OK, Code, 'system env hook bash exits 0');
  AssertTrue(Pos('$HOME/.fpdev/env', OutBufObj.Text) = 0, 'shell-hook bash should not hardcode $HOME/.fpdev/env');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'env', 'hook', 'fish'], Ctx);
  AssertEquals(EXIT_OK, Code, 'system env hook fish exits 0');
  AssertTrue(Pos('$HOME/.fpdev/env', OutBufObj.Text) = 0, 'shell-hook fish should not hardcode $HOME/.fpdev/env');
end;

// ============================================================================
// Test: Cross Build Dry-Run Should Not Fail Without Sources
// ============================================================================
procedure TestCrossBuildDryRunNoSources;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestCrossBuildDryRunNoSources');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(
    ['cross', 'build', 'x86_64-win64', '--dry-run', '--source=/tmp/fpdev-sources-missing'],
    Ctx
  );
  AssertEquals(EXIT_OK, Code, 'cross build --dry-run exits 0 even when sources are missing');
end;

// ============================================================================
// Test: fpc test should fall back to system FPC when no default toolchain exists
// ============================================================================
procedure TestFPCTestFallsBackToSystemFPC;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestFPCTestFallsBackToSystemFPC');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  // Ensure toolchain state is empty in this isolated test environment.
  Ctx.Config.GetToolchainManager.Clear;
  Ctx.SaveIfModified;

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'test'], Ctx);

  AssertEquals(EXIT_OK, Code, 'fpc test exits 0 by testing system FPC when no default toolchain is set');
  AssertTrue(Pos('Testing system FPC', OutBufObj.Text) > 0, 'fpc test prints system fallback message');
end;

// ============================================================================
// Test: Namespace help unknown subcommands must return usage error
// ============================================================================
procedure TestHelpUnknownSubcommandExitCode;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestHelpUnknownSubcommandExitCode');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'help', '__unknown__'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'fpc help unknown exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'help', 'default'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'fpc help default exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['package', 'help', '__unknown__'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'package help unknown exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['project', 'help', '__unknown__'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'project help unknown exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'repo', 'help', '__unknown__'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system repo help unknown exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'help', '__unknown__'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus help unknown exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'help', 'default'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus help default exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'help', '__unknown__'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross help unknown exits usage error');
end;

// ============================================================================
// Test: Namespace help must reject unexpected extra positional args
// ============================================================================
procedure TestHelpUnexpectedArgsExitCode;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestHelpUnexpectedArgsExitCode');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'help', 'list', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'fpc help extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['package', 'help', 'install', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'package help extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['project', 'help', 'new', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'project help extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'repo', 'help', 'add', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system repo help extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'help', 'install', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus help extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'help', 'build', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross help extra arg exits usage error');
end;

// ============================================================================
// Test: Core commands must reject unexpected args/options with usage error
// ============================================================================
procedure TestCommandUnexpectedArgsExitCode;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestCommandUnexpectedArgsExitCode');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'repo', 'list', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system repo list extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'repo', 'add', 'demo', 'https://example.com/r.json', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system repo add extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'repo', 'remove', 'demo', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system repo remove extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'repo', 'show', 'demo', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system repo show extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'repo', 'use', 'demo', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system repo use extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'repo', 'versions', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system repo versions positional arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'repo', 'versions', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system repo versions unknown flag exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'config', 'show', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'config show extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'config', 'list', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'config list unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'index', 'status', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'index status extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'cache', 'stats', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'system cache stats extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'env', 'vars', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'env vars extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'env', 'export', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'env export unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['system', 'env', 'export', '--shell'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'env export missing shell value exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'cache', 'list', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'fpc cache list extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'cache', 'stats', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'fpc cache stats unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'cache', 'path', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'fpc cache path extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'cache', 'clean', '--all', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'fpc cache clean extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'doctor', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'fpc doctor extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'current', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'fpc current extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'current', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'fpc current unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'update-manifest', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'fpc update-manifest extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'update-manifest', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'fpc update-manifest unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['fpc', 'update-manifest', '--force', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'fpc update-manifest --force extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'current', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus current extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'current', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus current unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'doctor', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus doctor extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'doctor', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus doctor unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'list', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross list extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'list', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross list unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'show', 'win64', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross show extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'show', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross show unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'doctor', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross doctor extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'doctor', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross doctor unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'run', '3.0', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus run extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'run', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus run unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'update', '3.0', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus update extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'update', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus update unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'enable', 'win64', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross enable extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'enable', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross enable unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'disable', 'win64', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross disable extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'disable', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross disable unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'install', 'win64', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross install extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'install', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross install unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'uninstall', 'win64', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross uninstall extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'uninstall', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross uninstall unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'configure', 'win64', '--binutils=/tmp/bin', '--libraries=/tmp/lib', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross configure extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'configure', 'win64', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross configure unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'test', 'win64', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross test extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'test', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross test unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'update', 'win64', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross update extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'update', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross update unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'clean', 'win64', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross clean extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'clean', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross clean unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'configure', '--help', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross configure help extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'test', '--help', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross test help extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'update', '--help', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross update help extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['cross', 'clean', '--help', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'cross clean help extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'install', '--help', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus install help extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'list', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus list extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'list', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus list unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'use', 'invalid-version', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus use extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'use', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus use unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'show', 'invalid-version', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus show extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'show', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus show unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'configure', 'invalid-version', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus configure extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'configure', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus configure unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'uninstall', 'invalid-version', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus uninstall extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'uninstall', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus uninstall unknown option exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'test', 'invalid-version', 'extra'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus test extra arg exits usage error');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.DispatchPath(['lazarus', 'test', '--unknown'], Ctx);
  AssertEquals(EXIT_USAGE_ERROR, Code, 'lazarus test unknown option exits usage error');
end;

// ============================================================================
// Main
// ============================================================================
begin
  WriteLn('========================================');
  WriteLn('B053: Command Registry Contract Tests');
  WriteLn('========================================');
  WriteLn('');

  TestContextUsesIsolatedConfigPath;
  TestRootCommandsRegistered;
  TestFPCSubcommandsRegistered;
  TestPackageSubcommandsRegistered;
  TestRepoSubcommandsRegistered;
  TestSystemSubcommandsRegistered;
  TestCommandCount;
  TestAliasResolution;
  TestUnknownCommandSuggestion;
  TestUnknownCommandFallsBackToAvailableCommands;
  TestMissingSubcommandUsage;
  TestRootHelpOutputUsesCurrentCLI;
  TestVersionHelpUsesGlobalSwitchSyntax;
    TestHelpFlagsDispatch;
    TestRootHelpHelperLeafFallback;
    TestRootHelpHelperUsesDynamicDomainHelp;
    TestSystemMaintenanceCommands;
    TestFPCHelpSubcommandsCoverage;
  TestCrossHelpSubcommandsCoverage;
  TestLazarusHelpContractDrift;
  TestPackageHelpContractDrift;
  TestHelpAliasPruningStaysEnforced;
  TestShellHookNoHardcodedHomePath;
  TestCrossBuildDryRunNoSources;
  TestFPCTestFallsBackToSystemFPC;
  TestHelpUnknownSubcommandExitCode;
  TestHelpUnexpectedArgsExitCode;
  TestCommandUnexpectedArgsExitCode;

  WriteLn('');
  WriteLn('========================================');
  if TestsFailed = 0 then
    WriteLn('SUCCESS: All ', TestsPassed, ' tests passed!')
  else
    WriteLn('FAILED: ', TestsFailed, ' of ', TestsPassed + TestsFailed, ' tests failed');
  WriteLn('========================================');

  if (GTempConfigRoot <> '') and DirectoryExists(GTempConfigRoot) then
    DeleteDirRecursive(GTempConfigRoot);

  if TestsFailed > 0 then
    Halt(1);
end.
