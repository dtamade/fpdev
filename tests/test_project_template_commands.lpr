program test_project_template_commands;

{$mode objfpc}{$H+}

{
  B243-B246: Tests for project template command registration and subcommands
}

uses
  SysUtils, Classes,
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.config.interfaces,
  fpdev.paths,
  fpdev.exitcodes,
  fpdev.cmd.project.root,
  fpdev.cmd.project.template.root,
  fpdev.cmd.project.template.list,
  fpdev.cmd.project.template.install,
  fpdev.cmd.project.template.remove,
  fpdev.cmd.project.template.update,
  fpdev.utils,
  fpdev.utils.process,
  test_cli_helpers,
  test_temp_paths;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  GTempDir: string = '';
  GTemplateUpdateDataRoot: string = '';
  GSavedDataRoot: string = '';

procedure Check(const ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

function HasSubcommand(const APath: array of string; const AName: string): Boolean;
var
  Children: TStringArray;
  i: Integer;
begin
  Result := False;
  Children := GlobalCommandRegistry.ListChildren(APath);
  for i := Low(Children) to High(Children) do
    if LowerCase(Children[i]) = LowerCase(AName) then
      Exit(True);
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

procedure WriteTextFile(const APath, AContent: string);
var
  Lines: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  Lines := TStringList.Create;
  try
    Lines.Text := AContent;
    Lines.SaveToFile(APath);
  finally
    Lines.Free;
  end;
end;

function RunCommandInDir(const AProgram: string; const AArgs: array of string;
  const AWorkDir: string): Boolean;
var
  ProcResult: TProcessResult;
begin
  ProcResult := TProcessExecutor.Execute(AProgram, AArgs, AWorkDir);
  Result := ProcResult.Success and (ProcResult.ExitCode = 0);
  if not Result then
  begin
    WriteLn('[CMD FAIL] ', AProgram, ' in ', AWorkDir);
    if ProcResult.StdOut <> '' then
      WriteLn('stdout: ', ProcResult.StdOut);
    if ProcResult.StdErr <> '' then
      WriteLn('stderr: ', ProcResult.StdErr);
    if ProcResult.ErrorMessage <> '' then
      WriteLn('error: ', ProcResult.ErrorMessage);
  end;
end;

function CommitAll(const ARepoDir, AMessage: string): Boolean;
begin
  Result :=
    RunCommandInDir('git', ['add', '-A'], ARepoDir) and
    RunCommandInDir('git', ['commit', '-m', AMessage], ARepoDir);
end;

function SetInstallRoot(const Ctx: IContext; const AInstallRoot: string): Boolean;
var
  Settings: TFPDevSettings;
begin
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := AInstallRoot;
  Result := Ctx.Config.GetSettingsManager.SetSettings(Settings);
end;

procedure SetupLocalTemplateUpdateRepo;
var
  RepoDir, TemplatesDir: string;
begin
  GSavedDataRoot := get_env('FPDEV_DATA_ROOT');
  GTemplateUpdateDataRoot := CreateUniqueTempDir('fpdev_test_project_template_update_data');
  SetPortableMode(False);
  set_env('FPDEV_DATA_ROOT', GTemplateUpdateDataRoot);

  RepoDir := IncludeTrailingPathDelimiter(GTemplateUpdateDataRoot) + 'resources';
  TemplatesDir := RepoDir + PathDelim + 'templates';
  ForceDirectories(TemplatesDir);
  WriteTextFile(RepoDir + PathDelim + 'manifest.json', '{"version":"1.0.0"}');

  if not RunCommandInDir('git', ['init'], RepoDir) then
    raise Exception.Create('Failed to initialize local template update repo');
  if not RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], RepoDir) then
    raise Exception.Create('Failed to configure template update repo email');
  if not RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], RepoDir) then
    raise Exception.Create('Failed to configure template update repo user');
  if not RunCommandInDir('git', ['add', 'manifest.json'], RepoDir) then
    raise Exception.Create('Failed to stage template update manifest');
  if not RunCommandInDir('git', ['commit', '-m', 'initial'], RepoDir) then
    raise Exception.Create('Failed to commit template update manifest');
  if not RunCommandInDir('git', ['branch', '-M', 'main'], RepoDir) then
    raise Exception.Create('Failed to rename template update branch');
end;

{ --- Root Registration Tests --- }

procedure TestProjectRootRegistered;
begin
  Check(HasSubcommand([], 'project'), 'project: root registered');
end;

procedure TestTemplateRootRegistered;
begin
  Check(HasSubcommand(['project'], 'template'), 'project template: registered as subcommand');
end;

procedure TestTemplateAliasRegistered;
begin
  Check(not HasSubcommand(['project'], 'tpl'), 'project tpl alias removed');
end;

{ --- Subcommand Registration Tests --- }

procedure TestTemplateListRegistered;
begin
  Check(HasSubcommand(['project','template'], 'list'), 'project template list: registered');
end;

procedure TestTemplateListAliasRegistered;
begin
  Check(not HasSubcommand(['project','template'], 'ls'), 'project template ls alias removed');
end;

procedure TestTemplateInstallRegistered;
begin
  Check(HasSubcommand(['project','template'], 'install'), 'project template install: registered');
end;

procedure TestTemplateRemoveRegistered;
begin
  Check(HasSubcommand(['project','template'], 'remove'), 'project template remove: registered');
end;

procedure TestTemplateRemoveAliasRegistered;
begin
  Check(not HasSubcommand(['project','template'], 'rm'), 'project template rm alias removed');
end;

procedure TestTemplateUpdateRegistered;
begin
  Check(HasSubcommand(['project','template'], 'update'), 'project template update: registered');
end;

{ --- Count Tests --- }

procedure TestTemplateSubcommandCount;
var
  Children: TStringArray;
begin
  Children := GlobalCommandRegistry.ListChildren(['project','template']);
  Check(Length(Children) >= 4, 'project template: at least 4 subcommands (list, install, remove, update)');
end;

{ --- Command Name Tests --- }

procedure TestListCommandName;
var
  Cmd: ICommand;
begin
  Cmd := TProjectTemplateListCommand.Create;
  Check(Cmd.Name = 'list', 'template list: Name returns "list"');
end;

procedure TestInstallCommandName;
var
  Cmd: ICommand;
begin
  Cmd := TProjectTemplateInstallCommand.Create;
  Check(Cmd.Name = 'install', 'template install: Name returns "install"');
end;

procedure TestRemoveCommandName;
var
  Cmd: ICommand;
begin
  Cmd := TProjectTemplateRemoveCommand.Create;
  Check(Cmd.Name = 'remove', 'template remove: Name returns "remove"');
end;

procedure TestUpdateCommandName;
var
  Cmd: ICommand;
begin
  Cmd := TProjectTemplateUpdateCommand.Create;
  Check(Cmd.Name = 'update', 'template update: Name returns "update"');
end;

{ --- FindSub Tests --- }

procedure TestListFindSubNil;
var
  Cmd: ICommand;
begin
  Cmd := TProjectTemplateListCommand.Create;
  Check(Cmd.FindSub('anything') = nil, 'template list: FindSub returns nil');
end;

procedure TestInstallFindSubNil;
var
  Cmd: ICommand;
begin
  Cmd := TProjectTemplateInstallCommand.Create;
  Check(Cmd.FindSub('anything') = nil, 'template install: FindSub returns nil');
end;

{ --- Direct CLI Contract Tests --- }

procedure TestListUnexpectedArg;
var
  Cmd: TProjectTemplateListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectTemplateListCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check(Ret = EXIT_USAGE_ERROR, 'template list unexpected arg EXIT_USAGE_ERROR');
    Check(Trim(StdOut.GetBuffer) = '', 'template list unexpected arg keeps stdout empty');
    Check(StdErr.Contains('Usage: fpdev project template list'),
      'template list unexpected arg shows usage');
  finally
    Cmd.Free;
  end;
end;

procedure TestListUnknownOption;
var
  Cmd: TProjectTemplateListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectTemplateListCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check(Ret = EXIT_USAGE_ERROR, 'template list unknown option EXIT_USAGE_ERROR');
    Check(Trim(StdOut.GetBuffer) = '', 'template list unknown option keeps stdout empty');
    Check(StdErr.Contains('Usage: fpdev project template list'),
      'template list unknown option shows usage');
  finally
    Cmd.Free;
  end;
end;

procedure TestInstallUnexpectedArg;
var
  Cmd: TProjectTemplateInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectTemplateInstallCommand.Create;
  try
    Ret := Cmd.Execute(['missing_template_path', 'extra'], Ctx);
    Check(Ret = EXIT_USAGE_ERROR, 'template install unexpected arg EXIT_USAGE_ERROR');
    Check(Trim(StdOut.GetBuffer) = '', 'template install unexpected arg keeps stdout empty');
    Check(StdErr.Contains('Usage: fpdev project template install <path>'),
      'template install unexpected arg shows usage');
  finally
    Cmd.Free;
  end;
end;

procedure TestInstallUnknownOption;
var
  Cmd: TProjectTemplateInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectTemplateInstallCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check(Ret = EXIT_USAGE_ERROR, 'template install unknown option EXIT_USAGE_ERROR');
    Check(Trim(StdOut.GetBuffer) = '', 'template install unknown option keeps stdout empty');
    Check(StdErr.Contains('Usage: fpdev project template install <path>'),
      'template install unknown option shows usage');
  finally
    Cmd.Free;
  end;
end;

procedure TestRemoveUnexpectedArg;
var
  Cmd: TProjectTemplateRemoveCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectTemplateRemoveCommand.Create;
  try
    Ret := Cmd.Execute(['missing_template_name', 'extra'], Ctx);
    Check(Ret = EXIT_USAGE_ERROR, 'template remove unexpected arg EXIT_USAGE_ERROR');
    Check(Trim(StdOut.GetBuffer) = '', 'template remove unexpected arg keeps stdout empty');
    Check(StdErr.Contains('Usage: fpdev project template remove <name>'),
      'template remove unexpected arg shows usage');
  finally
    Cmd.Free;
  end;
end;

procedure TestRemoveUnknownOption;
var
  Cmd: TProjectTemplateRemoveCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectTemplateRemoveCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check(Ret = EXIT_USAGE_ERROR, 'template remove unknown option EXIT_USAGE_ERROR');
    Check(Trim(StdOut.GetBuffer) = '', 'template remove unknown option keeps stdout empty');
    Check(StdErr.Contains('Usage: fpdev project template remove <name>'),
      'template remove unknown option shows usage');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateUnexpectedArg;
var
  Cmd: TProjectTemplateUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectTemplateUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check(Ret = EXIT_USAGE_ERROR, 'template update unexpected arg EXIT_USAGE_ERROR');
    Check(Trim(StdOut.GetBuffer) = '', 'template update unexpected arg keeps stdout empty');
    Check(StdErr.Contains('Usage: fpdev project template update'),
      'template update unexpected arg shows usage');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateUnknownOption;
var
  Cmd: TProjectTemplateUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TProjectTemplateUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check(Ret = EXIT_USAGE_ERROR, 'template update unknown option EXIT_USAGE_ERROR');
    Check(Trim(StdOut.GetBuffer) = '', 'template update unknown option keeps stdout empty');
    Check(StdErr.Contains('Usage: fpdev project template update'),
      'template update unknown option shows usage');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateCopiesTemplatesFromLocalResourceRepo;
var
  Cmd: TProjectTemplateUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  RepoDir, TemplateDir, InstallRoot: string;
  TemplateMetaDest, NestedDest: string;
begin
  RepoDir := IncludeTrailingPathDelimiter(GTemplateUpdateDataRoot) + 'resources';
  TemplateDir := RepoDir + PathDelim + 'templates' + PathDelim + 'console';
  WriteTextFile(TemplateDir + PathDelim + 'template.json',
    '{"name":"console","version":"1.0.0"}');
  WriteTextFile(TemplateDir + PathDelim + 'src' + PathDelim + 'main.pas',
    'program generated;' + LineEnding);
  if not CommitAll(RepoDir, 'add console template') then
    raise Exception.Create('Failed to commit template update repo fixture');

  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  InstallRoot := GTempDir + PathDelim + 'install-root';
  Check(SetInstallRoot(Ctx, InstallRoot), 'template update local repo sets install root');

  Cmd := TProjectTemplateUpdateCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check(Ret = EXIT_OK, 'template update local repo EXIT_OK');
    Check(Trim(StdErr.GetBuffer) = '', 'template update local repo keeps stderr empty');
    Check(StdOut.Contains('Failed to update resource repository'),
      'template update local repo reports cached-update warning');
    Check(StdOut.Contains('Templates updated: 1 added, 0 updated'),
      'template update local repo reports copied template count');

    TemplateMetaDest := InstallRoot + PathDelim + 'templates' + PathDelim +
      'console' + PathDelim + 'template.json';
    NestedDest := InstallRoot + PathDelim + 'templates' + PathDelim +
      'console' + PathDelim + 'src' + PathDelim + 'main.pas';
    Check(FileExists(TemplateMetaDest),
      'template update local repo copies template metadata');
    Check(FileExists(NestedDest),
      'template update local repo copies nested template files');
  finally
    Cmd.Free;
  end;
end;

begin
  WriteLn('=== Project Template Commands Unit Tests ===');
  WriteLn;

  GTempDir := CreateUniqueTempDir('fpdev_test_project_template');
  SetupLocalTemplateUpdateRepo;

  TestProjectRootRegistered;
  TestTemplateRootRegistered;
  TestTemplateAliasRegistered;
  TestTemplateListRegistered;
  TestTemplateListAliasRegistered;
  TestTemplateInstallRegistered;
  TestTemplateRemoveRegistered;
  TestTemplateRemoveAliasRegistered;
  TestTemplateUpdateRegistered;
  TestTemplateSubcommandCount;
  TestListCommandName;
  TestInstallCommandName;
  TestRemoveCommandName;
  TestUpdateCommandName;
  TestListFindSubNil;
  TestInstallFindSubNil;
  TestListUnexpectedArg;
  TestListUnknownOption;
  TestInstallUnexpectedArg;
  TestInstallUnknownOption;
  TestRemoveUnexpectedArg;
  TestRemoveUnknownOption;
  TestUpdateUnexpectedArg;
  TestUpdateUnknownOption;
  TestUpdateCopiesTemplatesFromLocalResourceRepo;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  RestoreEnv('FPDEV_DATA_ROOT', GSavedDataRoot);
  CleanupTempDir(GTemplateUpdateDataRoot);
  CleanupTempDir(GTempDir);

  if TestsFailed > 0 then
    Halt(1);
end.
