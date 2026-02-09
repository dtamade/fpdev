program test_resource_repo_package;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.resource.repo.package;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TempDir: string;

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

procedure CreateDummyFile(const APath: string);
var
  F: TFileStream;
begin
  ForceDirectories(ExtractFileDir(APath));
  F := TFileStream.Create(APath, fmCreate);
  F.Free;
end;

procedure TestResolveDirectPath;
var
  PkgPath: string;
begin
  // packages/<name>/<name>.json
  PkgPath := TempDir + PathDelim + 'packages' + PathDelim + 'mylib' + PathDelim + 'mylib.json';
  CreateDummyFile(PkgPath);

  Check(ResourceRepoResolvePackageMetaPath(TempDir, 'mylib') = PkgPath,
        'ResolvePath: direct packages/<name>/<name>.json');
end;

procedure TestResolveCorePath;
var
  PkgPath: string;
begin
  // packages/core/<name>/<name>.json
  PkgPath := TempDir + PathDelim + 'packages' + PathDelim + 'core' + PathDelim +
    'corelib' + PathDelim + 'corelib.json';
  CreateDummyFile(PkgPath);

  Check(ResourceRepoResolvePackageMetaPath(TempDir, 'corelib') = PkgPath,
        'ResolvePath: packages/core/<name>/<name>.json');
end;

procedure TestResolveUIPath;
var
  PkgPath: string;
begin
  // packages/ui/<name>/<name>.json
  PkgPath := TempDir + PathDelim + 'packages' + PathDelim + 'ui' + PathDelim +
    'uilib' + PathDelim + 'uilib.json';
  CreateDummyFile(PkgPath);

  Check(ResourceRepoResolvePackageMetaPath(TempDir, 'uilib') = PkgPath,
        'ResolvePath: packages/ui/<name>/<name>.json');
end;

procedure TestResolveUtilsPath;
var
  PkgPath: string;
begin
  // packages/utils/<name>/<name>.json
  PkgPath := TempDir + PathDelim + 'packages' + PathDelim + 'utils' + PathDelim +
    'utillib' + PathDelim + 'utillib.json';
  CreateDummyFile(PkgPath);

  Check(ResourceRepoResolvePackageMetaPath(TempDir, 'utillib') = PkgPath,
        'ResolvePath: packages/utils/<name>/<name>.json');
end;

procedure TestResolveNotFound;
begin
  Check(ResourceRepoResolvePackageMetaPath(TempDir, 'nonexistent') = '',
        'ResolvePath: not found -> empty');
end;

procedure TestResolvePriorityOrder;
var
  DirectPath, CorePath: string;
begin
  // Create both direct and core paths - direct should win
  DirectPath := TempDir + PathDelim + 'packages' + PathDelim + 'duallib' + PathDelim + 'duallib.json';
  CorePath := TempDir + PathDelim + 'packages' + PathDelim + 'core' + PathDelim +
    'duallib' + PathDelim + 'duallib.json';
  CreateDummyFile(DirectPath);
  CreateDummyFile(CorePath);

  Check(ResourceRepoResolvePackageMetaPath(TempDir, 'duallib') = DirectPath,
        'ResolvePath: direct path takes priority over core');
end;

begin
  Randomize;
  TempDir := IncludeTrailingPathDelimiter(GetTempDir(True)) +
    'test_repo_pkg_' + IntToStr(Random(100000));
  ForceDirectories(TempDir);

  WriteLn('=== Resource Repo Package Unit Tests ===');
  WriteLn;

  TestResolveDirectPath;
  TestResolveCorePath;
  TestResolveUIPath;
  TestResolveUtilsPath;
  TestResolveNotFound;
  TestResolvePriorityOrder;

  // Cleanup - best effort
  // RemoveDir won't remove non-empty dirs, but that's ok for temp

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
