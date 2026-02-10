program test_resource_repo_types;

{$mode objfpc}{$H+}

{
================================================================================
  test_resource_repo_types - Tests for fpdev.resource.repo.types
================================================================================

  Tests the extracted resource repository type definitions:
  - TMirrorInfo and helper functions
  - TResourceRepoConfig
  - TPlatformInfo
  - TCrossToolchainInfo
  - TRepoPackageInfo

  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, fpdev.resource.repo.types;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Test(const AName: string; ACondition: Boolean);
begin
  Inc(GTestCount);
  if ACondition then
  begin
    Inc(GPassCount);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('[FAIL] ', AName);
  end;
end;

{ TMirrorInfo Tests }

procedure TestEmptyMirrorInfoDefaults;
var
  Info: TMirrorInfo;
begin
  Info := EmptyMirrorInfo;
  Test('EmptyMirrorInfo Name empty', Info.Name = '');
  Test('EmptyMirrorInfo URL empty', Info.URL = '');
  Test('EmptyMirrorInfo Region empty', Info.Region = '');
  Test('EmptyMirrorInfo Priority zero', Info.Priority = 0);
end;

procedure TestMirrorInfoToString;
var
  Info: TMirrorInfo;
  S: string;
begin
  Info.Name := 'GitHub';
  Info.URL := 'https://github.com';
  Info.Region := 'us';
  Info.Priority := 1;

  S := MirrorInfoToString(Info);
  Test('MirrorInfoToString contains name', Pos('GitHub', S) > 0);
  Test('MirrorInfoToString contains URL', Pos('github.com', S) > 0);
  Test('MirrorInfoToString contains region', Pos('us', S) > 0);
  Test('MirrorInfoToString contains priority', Pos('priority=1', S) > 0);
end;

{ TResourceRepoConfig Tests }

procedure TestEmptyResourceRepoConfigDefaults;
var
  Config: TResourceRepoConfig;
begin
  Config := EmptyResourceRepoConfig;
  Test('EmptyResourceRepoConfig URL empty', Config.URL = '');
  Test('EmptyResourceRepoConfig Mirrors empty', Length(Config.Mirrors) = 0);
  Test('EmptyResourceRepoConfig MirrorInfos empty', Length(Config.MirrorInfos) = 0);
  Test('EmptyResourceRepoConfig LocalPath empty', Config.LocalPath = '');
  Test('EmptyResourceRepoConfig Branch is main', Config.Branch = 'main');
  Test('EmptyResourceRepoConfig AutoUpdate true', Config.AutoUpdate = True);
  Test('EmptyResourceRepoConfig UpdateIntervalHours 24', Config.UpdateIntervalHours = 24);
end;

{ TPlatformInfo Tests }

procedure TestEmptyPlatformInfoDefaults;
var
  Info: TPlatformInfo;
begin
  Info := EmptyPlatformInfo;
  Test('EmptyPlatformInfo URL empty', Info.URL = '');
  Test('EmptyPlatformInfo Mirrors empty', Length(Info.Mirrors) = 0);
  Test('EmptyPlatformInfo Path empty', Info.Path = '');
  Test('EmptyPlatformInfo Executable empty', Info.Executable = '');
  Test('EmptyPlatformInfo SHA256 empty', Info.SHA256 = '');
  Test('EmptyPlatformInfo Size zero', Info.Size = 0);
  Test('EmptyPlatformInfo Tested false', Info.Tested = False);
end;

procedure TestPlatformInfoToStringWithURL;
var
  Info: TPlatformInfo;
  S: string;
begin
  Info := EmptyPlatformInfo;
  Info.URL := 'https://example.com/file.tar.gz';
  Info.Size := 12345;

  S := PlatformInfoToString(Info);
  Test('PlatformInfoToString with URL contains URL', Pos('URL:', S) > 0);
  Test('PlatformInfoToString with URL contains size', Pos('12345', S) > 0);
end;

procedure TestPlatformInfoToStringWithPath;
var
  Info: TPlatformInfo;
  S: string;
begin
  Info := EmptyPlatformInfo;
  Info.Path := 'resources/bootstrap/3.2.2';
  Info.Size := 54321;

  S := PlatformInfoToString(Info);
  Test('PlatformInfoToString with Path contains Path', Pos('Path:', S) > 0);
  Test('PlatformInfoToString with Path contains size', Pos('54321', S) > 0);
end;

{ TCrossToolchainInfo Tests }

procedure TestEmptyCrossToolchainInfoDefaults;
var
  Info: TCrossToolchainInfo;
begin
  Info := EmptyCrossToolchainInfo;
  Test('EmptyCrossToolchainInfo TargetName empty', Info.TargetName = '');
  Test('EmptyCrossToolchainInfo DisplayName empty', Info.DisplayName = '');
  Test('EmptyCrossToolchainInfo CPU empty', Info.CPU = '');
  Test('EmptyCrossToolchainInfo OS empty', Info.OS = '');
  Test('EmptyCrossToolchainInfo BinutilsPrefix empty', Info.BinutilsPrefix = '');
  Test('EmptyCrossToolchainInfo BinutilsArchive empty', Info.BinutilsArchive = '');
  Test('EmptyCrossToolchainInfo LibsArchive empty', Info.LibsArchive = '');
  Test('EmptyCrossToolchainInfo BinutilsSHA256 empty', Info.BinutilsSHA256 = '');
  Test('EmptyCrossToolchainInfo LibsSHA256 empty', Info.LibsSHA256 = '');
end;

procedure TestCrossToolchainInfoAssignment;
var
  Info: TCrossToolchainInfo;
begin
  Info := EmptyCrossToolchainInfo;
  Info.TargetName := 'win64';
  Info.DisplayName := 'Windows 64-bit';
  Info.CPU := 'x86_64';
  Info.OS := 'win64';
  Info.BinutilsPrefix := 'x86_64-w64-mingw32-';

  Test('CrossToolchainInfo TargetName assigned', Info.TargetName = 'win64');
  Test('CrossToolchainInfo DisplayName assigned', Info.DisplayName = 'Windows 64-bit');
  Test('CrossToolchainInfo CPU assigned', Info.CPU = 'x86_64');
  Test('CrossToolchainInfo OS assigned', Info.OS = 'win64');
  Test('CrossToolchainInfo BinutilsPrefix assigned', Info.BinutilsPrefix = 'x86_64-w64-mingw32-');
end;

{ TRepoPackageInfo Tests }

procedure TestEmptyRepoPackageInfoDefaults;
var
  Info: TRepoPackageInfo;
begin
  Info := EmptyRepoPackageInfo;
  Test('EmptyRepoPackageInfo Name empty', Info.Name = '');
  Test('EmptyRepoPackageInfo Version empty', Info.Version = '');
  Test('EmptyRepoPackageInfo Description empty', Info.Description = '');
  Test('EmptyRepoPackageInfo Category empty', Info.Category = '');
  Test('EmptyRepoPackageInfo Archive empty', Info.Archive = '');
  Test('EmptyRepoPackageInfo SHA256 empty', Info.SHA256 = '');
  Test('EmptyRepoPackageInfo Dependencies empty', Length(Info.Dependencies) = 0);
  Test('EmptyRepoPackageInfo FPCMinVersion empty', Info.FPCMinVersion = '');
end;

procedure TestRepoPackageInfoAssignment;
var
  Info: TRepoPackageInfo;
begin
  Info := EmptyRepoPackageInfo;
  Info.Name := 'my-package';
  Info.Version := '1.2.3';
  Info.Description := 'A test package';
  Info.Category := 'utils';
  SetLength(Info.Dependencies, 2);
  Info.Dependencies[0] := 'dep1';
  Info.Dependencies[1] := 'dep2';
  Info.FPCMinVersion := '3.2.0';

  Test('RepoPackageInfo Name assigned', Info.Name = 'my-package');
  Test('RepoPackageInfo Version assigned', Info.Version = '1.2.3');
  Test('RepoPackageInfo Description assigned', Info.Description = 'A test package');
  Test('RepoPackageInfo Category assigned', Info.Category = 'utils');
  Test('RepoPackageInfo Dependencies count', Length(Info.Dependencies) = 2);
  Test('RepoPackageInfo Dependencies[0]', Info.Dependencies[0] = 'dep1');
  Test('RepoPackageInfo Dependencies[1]', Info.Dependencies[1] = 'dep2');
  Test('RepoPackageInfo FPCMinVersion assigned', Info.FPCMinVersion = '3.2.0');
end;

{ TMirrorArray Tests }

procedure TestMirrorArray;
var
  Mirrors: TMirrorArray;
begin
  SetLength(Mirrors, 3);
  Mirrors[0] := EmptyMirrorInfo;
  Mirrors[0].Name := 'Mirror1';
  Mirrors[0].Priority := 1;

  Mirrors[1] := EmptyMirrorInfo;
  Mirrors[1].Name := 'Mirror2';
  Mirrors[1].Priority := 2;

  Mirrors[2] := EmptyMirrorInfo;
  Mirrors[2].Name := 'Mirror3';
  Mirrors[2].Priority := 3;

  Test('MirrorArray length', Length(Mirrors) = 3);
  Test('MirrorArray[0].Name', Mirrors[0].Name = 'Mirror1');
  Test('MirrorArray[1].Priority', Mirrors[1].Priority = 2);
  Test('MirrorArray[2].Name', Mirrors[2].Name = 'Mirror3');
end;

{ Integration Tests }

procedure TestRecordCopying;
var
  Info1, Info2: TPlatformInfo;
begin
  Info1 := EmptyPlatformInfo;
  Info1.URL := 'https://test.com';
  Info1.Size := 1000;
  Info1.SHA256 := 'abc123';

  Info2 := Info1;  // Copy record

  Test('Record copy URL', Info2.URL = 'https://test.com');
  Test('Record copy Size', Info2.Size = 1000);
  Test('Record copy SHA256', Info2.SHA256 = 'abc123');

  // Modify original
  Info1.URL := 'https://modified.com';
  Test('Record copy independent', Info2.URL = 'https://test.com');
end;

begin
  WriteLn('=== fpdev.resource.repo.types Tests ===');
  WriteLn;

  // TMirrorInfo tests
  TestEmptyMirrorInfoDefaults;
  TestMirrorInfoToString;
  TestMirrorArray;

  // TResourceRepoConfig tests
  TestEmptyResourceRepoConfigDefaults;

  // TPlatformInfo tests
  TestEmptyPlatformInfoDefaults;
  TestPlatformInfoToStringWithURL;
  TestPlatformInfoToStringWithPath;

  // TCrossToolchainInfo tests
  TestEmptyCrossToolchainInfoDefaults;
  TestCrossToolchainInfoAssignment;

  // TRepoPackageInfo tests
  TestEmptyRepoPackageInfoDefaults;
  TestRepoPackageInfoAssignment;

  // Integration tests
  TestRecordCopying;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Total:  ', GTestCount);
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);

  if GFailCount > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
