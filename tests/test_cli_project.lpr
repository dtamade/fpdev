program test_cli_project;

{$mode objfpc}{$H+}

{
================================================================================
  test_cli_project - CLI tests for all project sub-commands
================================================================================

  Covers: new, build, run, test, clean, list, info, help

  B199: Project command CLI test coverage
  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.exitcodes,
  fpdev.cmd.project.root,
  fpdev.cmd.project.new,
  fpdev.cmd.project.build,
  fpdev.cmd.project.run,
  fpdev.cmd.project.test,
  fpdev.cmd.project.clean,
  fpdev.cmd.project.list,
  fpdev.cmd.project.info,
  fpdev.cmd.project.help,
  test_cli_helpers, test_temp_paths;

var
  GTempDir: string;

{ ===== new ===== }

procedure TestNewName;
var Cmd: TProjectNewCommand;
begin
  Cmd := TProjectNewCommand.Create;
  try Check('new: name', Cmd.Name = 'new'); finally Cmd.Free; end;
end;

procedure TestNewHelp;
var Cmd: TProjectNewCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectNewCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('new --help EXIT_OK', Ret = EXIT_OK);
    Check('new --help shows usage', StdOut.Contains('new'));
  finally Cmd.Free; end;
end;

procedure TestNewMissingArgs;
var Cmd: TProjectNewCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectNewCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('new no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestNewUnexpectedArg;
var Cmd: TProjectNewCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectNewCommand.Create;
  try
    Ret := Cmd.Execute(['console', 'demo', '.', 'extra'], Ctx);
    Check('new unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('new unexpected arg shows usage', StdErr.Contains('Usage: fpdev project new <template> <name> [dir]'));
    Check('new unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

procedure TestNewUnknownOption;
var Cmd: TProjectNewCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectNewCommand.Create;
  try
    Ret := Cmd.Execute(['console', 'demo', '--unknown'], Ctx);
    Check('new unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('new unknown option shows usage', StdErr.Contains('Usage: fpdev project new <template> <name> [dir]'));
    Check('new unknown option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

procedure TestNewUnavailableTemplate;
var Cmd: TProjectNewCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
    BaseDir, ProjectDir: string;
begin
  BaseDir := GTempDir + PathDelim + 'unsupported-template';
  ProjectDir := BaseDir + PathDelim + 'demo';
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectNewCommand.Create;
  try
    Ret := Cmd.Execute(['webapp', 'demo', BaseDir], Ctx);
    Check('new unavailable template EXIT_ERROR', Ret = EXIT_ERROR);
    Check('new unavailable template shows error', StdErr.Contains('Failed to create project'));
    Check('new unavailable template does not create project dir', not DirectoryExists(ProjectDir));
  finally Cmd.Free; end;
end;

{ ===== build ===== }

procedure TestBuildName;
var Cmd: TProjectBuildCommand;
begin
  Cmd := TProjectBuildCommand.Create;
  try Check('build: name', Cmd.Name = 'build'); finally Cmd.Free; end;
end;

procedure TestBuildHelp;
var Cmd: TProjectBuildCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectBuildCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('build --help EXIT_OK', Ret = EXIT_OK);
    Check('build --help shows usage', StdOut.Contains('build'));
  finally Cmd.Free; end;
end;

procedure TestBuildNoArgs;
var Cmd: TProjectBuildCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectBuildCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('build no args returns valid code', Ret >= 0);
  finally Cmd.Free; end;
end;

procedure TestBuildUnexpectedArg;
var Cmd: TProjectBuildCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectBuildCommand.Create;
  try
    Ret := Cmd.Execute(['.', 'win64', 'extra'], Ctx);
    Check('build unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('build unexpected arg shows usage', StdErr.Contains('Usage: fpdev project build [dir] [target]'));
    Check('build unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

procedure TestBuildUnknownOption;
var Cmd: TProjectBuildCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectBuildCommand.Create;
  try
    Ret := Cmd.Execute(['.', '--unknown'], Ctx);
    Check('build unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('build unknown option shows usage', StdErr.Contains('Usage: fpdev project build [dir] [target]'));
    Check('build unknown option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

{ ===== run ===== }

procedure TestRunName;
var Cmd: TProjectRunCommand;
begin
  Cmd := TProjectRunCommand.Create;
  try Check('run: name', Cmd.Name = 'run'); finally Cmd.Free; end;
end;

procedure TestRunHelp;
var Cmd: TProjectRunCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectRunCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('run --help EXIT_OK', Ret = EXIT_OK);
    Check('run --help shows usage', StdOut.Contains('run'));
  finally Cmd.Free; end;
end;

procedure TestRunNoArgs;
var Cmd: TProjectRunCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectRunCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('run no args returns valid code', Ret >= 0);
  finally Cmd.Free; end;
end;

procedure TestRunAcceptsOptionLikeArgs;
var Cmd: TProjectRunCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectRunCommand.Create;
  try
    Ret := Cmd.Execute(['.', '--demo-flag', 'value'], Ctx);
    Check('run option-like args avoid usage error', Ret <> EXIT_USAGE_ERROR);
    Check('run option-like args do not print usage', not StdErr.Contains('Usage: fpdev project run [dir] [args...]'));
  finally Cmd.Free; end;
end;

{ ===== test ===== }

procedure TestTestName;
var Cmd: TProjectTestCommand;
begin
  Cmd := TProjectTestCommand.Create;
  try Check('test: name', Cmd.Name = 'test'); finally Cmd.Free; end;
end;

procedure TestTestHelp;
var Cmd: TProjectTestCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectTestCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('test --help EXIT_OK', Ret = EXIT_OK);
    Check('test --help shows usage', StdOut.Contains('test'));
  finally Cmd.Free; end;
end;

procedure TestTestNoArgs;
var Cmd: TProjectTestCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectTestCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('test no args returns valid code', Ret >= 0);
  finally Cmd.Free; end;
end;

procedure TestTestUnexpectedArg;
var Cmd: TProjectTestCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectTestCommand.Create;
  try
    Ret := Cmd.Execute(['.', 'extra'], Ctx);
    Check('test unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('test unexpected arg shows usage', StdErr.Contains('Usage: fpdev project test [dir]'));
    Check('test unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

procedure TestTestUnknownOption;
var Cmd: TProjectTestCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectTestCommand.Create;
  try
    Ret := Cmd.Execute(['.', '--unknown'], Ctx);
    Check('test unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('test unknown option shows usage', StdErr.Contains('Usage: fpdev project test [dir]'));
    Check('test unknown option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

{ ===== clean ===== }

procedure TestCleanName;
var Cmd: TProjectCleanCommand;
begin
  Cmd := TProjectCleanCommand.Create;
  try Check('clean: name', Cmd.Name = 'clean'); finally Cmd.Free; end;
end;

procedure TestCleanHelp;
var Cmd: TProjectCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectCleanCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('clean --help EXIT_OK', Ret = EXIT_OK);
    Check('clean --help shows usage', StdOut.Contains('clean'));
  finally Cmd.Free; end;
end;

procedure TestCleanNoArgs;
var Cmd: TProjectCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectCleanCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('clean no args returns valid code', Ret >= 0);
  finally Cmd.Free; end;
end;

procedure TestCleanUnknownOption;
var Cmd: TProjectCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectCleanCommand.Create;
  try
    Ret := Cmd.Execute(['.', '--unknown'], Ctx);
    Check('clean unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('clean unknown option shows usage', StdErr.Contains('Usage: fpdev project clean [dir]'));
    Check('clean unknown option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

procedure TestCleanUnexpectedArg;
var Cmd: TProjectCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectCleanCommand.Create;
  try
    Ret := Cmd.Execute(['.', 'extra'], Ctx);
    Check('clean unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('clean unexpected arg shows usage', StdErr.Contains('Usage: fpdev project clean [dir]'));
    Check('clean unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

{ ===== list ===== }

procedure TestListName;
var Cmd: TProjectListCommand;
begin
  Cmd := TProjectListCommand.Create;
  try Check('list: name', Cmd.Name = 'list'); finally Cmd.Free; end;
end;

procedure TestListHelp;
var Cmd: TProjectListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectListCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('list --help EXIT_OK', Ret = EXIT_OK);
    Check('list --help shows --json', StdOut.Contains('json'));
  finally Cmd.Free; end;
end;

procedure TestListNoArgs;
var Cmd: TProjectListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectListCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('list no args EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestListJsonOutput;
var Cmd: TProjectListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectListCommand.Create;
  try
    Ret := Cmd.Execute(['--json'], Ctx);
    Check('list --json EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestListHelpRejectsExtraOption;
var Cmd: TProjectListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectListCommand.Create;
  try
    Ret := Cmd.Execute(['--help', '--json'], Ctx);
    Check('list --help with extra option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('list --help with extra option shows usage', StdErr.Contains('Usage: fpdev project list [--json]'));
    Check('list --help with extra option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

procedure TestListUnexpectedArg;
var Cmd: TProjectListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectListCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('list unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('list unexpected arg shows usage', StdErr.Contains('Usage: fpdev project list [--json]'));
    Check('list unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

procedure TestListUnknownOption;
var Cmd: TProjectListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectListCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('list unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('list unknown option shows usage', StdErr.Contains('Usage: fpdev project list [--json]'));
    Check('list unknown option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

procedure TestListOmitsUnavailableTemplate;
var Cmd: TProjectListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectListCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('list omits unavailable template EXIT_OK', Ret = EXIT_OK);
    Check('list omits unavailable template keeps stderr empty', Trim(StdErr.GetBuffer) = '');
    Check('list omits unavailable template from stdout', not StdOut.Contains('webapp'));
    Check('list still shows library template', StdOut.Contains('library'));
  finally Cmd.Free; end;
end;

{ ===== info ===== }

procedure TestInfoName;
var Cmd: TProjectInfoCommand;
begin
  Cmd := TProjectInfoCommand.Create;
  try Check('info: name', Cmd.Name = 'info'); finally Cmd.Free; end;
end;

procedure TestInfoHelp;
var Cmd: TProjectInfoCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectInfoCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('info --help EXIT_OK', Ret = EXIT_OK);
    Check('info --help shows usage', StdOut.Contains('info'));
  finally Cmd.Free; end;
end;

procedure TestInfoMissingTemplate;
var Cmd: TProjectInfoCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectInfoCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('info no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestInfoUnexpectedArg;
var Cmd: TProjectInfoCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectInfoCommand.Create;
  try
    Ret := Cmd.Execute(['console', 'extra'], Ctx);
    Check('info unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('info unexpected arg shows usage', StdErr.Contains('Usage: fpdev project info <template>'));
    Check('info unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

procedure TestInfoUnknownOption;
var Cmd: TProjectInfoCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectInfoCommand.Create;
  try
    Ret := Cmd.Execute(['console', '--unknown'], Ctx);
    Check('info unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('info unknown option shows usage', StdErr.Contains('Usage: fpdev project info <template>'));
    Check('info unknown option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

procedure TestInfoUnavailableTemplate;
var Cmd: TProjectInfoCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectInfoCommand.Create;
  try
    Ret := Cmd.Execute(['webapp'], Ctx);
    Check('info unavailable template EXIT_ERROR', Ret = EXIT_ERROR);
    Check('info unavailable template reports missing template', StdErr.Contains('Template not found: webapp'));
    Check('info unavailable template keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

{ ===== help ===== }

procedure TestHelpName;
var Cmd: TProjectHelpCommand;
begin
  Cmd := TProjectHelpCommand.Create;
  try Check('help: name', Cmd.Name = 'help'); finally Cmd.Free; end;
end;

procedure TestHelpNoArgs;
var Cmd: TProjectHelpCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectHelpCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('help no args EXIT_OK', Ret = EXIT_OK);
    Check('help shows project commands', StdOut.Contains('new'));
  finally Cmd.Free; end;
end;

procedure TestHelpUnexpectedArg;
var Cmd: TProjectHelpCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectHelpCommand.Create;
  try
    Ret := Cmd.Execute(['new', 'extra'], Ctx);
    Check('help unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== Registration ===== }

procedure TestProjectRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundNew, FoundBuild, FoundRun, FoundTest: Boolean;
  FoundClean, FoundList, FoundInfo, FoundHelp: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['project']);
  FoundNew := False; FoundBuild := False; FoundRun := False;
  FoundTest := False; FoundClean := False; FoundList := False;
  FoundInfo := False; FoundHelp := False;

  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'new' then FoundNew := True;
    if Children[I] = 'build' then FoundBuild := True;
    if Children[I] = 'run' then FoundRun := True;
    if Children[I] = 'test' then FoundTest := True;
    if Children[I] = 'clean' then FoundClean := True;
    if Children[I] = 'list' then FoundList := True;
    if Children[I] = 'info' then FoundInfo := True;
    if Children[I] = 'help' then FoundHelp := True;
  end;

  Check('project new registered', FoundNew);
  Check('project build registered', FoundBuild);
  Check('project run registered', FoundRun);
  Check('project test registered', FoundTest);
  Check('project clean registered', FoundClean);
  Check('project list registered', FoundList);
  Check('project info registered', FoundInfo);
  Check('project help registered', FoundHelp);
end;

{ ===== Main ===== }
begin
  WriteLn('=== Project Commands CLI Tests (B199) ===');
  WriteLn;

  GTempDir := CreateUniqueTempDir('fpdev_test_proj');
  Check('temp dir uses system temp root', PathUsesSystemTempRoot(GTempDir));

  try
    WriteLn('--- new ---');
    TestNewName;
    TestNewHelp;
    TestNewMissingArgs;
    TestNewUnexpectedArg;
    TestNewUnknownOption;
    TestNewUnavailableTemplate;

    WriteLn('');
    WriteLn('--- build ---');
    TestBuildName;
    TestBuildHelp;
    TestBuildNoArgs;
    TestBuildUnexpectedArg;
    TestBuildUnknownOption;

    WriteLn('');
    WriteLn('--- run ---');
    TestRunName;
    TestRunHelp;
    TestRunNoArgs;
    TestRunAcceptsOptionLikeArgs;

    WriteLn('');
    WriteLn('--- test ---');
    TestTestName;
    TestTestHelp;
    TestTestNoArgs;
    TestTestUnexpectedArg;
    TestTestUnknownOption;

    WriteLn('');
    WriteLn('--- clean ---');
    TestCleanName;
    TestCleanHelp;
    TestCleanNoArgs;
    TestCleanUnexpectedArg;
    TestCleanUnknownOption;

    WriteLn('');
    WriteLn('--- list ---');
    TestListName;
    TestListHelp;
    TestListNoArgs;
    TestListJsonOutput;
    TestListHelpRejectsExtraOption;
    TestListUnexpectedArg;
    TestListUnknownOption;
    TestListOmitsUnavailableTemplate;

    WriteLn('');
    WriteLn('--- info ---');
    TestInfoName;
    TestInfoHelp;
    TestInfoMissingTemplate;
    TestInfoUnexpectedArg;
    TestInfoUnknownOption;
    TestInfoUnavailableTemplate;

    WriteLn('');
    WriteLn('--- help ---');
    TestHelpName;
    TestHelpNoArgs;
    TestHelpUnexpectedArg;

    WriteLn('');
    WriteLn('--- Registration ---');
    TestProjectRegistration;
  finally
    CleanupTempDir(GTempDir);
  end;

  Halt(PrintTestSummary);
end.
