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
  test_cli_helpers;

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

  GTempDir := GetTempDir + 'fpdev_test_proj_' + IntToStr(GetTickCount64);
  ForceDirectories(GTempDir);

  try
    WriteLn('--- new ---');
    TestNewName;
    TestNewHelp;
    TestNewMissingArgs;

    WriteLn('');
    WriteLn('--- build ---');
    TestBuildName;
    TestBuildHelp;
    TestBuildNoArgs;

    WriteLn('');
    WriteLn('--- run ---');
    TestRunName;
    TestRunHelp;
    TestRunNoArgs;

    WriteLn('');
    WriteLn('--- test ---');
    TestTestName;
    TestTestHelp;
    TestTestNoArgs;

    WriteLn('');
    WriteLn('--- clean ---');
    TestCleanName;
    TestCleanHelp;
    TestCleanNoArgs;

    WriteLn('');
    WriteLn('--- list ---');
    TestListName;
    TestListHelp;
    TestListNoArgs;
    TestListJsonOutput;

    WriteLn('');
    WriteLn('--- info ---');
    TestInfoName;
    TestInfoHelp;
    TestInfoMissingTemplate;

    WriteLn('');
    WriteLn('--- help ---');
    TestHelpName;
    TestHelpNoArgs;

    WriteLn('');
    WriteLn('--- Registration ---');
    TestProjectRegistration;
  finally
    if DirectoryExists(GTempDir) then
    begin
      DeleteFile(GTempDir + PathDelim + 'config.json');
      RemoveDir(GTempDir);
    end;
  end;

  Halt(PrintTestSummary);
end.
