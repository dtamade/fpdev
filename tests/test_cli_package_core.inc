{ ===== install ===== }

procedure TestInstallName;
var Cmd: TPackageInstallCommand;
begin
  Cmd := TPackageInstallCommand.Create;
  try Check('install: name', Cmd.Name = 'install'); finally Cmd.Free; end;
end;

procedure TestInstallHelp;
var Cmd: TPackageInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('install --help EXIT_OK', Ret = EXIT_OK);
    Check('install --help shows usage', StdOut.Contains('install'));
    Check('install --help shows --dry-run', StdOut.Contains('dry-run'));
  finally Cmd.Free; end;
end;

procedure TestInstallMissingPackage;
var Cmd: TPackageInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('install no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestInstallUnknownPackage;
var Cmd: TPackageInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallCommand.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_install'], Ctx);
    Check('install unknown package EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('install unknown package writes stderr',
      Pos('not found', LowerCase(StdErr.GetBuffer)) > 0);
  finally Cmd.Free; end;
end;

procedure TestInstallUnexpectedArg;
var Cmd: TPackageInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallCommand.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_install', '1.0.0', 'extra'], Ctx);
    Check('install unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestInstallUnknownOption;
var Cmd: TPackageInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallCommand.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_install', '--unknown-option'], Ctx);
    Check('install unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestInstallDryRunOutput;
var Cmd: TPackageInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallCommand.Create;
  try
    Ret := Cmd.Execute(['demo_pkg', '--dry-run', '--no-deps'], Ctx);
    Check('install dry-run EXIT_OK', Ret = EXIT_OK);
    Check('install dry-run shows header', StdOut.Contains('Dry-run mode'));
    Check('install dry-run shows package', StdOut.Contains('Package: demo_pkg'));
    Check('install dry-run shows deps skipped', StdOut.Contains('Dependencies: skipped'));
  finally Cmd.Free; end;
end;

{ ===== uninstall ===== }

procedure TestUninstallName;
var Cmd: TPackageUninstallCommand;
begin
  Cmd := TPackageUninstallCommand.Create;
  try Check('uninstall: name', Cmd.Name = 'uninstall'); finally Cmd.Free; end;
end;

procedure TestUninstallHelp;
var Cmd: TPackageUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUninstallCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('uninstall --help EXIT_OK', Ret = EXIT_OK);
    Check('uninstall --help shows usage', StdOut.Contains('uninstall'));
  finally Cmd.Free; end;
end;

procedure TestUninstallMissingPackage;
var Cmd: TPackageUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUninstallCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('uninstall no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestUninstallEmptyPackage;
var Cmd: TPackageUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUninstallCommand.Create;
  try
    Ret := Cmd.Execute([''], Ctx);
    Check('uninstall empty package EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestUninstallUnknownPackage;
var Cmd: TPackageUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUninstallCommand.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_uninstall'], Ctx);
    Check('uninstall unknown package EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('uninstall unknown package writes stderr',
      Pos('not installed', LowerCase(StdErr.GetBuffer)) > 0);
  finally Cmd.Free; end;
end;

procedure TestUninstallUnexpectedArg;
var Cmd: TPackageUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUninstallCommand.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_uninstall', 'extra'], Ctx);
    Check('uninstall unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestUninstallUnknownOption;
var Cmd: TPackageUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUninstallCommand.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_uninstall', '--unknown-option'], Ctx);
    Check('uninstall unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== update ===== }

procedure TestUpdateName;
var Cmd: TPackageUpdateCommand;
begin
  Cmd := TPackageUpdateCommand.Create;
  try Check('update: name', Cmd.Name = 'update'); finally Cmd.Free; end;
end;

procedure TestUpdateHelp;
var Cmd: TPackageUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('update --help EXIT_OK', Ret = EXIT_OK);
    Check('update --help shows usage', StdOut.Contains('update'));
  finally Cmd.Free; end;
end;

procedure TestUpdateMissingPackage;
var Cmd: TPackageUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUpdateCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('update no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestUpdateUnknownPackage;
var Cmd: TPackageUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_update'], Ctx);
    Check('update unknown package EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('update unknown package writes stderr',
      Pos('not installed', LowerCase(StdErr.GetBuffer)) > 0);
  finally Cmd.Free; end;
end;

procedure TestUpdateUnexpectedArg;
var Cmd: TPackageUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_update', 'extra'], Ctx);
    Check('update unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestUpdateUnknownOption;
var Cmd: TPackageUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_update', '--unknown-option'], Ctx);
    Check('update unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== list ===== }

procedure TestListName;
var Cmd: TPackageListCommand;
begin
  Cmd := TPackageListCommand.Create;
  try Check('list: name', Cmd.Name = 'list'); finally Cmd.Free; end;
end;

procedure TestListAlias;
var Cmd: TPackageListCommand; A: TStringArray;
begin
  Cmd := TPackageListCommand.Create;
  try
    A := Cmd.Aliases;
    Check('list: has no alias', A = nil);
  finally Cmd.Free; end;
end;

procedure TestListHelp;
var Cmd: TPackageListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageListCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('list --help EXIT_OK', Ret = EXIT_OK);
    Check('list --help shows --all', StdOut.Contains('all'));
    Check('list --help shows --json', StdOut.Contains('json'));
  finally Cmd.Free; end;
end;

procedure TestListNoArgs;
var Cmd: TPackageListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageListCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('list no args EXIT_OK', Ret = EXIT_OK);
    Check('list no args shows installed header', StdOut.Contains('Installed packages:'));
  finally Cmd.Free; end;
end;

procedure TestListAllOutput;
var Cmd: TPackageListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageListCommand.Create;
  try
    Ret := Cmd.Execute(['--all'], Ctx);
    Check('list --all EXIT_OK', Ret = EXIT_OK);
    Check('list --all shows available header', StdOut.Contains('Available packages:'));
  finally Cmd.Free; end;
end;

procedure TestListJsonOutput;
var Cmd: TPackageListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageListCommand.Create;
  try
    Ret := Cmd.Execute(['--json'], Ctx);
    Check('list --json EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestListUnexpectedArg;
var Cmd: TPackageListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageListCommand.Create;
  try
    Ret := Cmd.Execute(['unexpected_package'], Ctx);
    Check('list unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestListUnknownOption;
var Cmd: TPackageListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageListCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown-option'], Ctx);
    Check('list unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== search ===== }

procedure TestSearchName;
var Cmd: TPackageSearchCmd;
begin
  Cmd := TPackageSearchCmd.Create;
  try Check('search: name', Cmd.Name = 'search'); finally Cmd.Free; end;
end;

procedure TestSearchHelp;
var Cmd: TPackageSearchCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageSearchCmd.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('search --help EXIT_OK', Ret = EXIT_OK);
    Check('search --help shows usage', StdOut.Contains('search'));
  finally Cmd.Free; end;
end;

procedure TestSearchMissingQuery;
var Cmd: TPackageSearchCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageSearchCmd.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('search no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestSearchBlankQuery;
var Cmd: TPackageSearchCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageSearchCmd.Create;
  try
    Ret := Cmd.Execute(['   '], Ctx);
    Check('search blank query EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestSearchUnknownOption;
var Cmd: TPackageSearchCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageSearchCmd.Create;
  try
    Ret := Cmd.Execute(['json', '--unknown-option'], Ctx);
    Check('search unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestSearchUnexpectedArg;
var Cmd: TPackageSearchCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageSearchCmd.Create;
  try
    Ret := Cmd.Execute(['json', 'extra'], Ctx);
    Check('search unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('search unexpected arg shows usage', StdErr.Contains('Usage: fpdev package search <query> [--json]'));
    Check('search unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally Cmd.Free; end;
end;

procedure TestSearchNoResultsOutput;
var Cmd: TPackageSearchCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageSearchCmd.Create;
  try
    Ret := Cmd.Execute(['__no_match_query__'], Ctx);
    Check('search no results EXIT_OK', Ret = EXIT_OK);
    Check('search no results shows message', StdOut.Contains('No packages found'));
  finally Cmd.Free; end;
end;

procedure TestSearchJsonUsesFPDEVDataRootRegistry;
var
  Cmd: TPackageSearchCmd;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  ProbeRoot: string;
  RegistryRoot: string;
  IndexPath: string;
  SavedDataRoot: string;
  PackageName: string;
  JSONData: TJSONData;
  JSONObject: TJSONObject;
  Results: TJSONArray;
begin
  ProbeRoot := CreateUniqueTempDir('fpdev_pkg_search_json_probe');
  RegistryRoot := IncludeTrailingPathDelimiter(ProbeRoot) + 'registry';
  IndexPath := RegistryRoot + PathDelim + 'index.json';
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  PackageName := 'pkg_search_json_fpdev_data_root_probe_zzx91';
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageSearchCmd.Create;
  JSONData := nil;
  try
    SetPortableMode(False);
    set_env('FPDEV_DATA_ROOT', ProbeRoot);
    ForceDirectories(RegistryRoot);

    SafeWriteAllText(
      IndexPath,
      '{' + LineEnding +
      '  "version": "1.0",' + LineEnding +
      '  "packages": {' + LineEnding +
      '    "' + PackageName + '": {' + LineEnding +
      '      "name": "' + PackageName + '",' + LineEnding +
      '      "description": "FPDEV_DATA_ROOT registry probe",' + LineEnding +
      '      "author": "fpdev-test",' + LineEnding +
      '      "versions": ["1.0.0"],' + LineEnding +
      '      "latest": "1.0.0"' + LineEnding +
      '    }' + LineEnding +
      '  }' + LineEnding +
      '}'
    );

    Ret := Cmd.Execute([PackageName, '--json'], Ctx);
    Check('search --json with FPDEV_DATA_ROOT registry EXIT_OK', Ret = EXIT_OK);

    try
      JSONData := GetJSON(StdOut.GetBuffer);
      JSONObject := TJSONObject(JSONData);
      Results := JSONObject.Arrays['results'];
      Check('search --json uses FPDEV_DATA_ROOT registry query echo',
        JSONObject.Get('query', '') = PackageName);
      Check('search --json uses FPDEV_DATA_ROOT registry count',
        JSONObject.Get('count', -1) = 1);
      Check('search --json uses FPDEV_DATA_ROOT registry result item',
        (Results <> nil) and (Results.Count = 1) and (Results.Strings[0] = PackageName));
    except
      on E: Exception do
      begin
        if JSONData <> nil then
          FreeAndNil(JSONData);
        Check('search --json returns valid JSON for FPDEV_DATA_ROOT registry probe', False);
      end;
    end;
  finally
    if JSONData <> nil then
      JSONData.Free;
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    CleanupTempDir(ProbeRoot);
    Cmd.Free;
  end;
end;

{ ===== info ===== }

procedure TestInfoName;
var Cmd: TPackageInfoCommand;
begin
  Cmd := TPackageInfoCommand.Create;
  try Check('info: name', Cmd.Name = 'info'); finally Cmd.Free; end;
end;

procedure TestInfoHelp;
var Cmd: TPackageInfoCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInfoCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('info --help EXIT_OK', Ret = EXIT_OK);
    Check('info --help shows usage', StdOut.Contains('info'));
  finally Cmd.Free; end;
end;

procedure TestInfoMissingPackage;
var Cmd: TPackageInfoCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInfoCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('info no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestInfoUnknownPackage;
var Cmd: TPackageInfoCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInfoCommand.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_info'], Ctx);
    Check('info unknown package EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('info unknown package writes stderr',
      Pos('not found', LowerCase(StdErr.GetBuffer)) > 0);
  finally Cmd.Free; end;
end;

procedure TestInfoUnexpectedArg;
var Cmd: TPackageInfoCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInfoCommand.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_info', 'extra'], Ctx);
    Check('info unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestInfoUnknownOption;
var Cmd: TPackageInfoCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInfoCommand.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_info', '--unknown-option'], Ctx);
    Check('info unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;
