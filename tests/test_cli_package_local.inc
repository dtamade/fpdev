{ ===== clean ===== }

procedure TestCleanName;
var Cmd: TPackageCleanCommand;
begin
  Cmd := TPackageCleanCommand.Create;
  try Check('clean: name', Cmd.Name = 'clean'); finally Cmd.Free; end;
end;

procedure TestCleanHelp;
var Cmd: TPackageCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageCleanCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('clean --help EXIT_OK', Ret = EXIT_OK);
    Check('clean --help shows --dry-run', StdOut.Contains('dry-run'));
  finally Cmd.Free; end;
end;

procedure TestCleanMissingScope;
var Cmd: TPackageCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageCleanCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('clean no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestCleanUnexpectedArg;
var Cmd: TPackageCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageCleanCommand.Create;
  try
    Ret := Cmd.Execute(['cache', 'extra', '--dry-run'], Ctx);
    Check('clean unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestCleanUnknownOption;
var Cmd: TPackageCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageCleanCommand.Create;
  try
    Ret := Cmd.Execute(['cache', '--unknown-option'], Ctx);
    Check('clean unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== install-local ===== }

procedure TestInstallLocalName;
var Cmd: TPackageInstallLocalCommand;
begin
  Cmd := TPackageInstallLocalCommand.Create;
  try Check('install-local: name', Cmd.Name = 'install-local'); finally Cmd.Free; end;
end;

procedure TestInstallLocalHelp;
var Cmd: TPackageInstallLocalCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallLocalCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('install-local --help EXIT_OK', Ret = EXIT_OK);
    Check('install-local --help shows usage', StdOut.Contains('install-local'));
  finally Cmd.Free; end;
end;

procedure TestInstallLocalMissingPath;
var Cmd: TPackageInstallLocalCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallLocalCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('install-local no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestInstallLocalEmptyPath;
var Cmd: TPackageInstallLocalCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallLocalCommand.Create;
  try
    Ret := Cmd.Execute([''], Ctx);
    Check('install-local empty path EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestInstallLocalPathNotFound;
var
  Cmd: TPackageInstallLocalCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  MissingPath: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  MissingPath := GTempDir + PathDelim + 'missing_local_package_path';
  Cmd := TPackageInstallLocalCommand.Create;
  try
    Ret := Cmd.Execute([MissingPath], Ctx);
    Check('install-local missing path EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('install-local missing path writes stderr',
      Pos('not found', LowerCase(StdErr.GetBuffer)) > 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestInstallLocalValidPath;
var
  Cmd: TPackageInstallLocalCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  LocalPath: string;
  Settings: TFPDevSettings;
  InstalledMetaPath: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);

  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := GTempDir + PathDelim + 'install_root';
  Ctx.Config.GetSettingsManager.SetSettings(Settings);

  LocalPath := GTempDir + PathDelim + 'local_valid_pkg';
  ForceDirectories(LocalPath);

  Cmd := TPackageInstallLocalCommand.Create;
  try
    Ret := Cmd.Execute([LocalPath], Ctx);
    Check('install-local valid path EXIT_OK', Ret = EXIT_OK);

    InstalledMetaPath := Settings.InstallRoot + PathDelim + 'packages' + PathDelim +
      ExtractFileName(LocalPath) + PathDelim + 'package.json';
    Check('install-local valid path writes metadata', FileExists(InstalledMetaPath));
  finally
    Cmd.Free;
  end;
end;

procedure TestInstallLocalUsesMetadataName;
var
  Cmd: TPackageInstallLocalCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  LocalPath: string;
  Settings: TFPDevSettings;
  InstalledMetaPath: string;
  DirNameMetaPath: string;
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);

  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := GTempDir + PathDelim + 'install_root_meta_name';
  Ctx.Config.GetSettingsManager.SetSettings(Settings);

  LocalPath := GTempDir + PathDelim + 'local_dir_name_only';
  ForceDirectories(LocalPath);

  SL := TStringList.Create;
  try
    SL.Text := '{' + LineEnding +
      '  "name": "pkg_from_meta_name",' + LineEnding +
      '  "version": "1.0.0",' + LineEnding +
      '  "description": "from meta description"' + LineEnding +
      '}';
    SL.SaveToFile(LocalPath + PathDelim + 'package.json');
  finally
    SL.Free;
  end;

  Cmd := TPackageInstallLocalCommand.Create;
  try
    Ret := Cmd.Execute([LocalPath], Ctx);
    Check('install-local metadata name EXIT_OK', Ret = EXIT_OK);

    InstalledMetaPath := Settings.InstallRoot + PathDelim + 'packages' + PathDelim +
      'pkg_from_meta_name' + PathDelim + 'package.json';
    Check('install-local uses metadata name for install path', FileExists(InstalledMetaPath));

    SL := TStringList.Create;
    try
      SL.LoadFromFile(InstalledMetaPath);
      J := GetJSON(SL.Text);
      try
        if J.JSONType = jtObject then
        begin
          O := TJSONObject(J);
          Check('install-local preserves metadata version',
            O.Get('version', '') = '1.0.0');
          Check('install-local preserves metadata description',
            O.Get('description', '') = 'from meta description');
        end
        else
          Check('install-local metadata file must be JSON object', False);
      finally
        J.Free;
      end;
    finally
      SL.Free;
    end;

    DirNameMetaPath := Settings.InstallRoot + PathDelim + 'packages' + PathDelim +
      ExtractFileName(LocalPath) + PathDelim + 'package.json';
    Check('install-local does not use directory name when metadata name exists',
      not FileExists(DirNameMetaPath));
  finally
    Cmd.Free;
  end;
end;

procedure TestInstallLocalUnexpectedArg;
var Cmd: TPackageInstallLocalCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallLocalCommand.Create;
  try
    Ret := Cmd.Execute([GTempDir, 'extra'], Ctx);
    Check('install-local unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestInstallLocalUnknownOption;
var Cmd: TPackageInstallLocalCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallLocalCommand.Create;
  try
    Ret := Cmd.Execute(['/tmp', '--unknown-option'], Ctx);
    Check('install-local unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== help ===== }

procedure TestHelpName;
var Cmd: TPackageHelpCommand;
begin
  Cmd := TPackageHelpCommand.Create;
  try Check('help: name', Cmd.Name = 'help'); finally Cmd.Free; end;
end;

procedure TestHelpNoArgs;
var Cmd: TPackageHelpCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageHelpCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('help no args EXIT_OK', Ret = EXIT_OK);
    Check('help shows available commands', StdOut.Contains('install'));
    Check('help shows deps description', StdOut.Contains('dependency tree'));
    Check('help shows why description', StdOut.Contains('dependency path'));
  finally Cmd.Free; end;
end;

procedure TestHelpUnexpectedArg;
var Cmd: TPackageHelpCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageHelpCommand.Create;
  try
    Ret := Cmd.Execute(['install', 'extra'], Ctx);
    Check('help unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== deps ===== }

procedure TestDepsName;
var Cmd: TPackageDepsCommand;
begin
  Cmd := TPackageDepsCommand.Create;
  try Check('deps: name', Cmd.Name = 'deps'); finally Cmd.Free; end;
end;

procedure TestDepsAlias;
var Cmd: TPackageDepsCommand; A: TStringArray;
begin
  Cmd := TPackageDepsCommand.Create;
  try
    A := Cmd.Aliases;
    Check('deps: has no alias', A = nil);
  finally Cmd.Free; end;
end;

procedure TestDepsHelp;
var Cmd: TPackageDepsCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageDepsCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('deps --help EXIT_OK', Ret = EXIT_OK);
    Check('deps --help shows --tree', StdOut.Contains('tree'));
    Check('deps --help shows --flat', StdOut.Contains('flat'));
  finally Cmd.Free; end;
end;

procedure TestDepsNoArgs;
var Cmd: TPackageDepsCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageDepsCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('deps no args EXIT_OK', Ret = EXIT_OK);
    Check('deps no args shows header', StdOut.Contains('Dependencies for:'));
    Check('deps no args shows current project', StdOut.Contains('current project'));
    Check('deps no args shows summary', StdOut.Contains('Total:'));
  finally Cmd.Free; end;
end;

procedure TestDepsWithPackageName;
var Cmd: TPackageDepsCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageDepsCommand.Create;
  try
    Ret := Cmd.Execute(['mylib'], Ctx);
    Check('deps with package EXIT_OK', Ret = EXIT_OK);
    Check('deps with package shows header', StdOut.Contains('Dependencies for: mylib'));
    Check('deps with package shows package node', StdOut.Contains('mylib'));
  finally Cmd.Free; end;
end;

procedure TestDepsUnexpectedArg;
var Cmd: TPackageDepsCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageDepsCommand.Create;
  try
    Ret := Cmd.Execute(['sample_pkg', 'extra_arg'], Ctx);
    Check('deps unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestDepsUnknownOption;
var Cmd: TPackageDepsCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageDepsCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown-option'], Ctx);
    Check('deps unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestDepsInvalidDepthOption;
var Cmd: TPackageDepsCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageDepsCommand.Create;
  try
    Ret := Cmd.Execute(['--depth=abc'], Ctx);
    Check('deps invalid depth EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== why ===== }

procedure TestWhyName;
var Cmd: TPackageWhyCommand;
begin
  Cmd := TPackageWhyCommand.Create;
  try Check('why: name', Cmd.Name = 'why'); finally Cmd.Free; end;
end;

procedure TestWhyHelp;
var Cmd: TPackageWhyCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageWhyCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('why --help EXIT_OK', Ret = EXIT_OK);
    Check('why --help shows usage', StdOut.Contains('why'));
  finally Cmd.Free; end;
end;

procedure TestWhyMissingPackage;
var Cmd: TPackageWhyCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageWhyCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('why no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestWhyPackageOutput;
var Cmd: TPackageWhyCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageWhyCommand.Create;
  try
    Ret := Cmd.Execute(['zlib'], Ctx);
    Check('why package EXIT_OK', Ret = EXIT_OK);
    Check('why package shows header', StdOut.Contains('Why is "zlib" installed?'));
    Check('why package shows tree root', StdOut.Contains('+-- fpdev-core >= 1.0.0'));
    Check('why package shows tree leaf', StdOut.Contains('+-- zlib'));
    Check('why package shows required by', StdOut.Contains('Required by: fpdev-core'));
    Check('why package shows constraint', StdOut.Contains('Constraint: >= 1.0.0'));
  finally Cmd.Free; end;
end;

procedure TestWhyUnexpectedArg;
var Cmd: TPackageWhyCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageWhyCommand.Create;
  try
    Ret := Cmd.Execute(['zlib', 'extra_arg'], Ctx);
    Check('why unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestWhyUnknownOption;
var Cmd: TPackageWhyCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageWhyCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown-option'], Ctx);
    Check('why unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestPackageCoreRuntimeI18nKeys;
begin
  Check('i18n dep resolving message',
    _(MSG_PKG_DEP_RESOLVING) = 'Resolving dependencies...');
  Check('i18n dep adding message',
    _Fmt(MSG_PKG_DEP_ADDING, ['zlib']) = 'Adding dependency: zlib');
  Check('i18n dep install one message',
    _Fmt(MSG_PKG_DEP_INSTALLING_ONE, ['zlib']) = 'Installing dependency: zlib');
  Check('i18n dep not found message',
    _Fmt(MSG_PKG_DEP_NOT_FOUND, ['zlib']) = 'Dependency package not found: zlib');
  Check('i18n dep install failed message',
    _Fmt(MSG_PKG_DEP_INSTALL_FAILED, ['zlib']) = 'Failed to install dependency: zlib');
  Check('i18n archive sha256 message',
    _Fmt(MSG_PKG_ARCHIVE_SHA256, ['abc']) = 'SHA256: abc');
  Check('i18n package test resolved header',
    _Fmt(CMD_PKG_TEST_DEP_RESOLVED_HEADER, [2]) = '[INFO] Resolved 2 dependencies:');
  Check('i18n package test resolved item',
    _Fmt(CMD_PKG_TEST_DEP_RESOLVED_ITEM, [1, 'zlib']) = '[INFO]   1. zlib');
  Check('i18n package test running script',
    _Fmt(CMD_PKG_TEST_SCRIPT_RUNNING, ['echo test']) = '[INFO] Running test script: echo test');
  Check('i18n package test missing script',
    _(CMD_PKG_TEST_SCRIPT_MISSING) = 'No test script found in package.json');
  Check('i18n search info package',
    _Fmt(CMD_PKG_SEARCH_INFO_PACKAGE, ['zlib']) = 'Package: zlib');
  Check('i18n search info versions',
    _Fmt(CMD_PKG_SEARCH_INFO_VERSIONS, ['1.0.0']) = 'Versions: 1.0.0');
  Check('i18n search init failed',
    _Fmt(CMD_PKG_SEARCH_INIT_FAILED, ['boom']) = 'Failed to initialize registry: boom');
  Check('i18n publish archive not found',
    _Fmt(CMD_PKG_PUBLISH_ARCHIVE_NOT_FOUND, ['a.tar.gz']) = 'Archive file not found: a.tar.gz');
  Check('i18n publish version exists',
    _Fmt(CMD_PKG_PUBLISH_VERSION_EXISTS, ['demo', '1.0.0']) = 'Package version already exists: demo 1.0.0');
  Check('i18n publish source path not found',
    _Fmt(CMD_PKG_PUBLISH_SOURCE_PATH_NOT_FOUND, ['/tmp/demo']) = 'Package source path not found: /tmp/demo');
  Check('i18n publish source no files',
    _Fmt(CMD_PKG_PUBLISH_SOURCE_NO_FILES, ['/tmp/demo']) = 'No source files found to archive in: /tmp/demo');
  Check('i18n validate pkgjson missing',
    _(CMD_PKG_VALIDATE_PKGJSON_NOT_FOUND) = 'package.json not found');
  Check('i18n validate required field missing',
    _Fmt(CMD_PKG_VALIDATE_REQUIRED_FIELD_MISSING, ['name']) = 'Missing required field: name');
  Check('i18n validate error prefix',
    _(CMD_PKG_VALIDATE_PREFIX_ERROR) = '[ERROR] ');
end;
