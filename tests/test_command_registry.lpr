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
  fpdev.config.interfaces,
  fpdev.config.managers,
  fpdev.exitcodes,
  fpdev.logger.intf,
  fpdev.output.intf,
  // Import all command units to trigger registration
  fpdev.cmd.help,
  fpdev.cmd.help.root,
  fpdev.cmd.version,
  fpdev.cmd.fpc,
  fpdev.cmd.fpc.root,
  fpdev.cmd.fpc.install,
  fpdev.cmd.fpc.autoinstall,
  fpdev.cmd.fpc.list,
  fpdev.cmd.fpc.use,
  fpdev.cmd.fpc.doctor,
  fpdev.cmd.fpc.current,
  fpdev.cmd.fpc.show,
  fpdev.cmd.fpc.test,
  fpdev.cmd.fpc.verify,
  fpdev.cmd.fpc.update,
  fpdev.cmd.fpc.update_manifest,
  fpdev.cmd.fpc.uninstall,
  fpdev.cmd.fpc.help,
  fpdev.cmd.fpc.cache,
  fpdev.cmd.fpc.cache.list,
  fpdev.cmd.fpc.cache.clean,
  fpdev.cmd.fpc.cache.stats,
  fpdev.cmd.fpc.cache.path,
  fpdev.cmd.repo.root,
  fpdev.cmd.repo.add,
  fpdev.cmd.repo.list,
  fpdev.cmd.repo.remove,
  fpdev.cmd.repo.default,
  fpdev.cmd.repo.show,
  fpdev.cmd.repo.versions,
  fpdev.cmd.repo.help,
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
  fpdev.cmd.cross.build,
  fpdev.cmd.package.root,
  fpdev.cmd.package.install,
  fpdev.cmd.package.list,
  fpdev.cmd.package.search,
  fpdev.cmd.package.info,
  fpdev.cmd.package.uninstall,
  fpdev.cmd.package.update,
  fpdev.cmd.package.clean,
  fpdev.cmd.package.install_local,
  fpdev.cmd.package.publish,
  fpdev.cmd.package.help,
  fpdev.cmd.project.root,
  fpdev.cmd.project.new,
  fpdev.cmd.project.list,
  fpdev.cmd.project.info,
  fpdev.cmd.project.build,
  fpdev.cmd.project.clean,
  fpdev.cmd.project.test,
  fpdev.cmd.project.run,
  fpdev.cmd.project.help,
  fpdev.cmd.shellhook,
  fpdev.cmd.resolveversion,
  fpdev.cmd.config,
  fpdev.cmd.config.list,
  fpdev.cmd.index,
  fpdev.cmd.cache,
  fpdev.cmd.perf,
  fpdev.cmd.env,
  fpdev.cmd.doctor,
  fpdev.cmd.default,
  fpdev.cmd.show;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

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
    FOut: IOutput;
    FErr: IOutput;
  public
    constructor Create(const AOut, AErr: IOutput);
    function Config: IConfigManager;
    function Out: IOutput;
    function Err: IOutput;
    function Logger: ILogger;
    procedure SaveIfModified;
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
  FConfig := TConfigManager.Create('') as IConfigManager;
  FConfig.LoadConfig;
  FOut := AOut;
  FErr := AErr;
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
// Test: Root Commands Registered
// ============================================================================
procedure TestRootCommandsRegistered;
var
  Children: TStringArray;
  i: Integer;
  HasFPC, HasLazarus, HasPackage, HasCross, HasRepo, HasProject: Boolean;
begin
  WriteLn('[TEST] TestRootCommandsRegistered');

  Children := GlobalCommandRegistry.ListChildren([]);

  HasFPC := False;
  HasLazarus := False;
  HasPackage := False;
  HasCross := False;
  HasRepo := False;
  HasProject := False;

  for i := 0 to High(Children) do
  begin
    case LowerCase(Children[i]) of
      'fpc': HasFPC := True;
      'lazarus': HasLazarus := True;
      'package', 'pkg': HasPackage := True;
      'cross': HasCross := True;
      'repo': HasRepo := True;
      'project': HasProject := True;
    end;
  end;

  AssertTrue(HasFPC, 'fpc command registered');
  AssertTrue(HasLazarus, 'lazarus command registered');
  AssertTrue(HasPackage, 'package command registered');
  AssertTrue(HasCross, 'cross command registered');
  AssertTrue(HasRepo, 'repo command registered');
  AssertTrue(HasProject, 'project command registered');
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
  HasAdd, HasRemove, HasList, HasDefault: Boolean;
begin
  WriteLn('[TEST] TestRepoSubcommandsRegistered');

  Children := GlobalCommandRegistry.ListChildren(['repo']);

  HasAdd := False;
  HasRemove := False;
  HasList := False;
  HasDefault := False;

  for i := 0 to High(Children) do
  begin
    case LowerCase(Children[i]) of
      'add': HasAdd := True;
      'remove', 'rm': HasRemove := True;
      'list', 'ls': HasList := True;
      'default': HasDefault := True;
    end;
  end;

  AssertTrue(HasAdd, 'repo add registered');
  AssertTrue(HasRemove, 'repo remove registered');
  AssertTrue(HasList, 'repo list registered');
  AssertTrue(HasDefault, 'repo default registered');
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
  AssertTrue(Length(RootChildren) >= 10, 'Root has >= 10 commands (got ' + IntToStr(Length(RootChildren)) + ')');

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

  RepoChildren := GlobalCommandRegistry.ListChildren(['repo']);

  HasRm := False;
  for i := 0 to High(RepoChildren) do
    if LowerCase(RepoChildren[i]) = 'rm' then
      HasRm := True;

  AssertTrue(HasRm, 'repo rm alias registered');
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
  Code := GlobalCommandRegistry.Dispatch(['shell-hook', '--help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'shell-hook --help exits 0');
  AssertTrue(Pos('Usage: fpdev shell-hook', OutBufObj.Text) > 0, 'shell-hook --help prints usage');

  // Namespaced leaf commands should accept --help and print usage
  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.Dispatch(['fpc', 'test', '--help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'fpc test --help exits 0');
  AssertTrue(Pos('Usage: fpdev fpc test', OutBufObj.Text) > 0, 'fpc test --help prints usage');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.Dispatch(['cross', 'test', '--help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'cross test --help exits 0');
  AssertTrue(Pos('Usage: fpdev cross test', OutBufObj.Text) > 0, 'cross test --help prints usage');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.Dispatch(['lazarus', 'run', '--help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'lazarus run --help exits 0');
  AssertTrue(Pos('Usage: fpdev lazarus run', OutBufObj.Text) > 0, 'lazarus run --help prints usage');

  // Standalone command should provide usage for --help
  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.Dispatch(['resolve-version', '--help'], Ctx);
  AssertEquals(EXIT_OK, Code, 'resolve-version --help exits 0');
  AssertTrue(Pos('Usage: fpdev resolve-version', OutBufObj.Text) > 0, 'resolve-version --help prints usage');
end;

// ============================================================================
// Test: "fpdev help <leaf>" Should Print Leaf Usage
// ============================================================================
procedure TestHelpCommandLeafFallback;
var
  OutBufObj, ErrBufObj: TBufferOutput;
  Ctx: IContext;
  Code: Integer;
begin
  WriteLn('[TEST] TestHelpCommandLeafFallback');

  OutBufObj := TBufferOutput.Create;
  ErrBufObj := TBufferOutput.Create;
  Ctx := TTestContext.Create(OutBufObj as IOutput, ErrBufObj as IOutput);

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.Dispatch(['help', 'shell-hook'], Ctx);
  AssertEquals(EXIT_OK, Code, 'help shell-hook exits 0');
  AssertTrue(Pos('Usage: fpdev shell-hook', OutBufObj.Text) > 0, 'help shell-hook prints usage');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.Dispatch(['help', 'env'], Ctx);
  AssertEquals(EXIT_OK, Code, 'help env exits 0');
  AssertTrue(Pos('Usage: fpdev env', OutBufObj.Text) > 0, 'help env prints usage');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.Dispatch(['help', 'resolve-version'], Ctx);
  AssertEquals(EXIT_OK, Code, 'help resolve-version exits 0');
  AssertTrue(Pos('Usage: fpdev resolve-version', OutBufObj.Text) > 0, 'help resolve-version prints usage');
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
  Code := GlobalCommandRegistry.Dispatch(['shell-hook', 'bash'], Ctx);
  AssertEquals(EXIT_OK, Code, 'shell-hook bash exits 0');
  AssertTrue(Pos('$HOME/.fpdev/env', OutBufObj.Text) = 0, 'shell-hook bash should not hardcode $HOME/.fpdev/env');

  OutBufObj.Clear;
  ErrBufObj.Clear;
  Code := GlobalCommandRegistry.Dispatch(['shell-hook', 'fish'], Ctx);
  AssertEquals(EXIT_OK, Code, 'shell-hook fish exits 0');
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
  Code := GlobalCommandRegistry.Dispatch(
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
  Code := GlobalCommandRegistry.Dispatch(['fpc', 'test'], Ctx);

  AssertEquals(EXIT_OK, Code, 'fpc test exits 0 by testing system FPC when no default toolchain is set');
  AssertTrue(Pos('Testing system FPC', OutBufObj.Text) > 0, 'fpc test prints system fallback message');
end;

// ============================================================================
// Main
// ============================================================================
begin
  WriteLn('========================================');
  WriteLn('B053: Command Registry Contract Tests');
  WriteLn('========================================');
  WriteLn('');

  TestRootCommandsRegistered;
  TestFPCSubcommandsRegistered;
  TestPackageSubcommandsRegistered;
  TestRepoSubcommandsRegistered;
  TestCommandCount;
  TestAliasResolution;
  TestHelpFlagsDispatch;
  TestHelpCommandLeafFallback;
  TestShellHookNoHardcodedHomePath;
  TestCrossBuildDryRunNoSources;
  TestFPCTestFallsBackToSystemFPC;

  WriteLn('');
  WriteLn('========================================');
  if TestsFailed = 0 then
    WriteLn('SUCCESS: All ', TestsPassed, ' tests passed!')
  else
    WriteLn('FAILED: ', TestsFailed, ' of ', TestsPassed + TestsFailed, ' tests failed');
  WriteLn('========================================');

  if TestsFailed > 0 then
    Halt(1);
end.
