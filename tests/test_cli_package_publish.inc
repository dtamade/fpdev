{ ===== publish ===== }

procedure TestPublishName;
var Cmd: TPackagePublishCmd;
begin
  Cmd := TPackagePublishCmd.Create;
  try Check('publish: name', Cmd.Name = 'publish'); finally Cmd.Free; end;
end;

procedure TestPublishHelp;
var Cmd: TPackagePublishCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackagePublishCmd.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('publish --help EXIT_OK', Ret = EXIT_OK);
    Check('publish --help shows usage', StdOut.Contains('publish'));
  finally Cmd.Free; end;
end;

procedure TestPublishMissingPackage;
var Cmd: TPackagePublishCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackagePublishCmd.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('publish no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestPublishEmptyPackage;
var Cmd: TPackagePublishCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackagePublishCmd.Create;
  try
    Ret := Cmd.Execute([''], Ctx);
    Check('publish empty package EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestPublishUnknownPackage;
var Cmd: TPackagePublishCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackagePublishCmd.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_publish'], Ctx);
    Check('publish unknown package EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('publish unknown package writes stderr',
      Pos('not found', LowerCase(StdErr.GetBuffer)) > 0);
  finally Cmd.Free; end;
end;

procedure TestPublishMissingMetadata;
var
  Cmd: TPackagePublishCmd;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  BrokenPackageDir: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  BrokenPackageDir := GTempDir + PathDelim + 'packages' + PathDelim + 'broken_publish_pkg';
  ForceDirectories(BrokenPackageDir);

  Cmd := TPackagePublishCmd.Create;
  try
    Ret := Cmd.Execute(['broken_publish_pkg'], Ctx);
    Check('publish missing metadata EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('publish missing metadata writes stderr',
      Pos('metadata', LowerCase(StdErr.GetBuffer)) > 0);
    Check('publish missing metadata gives install-local hint',
      Pos('install-local', LowerCase(StdErr.GetBuffer)) > 0);
    Check('publish missing metadata should not suggest package create',
      Pos('package create', LowerCase(StdErr.GetBuffer)) = 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestPublishAfterInstallLocalUsesMetadataVersion;
var
  InstallCmd: TPackageInstallLocalCommand;
  PublishCmd: TPackagePublishCmd;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  LocalPath: string;
  Settings: TFPDevSettings;
  SL: TStringList;
  ArchivePath: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := GTempDir + PathDelim + 'install_root_publish_e2e';
  Ctx.Config.GetSettingsManager.SetSettings(Settings);

  LocalPath := GTempDir + PathDelim + 'local_publish_e2e';
  ForceDirectories(LocalPath);

  SL := TStringList.Create;
  try
    SL.Text := 'unit e2e_demo;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    SL.SaveToFile(LocalPath + PathDelim + 'e2e_demo.pas');

    SL.Text := '{' + LineEnding +
      '  "name": "pkg_publish_e2e",' + LineEnding +
      '  "version": "2.3.4",' + LineEnding +
      '  "description": "e2e publish chain"' + LineEnding +
      '}';
    SL.SaveToFile(LocalPath + PathDelim + 'package.json');
  finally
    SL.Free;
  end;

  InstallCmd := TPackageInstallLocalCommand.Create;
  try
    Ret := InstallCmd.Execute([LocalPath], Ctx);
    Check('publish chain install-local EXIT_OK', Ret = EXIT_OK);
  finally
    InstallCmd.Free;
  end;

  PublishCmd := TPackagePublishCmd.Create;
  try
    Ret := PublishCmd.Execute(['pkg_publish_e2e'], Ctx);
    Check('publish chain publish EXIT_OK', Ret = EXIT_OK);
    Check('publish chain uses metadata version in archive name',
      Pos('pkg_publish_e2e-2.3.4.tar.gz', StdOut.GetBuffer) > 0);

    ArchivePath := Settings.InstallRoot + PathDelim + 'publish' + PathDelim +
      'pkg_publish_e2e-2.3.4.tar.gz';
    Check('publish chain archive exists', FileExists(ArchivePath));
  finally
    PublishCmd.Free;
  end;
end;

procedure TestPublishWorksAfterOriginalSourceDeleted;
var
  InstallCmd: TPackageInstallLocalCommand;
  PublishCmd: TPackagePublishCmd;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  LocalPath: string;
  Settings: TFPDevSettings;
  SL: TStringList;
  ArchivePath: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := GTempDir + PathDelim + 'install_root_publish_after_delete';
  Ctx.Config.GetSettingsManager.SetSettings(Settings);

  LocalPath := GTempDir + PathDelim + 'local_publish_after_delete';
  ForceDirectories(LocalPath);

  SL := TStringList.Create;
  try
    SL.Text := 'unit after_delete_demo;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    SL.SaveToFile(LocalPath + PathDelim + 'after_delete_demo.pas');

    SL.Text := '{' + LineEnding +
      '  "name": "pkg_publish_after_delete",' + LineEnding +
      '  "version": "1.0.7"' + LineEnding +
      '}';
    SL.SaveToFile(LocalPath + PathDelim + 'package.json');
  finally
    SL.Free;
  end;

  InstallCmd := TPackageInstallLocalCommand.Create;
  try
    Ret := InstallCmd.Execute([LocalPath], Ctx);
    Check('publish after delete install-local EXIT_OK', Ret = EXIT_OK);
  finally
    InstallCmd.Free;
  end;

  Check('publish after delete remove original source',
    DeleteDirRecursive(LocalPath));

  PublishCmd := TPackagePublishCmd.Create;
  try
    Ret := PublishCmd.Execute(['pkg_publish_after_delete'], Ctx);
    Check('publish after delete source EXIT_OK', Ret = EXIT_OK);
    ArchivePath := Settings.InstallRoot + PathDelim + 'publish' + PathDelim +
      'pkg_publish_after_delete-1.0.7.tar.gz';
    Check('publish after delete source archive exists', FileExists(ArchivePath));
  finally
    PublishCmd.Free;
  end;
end;

procedure TestPublishUsesFPDEVDataRootArchiveRoot;
var
  InstallCmd: TPackageInstallLocalCommand;
  PublishCmd: TPackagePublishCmd;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  LocalPath: string;
  ProbeRoot: string;
  SavedDataRoot: string;
  Settings: TFPDevSettings;
  SL: TStringList;
  ExpectedArchivePath: string;
begin
  ProbeRoot := CreateUniqueTempDir('fpdev_pkg_publish_data_root_probe');
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  try
    SetPortableMode(False);
    set_env('FPDEV_DATA_ROOT', ProbeRoot);

    Settings := Ctx.Config.GetSettingsManager.GetSettings;
    Settings.InstallRoot := '';
    Ctx.Config.GetSettingsManager.SetSettings(Settings);

    LocalPath := GTempDir + PathDelim + 'local_publish_data_root_probe';
    ForceDirectories(LocalPath);

    SL := TStringList.Create;
    try
      SL.Text := 'unit publish_data_root_demo;' + LineEnding +
        'interface' + LineEnding +
        'implementation' + LineEnding +
        'end.';
      SL.SaveToFile(LocalPath + PathDelim + 'publish_data_root_demo.pas');

      SL.Text := '{' + LineEnding +
        '  "name": "pkg_publish_data_root_probe",' + LineEnding +
        '  "version": "1.0.8"' + LineEnding +
        '}';
      SL.SaveToFile(LocalPath + PathDelim + 'package.json');
    finally
      SL.Free;
    end;

    InstallCmd := TPackageInstallLocalCommand.Create;
    try
      Ret := InstallCmd.Execute([LocalPath], Ctx);
      Check('publish data-root install-local EXIT_OK', Ret = EXIT_OK);
    finally
      InstallCmd.Free;
    end;

    StdOut.Clear;
    StdErr.Clear;

    PublishCmd := TPackagePublishCmd.Create;
    try
      Ret := PublishCmd.Execute(['pkg_publish_data_root_probe'], Ctx);
      Check('publish data-root archive EXIT_OK', Ret = EXIT_OK);

      ExpectedArchivePath := IncludeTrailingPathDelimiter(ProbeRoot) + 'publish' +
        PathDelim + 'pkg_publish_data_root_probe-1.0.8.tar.gz';
      Check('publish data-root archive exists under FPDEV_DATA_ROOT',
        FileExists(ExpectedArchivePath));
      Check('publish data-root archive path reported to stdout',
        Pos(ExpectedArchivePath, StdOut.GetBuffer) > 0);

      Settings := Ctx.Config.GetSettingsManager.GetSettings;
      Check('publish data-root writes resolved install root back to config',
        ExpandFileName(Settings.InstallRoot) = ExpandFileName(ProbeRoot));
    finally
      PublishCmd.Free;
    end;
  finally
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    CleanupTempDir(ProbeRoot);
  end;
end;

procedure TestPublishRejectsInvalidMetadataSourcePath;
var
  InstallCmd: TPackageInstallLocalCommand;
  PublishCmd: TPackagePublishCmd;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  LocalPath: string;
  BadSourcePath: string;
  InstallMetaPath: string;
  Settings: TFPDevSettings;
  SL: TStringList;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := GTempDir + PathDelim + 'install_root_publish_bad_source';
  Ctx.Config.GetSettingsManager.SetSettings(Settings);

  LocalPath := GTempDir + PathDelim + 'local_publish_bad_source';
  ForceDirectories(LocalPath);
  BadSourcePath := GTempDir + PathDelim + 'missing_publish_source_dir';

  SL := TStringList.Create;
  try
    SL.Text := 'unit bad_source_demo;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    SL.SaveToFile(LocalPath + PathDelim + 'bad_source_demo.pas');

    SL.Text := '{' + LineEnding +
      '  "name": "pkg_publish_bad_source",' + LineEnding +
      '  "version": "1.0.1"' + LineEnding +
      '}';
    SL.SaveToFile(LocalPath + PathDelim + 'package.json');
  finally
    SL.Free;
  end;

  InstallCmd := TPackageInstallLocalCommand.Create;
  try
    Ret := InstallCmd.Execute([LocalPath], Ctx);
    Check('publish invalid source install-local EXIT_OK', Ret = EXIT_OK);
  finally
    InstallCmd.Free;
  end;

  InstallMetaPath := Settings.InstallRoot + PathDelim + 'packages' + PathDelim +
    'pkg_publish_bad_source' + PathDelim + 'package.json';
  SL := TStringList.Create;
  try
    SL.Text := '{' + LineEnding +
      '  "name": "pkg_publish_bad_source",' + LineEnding +
      '  "version": "1.0.1",' + LineEnding +
      '  "source_path": "' + BadSourcePath + '"' + LineEnding +
      '}';
    SL.SaveToFile(InstallMetaPath);
  finally
    SL.Free;
  end;

  PublishCmd := TPackagePublishCmd.Create;
  try
    Ret := PublishCmd.Execute(['pkg_publish_bad_source'], Ctx);
    Check('publish invalid source path EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('publish invalid source path writes clear error',
      Pos(LowerCase(_Fmt(CMD_PKG_PUBLISH_SOURCE_PATH_NOT_FOUND, [BadSourcePath])),
      LowerCase(StdErr.GetBuffer)) > 0);
  finally
    PublishCmd.Free;
  end;
end;

procedure TestPublishRejectsEmptyMetadataSourceFiles;
var
  InstallCmd: TPackageInstallLocalCommand;
  PublishCmd: TPackagePublishCmd;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  LocalPath: string;
  EmptySourcePath: string;
  InstallMetaPath: string;
  Settings: TFPDevSettings;
  SL: TStringList;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := GTempDir + PathDelim + 'install_root_publish_empty_source';
  Ctx.Config.GetSettingsManager.SetSettings(Settings);

  LocalPath := GTempDir + PathDelim + 'local_publish_empty_source';
  ForceDirectories(LocalPath);
  EmptySourcePath := GTempDir + PathDelim + 'empty_publish_source_dir';
  ForceDirectories(EmptySourcePath);

  SL := TStringList.Create;
  try
    SL.Text := 'unit empty_source_demo;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    SL.SaveToFile(LocalPath + PathDelim + 'empty_source_demo.pas');

    SL.Text := '{' + LineEnding +
      '  "name": "pkg_publish_empty_source",' + LineEnding +
      '  "version": "1.0.2"' + LineEnding +
      '}';
    SL.SaveToFile(LocalPath + PathDelim + 'package.json');
  finally
    SL.Free;
  end;

  InstallCmd := TPackageInstallLocalCommand.Create;
  try
    Ret := InstallCmd.Execute([LocalPath], Ctx);
    Check('publish empty source install-local EXIT_OK', Ret = EXIT_OK);
  finally
    InstallCmd.Free;
  end;

  InstallMetaPath := Settings.InstallRoot + PathDelim + 'packages' + PathDelim +
    'pkg_publish_empty_source' + PathDelim + 'package.json';
  SL := TStringList.Create;
  try
    SL.Text := '{' + LineEnding +
      '  "name": "pkg_publish_empty_source",' + LineEnding +
      '  "version": "1.0.2",' + LineEnding +
      '  "source_path": "' + EmptySourcePath + '"' + LineEnding +
      '}';
    SL.SaveToFile(InstallMetaPath);
  finally
    SL.Free;
  end;

  PublishCmd := TPackagePublishCmd.Create;
  try
    Ret := PublishCmd.Execute(['pkg_publish_empty_source'], Ctx);
    Check('publish empty source files EXIT_ERROR', Ret = EXIT_ERROR);
    Check('publish empty source files writes clear error',
      Pos(LowerCase(_Fmt(CMD_PKG_PUBLISH_SOURCE_NO_FILES, [EmptySourcePath])),
      LowerCase(StdErr.GetBuffer)) > 0);
  finally
    PublishCmd.Free;
  end;
end;

procedure TestPublishResolvesRelativeMetadataSourcePath;
var
  InstallCmd: TPackageInstallLocalCommand;
  PublishCmd: TPackagePublishCmd;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  LocalPath: string;
  Settings: TFPDevSettings;
  InstallMetaPath: string;
  PackageInstallPath: string;
  RelativeSourcePath: string;
  RelativeSourceDir: string;
  ArchivePath: string;
  SL: TStringList;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := GTempDir + PathDelim +
    'install_root_publish_relative_source';
  Ctx.Config.GetSettingsManager.SetSettings(Settings);

  LocalPath := GTempDir + PathDelim + 'local_publish_relative_source';
  ForceDirectories(LocalPath);

  SL := TStringList.Create;
  try
    SL.Text := 'unit relative_source_demo;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    SL.SaveToFile(LocalPath + PathDelim + 'relative_source_demo.pas');

    SL.Text := '{' + LineEnding +
      '  "name": "pkg_publish_relative_source",' + LineEnding +
      '  "version": "1.0.4"' + LineEnding +
      '}';
    SL.SaveToFile(LocalPath + PathDelim + 'package.json');
  finally
    SL.Free;
  end;

  InstallCmd := TPackageInstallLocalCommand.Create;
  try
    Ret := InstallCmd.Execute([LocalPath], Ctx);
    Check('publish relative source install-local EXIT_OK', Ret = EXIT_OK);
  finally
    InstallCmd.Free;
  end;

  PackageInstallPath := Settings.InstallRoot + PathDelim + 'packages' +
    PathDelim + 'pkg_publish_relative_source';
  RelativeSourcePath := 'src_rel';
  RelativeSourceDir := PackageInstallPath + PathDelim + RelativeSourcePath;
  ForceDirectories(RelativeSourceDir);

  SL := TStringList.Create;
  try
    SL.Text := 'unit relative_publish_source;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    SL.SaveToFile(RelativeSourceDir + PathDelim + 'relative_publish_source.pas');

    InstallMetaPath := PackageInstallPath + PathDelim + 'package.json';
    SL.Text := '{' + LineEnding +
      '  "name": "pkg_publish_relative_source",' + LineEnding +
      '  "version": "1.0.4",' + LineEnding +
      '  "source_path": "' + RelativeSourcePath + '"' + LineEnding +
      '}';
    SL.SaveToFile(InstallMetaPath);
  finally
    SL.Free;
  end;

  PublishCmd := TPackagePublishCmd.Create;
  try
    Ret := PublishCmd.Execute(['pkg_publish_relative_source'], Ctx);
    Check('publish relative source path EXIT_OK', Ret = EXIT_OK);
    ArchivePath := Settings.InstallRoot + PathDelim + 'publish' + PathDelim +
      'pkg_publish_relative_source-1.0.4.tar.gz';
    Check('publish relative source archive exists', FileExists(ArchivePath));
  finally
    PublishCmd.Free;
  end;
end;

procedure TestPublishReturnsIoErrorWhenMetadataUnreadable;
var
  InstallCmd: TPackageInstallLocalCommand;
  PublishCmd: TPackagePublishCmd;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  LocalPath: string;
  Settings: TFPDevSettings;
  MetadataPath: string;
  SL: TStringList;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := GTempDir + PathDelim +
    'install_root_publish_meta_unreadable';
  Ctx.Config.GetSettingsManager.SetSettings(Settings);

  LocalPath := GTempDir + PathDelim + 'local_publish_meta_unreadable';
  ForceDirectories(LocalPath);

  SL := TStringList.Create;
  try
    SL.Text := 'unit unreadable_meta_demo;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    SL.SaveToFile(LocalPath + PathDelim + 'unreadable_meta_demo.pas');

    SL.Text := '{' + LineEnding +
      '  "name": "pkg_publish_meta_unreadable",' + LineEnding +
      '  "version": "1.0.5"' + LineEnding +
      '}';
    SL.SaveToFile(LocalPath + PathDelim + 'package.json');
  finally
    SL.Free;
  end;

  InstallCmd := TPackageInstallLocalCommand.Create;
  try
    Ret := InstallCmd.Execute([LocalPath], Ctx);
    Check('publish unreadable metadata install-local EXIT_OK', Ret = EXIT_OK);
  finally
    InstallCmd.Free;
  end;

  MetadataPath := Settings.InstallRoot + PathDelim + 'packages' + PathDelim +
    'pkg_publish_meta_unreadable' + PathDelim + 'package.json';

{$IFDEF UNIX}
  Check('publish unreadable metadata chmod 000',
    fpchmod(MetadataPath, &000) = 0);

  PublishCmd := TPackagePublishCmd.Create;
  try
    Ret := PublishCmd.Execute(['pkg_publish_meta_unreadable'], Ctx);
    Check('publish unreadable metadata EXIT_IO_ERROR', Ret = EXIT_IO_ERROR);
    Check('publish unreadable metadata writes clear error',
      Pos('metadata', LowerCase(StdErr.GetBuffer)) > 0);
  finally
    PublishCmd.Free;
    fpchmod(MetadataPath, &600);
  end;
{$ELSE}
  Check('publish unreadable metadata test skipped on non-unix', True);
{$ENDIF}
end;

procedure TestPublishRejectsInvalidMetadataJson;
var
  InstallCmd: TPackageInstallLocalCommand;
  PublishCmd: TPackagePublishCmd;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  LocalPath: string;
  Settings: TFPDevSettings;
  MetadataPath: string;
  SL: TStringList;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := GTempDir + PathDelim +
    'install_root_publish_invalid_metadata';
  Ctx.Config.GetSettingsManager.SetSettings(Settings);

  LocalPath := GTempDir + PathDelim + 'local_publish_invalid_metadata';
  ForceDirectories(LocalPath);

  SL := TStringList.Create;
  try
    SL.Text := 'unit invalid_meta_demo;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    SL.SaveToFile(LocalPath + PathDelim + 'invalid_meta_demo.pas');

    SL.Text := '{' + LineEnding +
      '  "name": "pkg_publish_invalid_metadata",' + LineEnding +
      '  "version": "1.0.6"' + LineEnding +
      '}';
    SL.SaveToFile(LocalPath + PathDelim + 'package.json');
  finally
    SL.Free;
  end;

  InstallCmd := TPackageInstallLocalCommand.Create;
  try
    Ret := InstallCmd.Execute([LocalPath], Ctx);
    Check('publish invalid metadata install-local EXIT_OK', Ret = EXIT_OK);
  finally
    InstallCmd.Free;
  end;

  MetadataPath := Settings.InstallRoot + PathDelim + 'packages' + PathDelim +
    'pkg_publish_invalid_metadata' + PathDelim + 'package.json';
  SL := TStringList.Create;
  try
    SL.Text := '{"name":"pkg_publish_invalid_metadata",';
    SL.SaveToFile(MetadataPath);
  finally
    SL.Free;
  end;

  PublishCmd := TPackagePublishCmd.Create;
  try
    Ret := PublishCmd.Execute(['pkg_publish_invalid_metadata'], Ctx);
    Check('publish invalid metadata EXIT_ERROR', Ret = EXIT_ERROR);
    Check('publish invalid metadata writes parse error',
      Pos(LowerCase(_Fmt(CMD_PKG_META_INVALID, [''])),
      LowerCase(StdErr.GetBuffer)) > 0);
  finally
    PublishCmd.Free;
  end;
end;

procedure TestPublishReturnsIoErrorWhenTarUnavailable;
var
  InstallCmd: TPackageInstallLocalCommand;
  PublishCmd: TPackagePublishCmd;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  LocalPath: string;
  Settings: TFPDevSettings;
  SL: TStringList;
  SavedPath: string;
  FakePath: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := GTempDir + PathDelim + 'install_root_publish_io_error';
  Ctx.Config.GetSettingsManager.SetSettings(Settings);

  LocalPath := GTempDir + PathDelim + 'local_publish_io_error';
  ForceDirectories(LocalPath);

  SL := TStringList.Create;
  try
    SL.Text := 'unit io_error_demo;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    SL.SaveToFile(LocalPath + PathDelim + 'io_error_demo.pas');

    SL.Text := '{' + LineEnding +
      '  "name": "pkg_publish_io_error",' + LineEnding +
      '  "version": "1.0.3"' + LineEnding +
      '}';
    SL.SaveToFile(LocalPath + PathDelim + 'package.json');
  finally
    SL.Free;
  end;

  InstallCmd := TPackageInstallLocalCommand.Create;
  try
    Ret := InstallCmd.Execute([LocalPath], Ctx);
    Check('publish io error install-local EXIT_OK', Ret = EXIT_OK);
  finally
    InstallCmd.Free;
  end;

  SavedPath := get_env('PATH');
  FakePath := GTempDir + PathDelim + 'missing_bin_for_publish_test';
  Check('publish io error set fake PATH',
    set_env('PATH', FakePath));

  PublishCmd := TPackagePublishCmd.Create;
  try
    Ret := PublishCmd.Execute(['pkg_publish_io_error'], Ctx);
    Check('publish io error EXIT_IO_ERROR', Ret = EXIT_IO_ERROR);
    Check('publish io error writes archive failure',
      Pos('archive', LowerCase(StdErr.GetBuffer)) > 0);
  finally
    PublishCmd.Free;
    set_env('PATH', SavedPath);
  end;
end;

procedure TestPublishUnexpectedArg;
var Cmd: TPackagePublishCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackagePublishCmd.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_publish', 'extra'], Ctx);
    Check('publish unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestPublishUnknownOption;
var Cmd: TPackagePublishCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackagePublishCmd.Create;
  try
    Ret := Cmd.Execute(['missing_pkg_for_publish', '--unknown-option'], Ctx);
    Check('publish unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;
