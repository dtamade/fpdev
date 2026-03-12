program test_package_lockfile;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.package.lockfile,
  test_temp_paths;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  GTempRoot: string = '';

function BuildLockFilePath(const AFileName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GTempRoot) + AFileName;
end;

procedure Assert(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', TestName);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', TestName);
  end;
end;

procedure TestCreateLockFile;
var
  LockFile: TPackageLockFile;
  TempFile: string;
begin
  TempFile := BuildLockFilePath('test-lock.json');
  LockFile := TPackageLockFile.Create(TempFile);
  try
    Assert(LockFile.LockFilePath = TempFile, 'Create lock file with path');
    Assert(LockFile.ProjectName = '', 'Initial project name is empty');
    Assert(LockFile.ProjectVersion = '', 'Initial project version is empty');
  finally
    LockFile.Free;
  end;
end;

procedure TestSetProjectInfo;
var
  LockFile: TPackageLockFile;
  TempFile: string;
begin
  TempFile := BuildLockFilePath('test-lock.json');
  LockFile := TPackageLockFile.Create(TempFile);
  try
    LockFile.SetProjectInfo('myproject', '1.0.0');
    Assert(LockFile.ProjectName = 'myproject', 'Set project name');
    Assert(LockFile.ProjectVersion = '1.0.0', 'Set project version');
  finally
    LockFile.Free;
  end;
end;

procedure TestAddPackage;
var
  LockFile: TPackageLockFile;
  Deps: TStringList;
  TempFile: string;
begin
  TempFile := BuildLockFilePath('test-lock.json');
  LockFile := TPackageLockFile.Create(TempFile);
  try
    Deps := TStringList.Create;
    try
      Deps.Add('libbar=>=2.0.0');

      LockFile.AddPackage('libfoo', '1.2.3', '/path/to/libfoo-1.2.3.tar.gz', 'sha256-abc123', Deps);

      Assert(LockFile.HasPackage('libfoo'), 'Package added successfully');
      Assert(LockFile.GetPackageVersion('libfoo') = '1.2.3', 'Package version correct');
    finally
      Deps.Free;
    end;
  finally
    LockFile.Free;
  end;
end;

procedure TestSaveAndLoadLockFile;
var
  LockFile: TPackageLockFile;
  Deps: TStringList;
  TempFile: string;
begin
  TempFile := BuildLockFilePath('test-temp-lock.json');

  LockFile := TPackageLockFile.Create(TempFile);
  try
    LockFile.SetProjectInfo('testproject', '2.0.0');

    Deps := TStringList.Create;
    try
      Deps.Add('libbar=>=2.0.0');
      LockFile.AddPackage('libfoo', '1.2.3', '/path/to/libfoo.tar.gz', 'sha256-xyz', Deps);
    finally
      Deps.Free;
    end;

    Assert(LockFile.Save, 'Save lock file');
  finally
    LockFile.Free;
  end;

  LockFile := TPackageLockFile.Create(TempFile);
  try
    Assert(LockFile.Load, 'Load lock file');
    Assert(LockFile.ProjectName = 'testproject', 'Loaded project name');
    Assert(LockFile.ProjectVersion = '2.0.0', 'Loaded project version');
    Assert(LockFile.HasPackage('libfoo'), 'Loaded package exists');
    Assert(LockFile.GetPackageVersion('libfoo') = '1.2.3', 'Loaded package version');
  finally
    LockFile.Free;
  end;
end;

procedure TestGetPackageNames;
var
  LockFile: TPackageLockFile;
  Deps: TStringList;
  Names: TStringList;
  TempFile: string;
begin
  TempFile := BuildLockFilePath('test-lock.json');
  LockFile := TPackageLockFile.Create(TempFile);
  try
    Deps := TStringList.Create;
    try
      LockFile.AddPackage('libfoo', '1.0.0', '/path/foo.tar.gz', 'sha256-1', Deps);
      LockFile.AddPackage('libbar', '2.0.0', '/path/bar.tar.gz', 'sha256-2', Deps);

      Names := LockFile.GetPackageNames;
      try
        Assert(Names.Count = 2, 'Get package names count');
        Assert(Names.IndexOf('libfoo') >= 0, 'Package libfoo in list');
        Assert(Names.IndexOf('libbar') >= 0, 'Package libbar in list');
      finally
        Names.Free;
      end;
    finally
      Deps.Free;
    end;
  finally
    LockFile.Free;
  end;
end;

procedure TestClearPackages;
var
  LockFile: TPackageLockFile;
  Deps: TStringList;
  TempFile: string;
begin
  TempFile := BuildLockFilePath('test-lock.json');
  LockFile := TPackageLockFile.Create(TempFile);
  try
    Deps := TStringList.Create;
    try
      LockFile.AddPackage('libfoo', '1.0.0', '/path/foo.tar.gz', 'sha256-1', Deps);
      Assert(LockFile.HasPackage('libfoo'), 'Package added before clear');

      LockFile.Clear;
      Assert(not LockFile.HasPackage('libfoo'), 'Package removed after clear');
    finally
      Deps.Free;
    end;
  finally
    LockFile.Free;
  end;
end;

procedure TestLoadNonExistentFile;
var
  LockFile: TPackageLockFile;
  TempFile: string;
begin
  TempFile := BuildLockFilePath('nonexistent-lock.json');
  LockFile := TPackageLockFile.Create(TempFile);
  try
    Assert(not LockFile.Load, 'Load nonexistent file fails');
    Assert(LockFile.GetLastError <> '', 'Error message set');
  finally
    LockFile.Free;
  end;
end;

procedure TestPackageWithDependencies;
var
  LockFile: TPackageLockFile;
  Deps: TStringList;
  TempFile: string;
begin
  TempFile := BuildLockFilePath('test-deps-lock.json');

  LockFile := TPackageLockFile.Create(TempFile);
  try
    LockFile.SetProjectInfo('depstest', '1.0.0');

    Deps := TStringList.Create;
    try
      Deps.Add('libbar=>=2.0.0');
      Deps.Add('libbaz=^1.5.0');
      LockFile.AddPackage('libfoo', '1.2.3', '/path/foo.tar.gz', 'sha256-abc', Deps);
    finally
      Deps.Free;
    end;

    Assert(LockFile.Save, 'Save lock file with dependencies');
  finally
    LockFile.Free;
  end;

  LockFile := TPackageLockFile.Create(TempFile);
  try
    Assert(LockFile.Load, 'Load lock file with dependencies');
    Assert(LockFile.HasPackage('libfoo'), 'Package with dependencies loaded');
  finally
    LockFile.Free;
  end;
end;

begin
  GTempRoot := CreateUniqueTempDir('test_package_lockfile');
  WriteLn('=== TPackageLockFile Tests ===');
  WriteLn;

  TestCreateLockFile;
  TestSetProjectInfo;
  TestAddPackage;
  TestSaveAndLoadLockFile;
  TestGetPackageNames;
  TestClearPackages;
  TestLoadNonExistentFile;
  TestPackageWithDependencies;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  CleanupTempDir(GTempRoot);

  if TestsFailed > 0 then
    Halt(1);
end.
