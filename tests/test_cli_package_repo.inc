{ ===== repo list ===== }

procedure TestRepoListName;
var Cmd: TPackageRepoListCommand;
begin
  Cmd := TPackageRepoListCommand.Create;
  try Check('repo list: name', Cmd.Name = 'list'); finally Cmd.Free; end;
end;

procedure TestRepoListAlias;
var Cmd: TPackageRepoListCommand; A: TStringArray;
begin
  Cmd := TPackageRepoListCommand.Create;
  try
    A := Cmd.Aliases;
    Check('repo list: has no alias', A = nil);
  finally Cmd.Free; end;
end;

procedure TestRepoListHelp;
var Cmd: TPackageRepoListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoListCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo list --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoListNoArgs;
var Cmd: TPackageRepoListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoListCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo list no args EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoListUnexpectedArg;
var Cmd: TPackageRepoListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoListCommand.Create;
  try
    Ret := Cmd.Execute(['unexpected_repo_name'], Ctx);
    Check('repo list unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoListUnknownOption;
var Cmd: TPackageRepoListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoListCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown-option'], Ctx);
    Check('repo list unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== repo add ===== }

procedure TestRepoAddName;
var Cmd: TPackageRepoAddCommand;
begin
  Cmd := TPackageRepoAddCommand.Create;
  try Check('repo add: name', Cmd.Name = 'add'); finally Cmd.Free; end;
end;

procedure TestRepoAddHelp;
var Cmd: TPackageRepoAddCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoAddCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo add --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoAddMissingArgs;
var Cmd: TPackageRepoAddCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoAddCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo add no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoAddEmptyArgs;
var
  Cmd: TPackageRepoAddCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoAddCommand.Create;
  try
    Ret := Cmd.Execute(['', 'https://example.com/packages/index.json'], Ctx);
    Check('repo add empty name EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);

    Ret := Cmd.Execute(['demo', ''], Ctx);
    Check('repo add empty url EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

procedure TestRepoAddDuplicateRepo;
var
  Cmd: TPackageRepoAddCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoAddCommand.Create;
  try
    Ret := Cmd.Execute(['dup_repo', 'https://example.com/packages-a/index.json'], Ctx);
    Check('repo add first add EXIT_OK', Ret = EXIT_OK);

    Ret := Cmd.Execute(['dup_repo', 'https://example.com/packages-b/index.json'], Ctx);
    Check('repo add duplicate EXIT_ALREADY_EXISTS', Ret = EXIT_ALREADY_EXISTS);
    Check('repo add duplicate writes stderr',
      Pos('exist', LowerCase(StdErr.GetBuffer)) > 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestRepoAddUnexpectedArg;
var Cmd: TPackageRepoAddCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoAddCommand.Create;
  try
    Ret := Cmd.Execute(['repo_name', 'https://example.com/packages/index.json', 'extra_arg'], Ctx);
    Check('repo add unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoAddUnknownOption;
var Cmd: TPackageRepoAddCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoAddCommand.Create;
  try
    Ret := Cmd.Execute(['repo_name', 'https://example.com/index.json', '--unknown-option'], Ctx);
    Check('repo add unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== repo remove ===== }

procedure TestRepoRemoveName;
var Cmd: TPackageRepoRemoveCommand;
begin
  Cmd := TPackageRepoRemoveCommand.Create;
  try Check('repo remove: name', Cmd.Name = 'remove'); finally Cmd.Free; end;
end;

procedure TestRepoRemoveAliases;
var Cmd: TPackageRepoRemoveCommand; A: TStringArray;
begin
  Cmd := TPackageRepoRemoveCommand.Create;
  try
    A := Cmd.Aliases;
    Check('repo remove: has no alias', A = nil);
  finally Cmd.Free; end;
end;

procedure TestRepoRemoveHelp;
var Cmd: TPackageRepoRemoveCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoRemoveCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo remove --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoRemoveMissingName;
var Cmd: TPackageRepoRemoveCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoRemoveCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo remove no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoRemoveEmptyName;
var
  Cmd: TPackageRepoRemoveCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoRemoveCommand.Create;
  try
    Ret := Cmd.Execute([''], Ctx);
    Check('repo remove empty name EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

procedure TestRepoRemoveUnknownRepo;
var
  Cmd: TPackageRepoRemoveCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoRemoveCommand.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_repo_for_remove'], Ctx);
    Check('repo remove unknown repo EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('repo remove unknown repo writes stderr',
      Pos('not found', LowerCase(StdErr.GetBuffer)) > 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestRepoRemoveUnexpectedArg;
var Cmd: TPackageRepoRemoveCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoRemoveCommand.Create;
  try
    Ret := Cmd.Execute(['repo_name', 'extra_arg'], Ctx);
    Check('repo remove unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoRemoveUnknownOption;
var Cmd: TPackageRepoRemoveCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoRemoveCommand.Create;
  try
    Ret := Cmd.Execute(['repo_name', '--unknown-option'], Ctx);
    Check('repo remove unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== repo update ===== }

procedure TestRepoUpdateName;
var Cmd: TPackageRepoUpdateCommand;
begin
  Cmd := TPackageRepoUpdateCommand.Create;
  try Check('repo update: name', Cmd.Name = 'update'); finally Cmd.Free; end;
end;

procedure TestRepoUpdateHelp;
var Cmd: TPackageRepoUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo update --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoUpdateNoArgs;
var Cmd: TPackageRepoUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoUpdateCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo update no args EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoUpdateUnexpectedArg;
var Cmd: TPackageRepoUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['unexpected_repo_name'], Ctx);
    Check('repo update unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoUpdateUnknownOption;
var Cmd: TPackageRepoUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown-option'], Ctx);
    Check('repo update unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;
