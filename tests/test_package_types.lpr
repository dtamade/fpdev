program test_package_types;

{$mode objfpc}{$H+}

{
================================================================================
  test_package_types - Tests for fpdev.package.types
================================================================================

  Tests the extracted package type definitions and helper functions:
  - TSemanticVersion parsing and comparison
  - TPackageInfo helpers
  - Version validation

  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes, fpdev.package.types;

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

{ TSemanticVersion Tests }

procedure TestParseSimpleVersion;
var
  V: TSemanticVersion;
begin
  V := ParseSemanticVersion('1.2.3');
  Test('Parse 1.2.3 - Valid', V.Valid);
  Test('Parse 1.2.3 - Major', V.Major = 1);
  Test('Parse 1.2.3 - Minor', V.Minor = 2);
  Test('Parse 1.2.3 - Patch', V.Patch = 3);
  Test('Parse 1.2.3 - No PreRelease', V.PreRelease = '');
end;

procedure TestParseVersionWithPreRelease;
var
  V: TSemanticVersion;
begin
  V := ParseSemanticVersion('2.0.0-beta1');
  Test('Parse 2.0.0-beta1 - Valid', V.Valid);
  Test('Parse 2.0.0-beta1 - Major', V.Major = 2);
  Test('Parse 2.0.0-beta1 - Minor', V.Minor = 0);
  Test('Parse 2.0.0-beta1 - Patch', V.Patch = 0);
  Test('Parse 2.0.0-beta1 - PreRelease', V.PreRelease = 'beta1');
end;

procedure TestParsePartialVersion;
var
  V: TSemanticVersion;
begin
  // Major only
  V := ParseSemanticVersion('5');
  Test('Parse 5 - Valid', V.Valid);
  Test('Parse 5 - Major', V.Major = 5);
  Test('Parse 5 - Minor zero', V.Minor = 0);
  Test('Parse 5 - Patch zero', V.Patch = 0);

  // Major.Minor only
  V := ParseSemanticVersion('3.2');
  Test('Parse 3.2 - Valid', V.Valid);
  Test('Parse 3.2 - Major', V.Major = 3);
  Test('Parse 3.2 - Minor', V.Minor = 2);
  Test('Parse 3.2 - Patch zero', V.Patch = 0);
end;

procedure TestParseInvalidVersion;
var
  V: TSemanticVersion;
begin
  V := ParseSemanticVersion('');
  Test('Parse empty - Invalid', not V.Valid);

  V := ParseSemanticVersion('abc');
  Test('Parse abc - Invalid', not V.Valid);

  V := ParseSemanticVersion('1.2.x');
  Test('Parse 1.2.x - Invalid', not V.Valid);
end;

procedure TestCompareVersions;
var
  V1, V2: TSemanticVersion;
  Cmp: Integer;
begin
  // 1.0.0 < 2.0.0
  V1 := ParseSemanticVersion('1.0.0');
  V2 := ParseSemanticVersion('2.0.0');
  Cmp := CompareSemanticVersions(V1, V2);
  Test('1.0.0 < 2.0.0', Cmp < 0);

  // 1.1.0 > 1.0.0
  V1 := ParseSemanticVersion('1.1.0');
  V2 := ParseSemanticVersion('1.0.0');
  Cmp := CompareSemanticVersions(V1, V2);
  Test('1.1.0 > 1.0.0', Cmp > 0);

  // 1.0.1 > 1.0.0
  V1 := ParseSemanticVersion('1.0.1');
  V2 := ParseSemanticVersion('1.0.0');
  Cmp := CompareSemanticVersions(V1, V2);
  Test('1.0.1 > 1.0.0', Cmp > 0);

  // 1.0.0 = 1.0.0
  V1 := ParseSemanticVersion('1.0.0');
  V2 := ParseSemanticVersion('1.0.0');
  Cmp := CompareSemanticVersions(V1, V2);
  Test('1.0.0 = 1.0.0', Cmp = 0);

  // 1.0.0 > 1.0.0-alpha (pre-release has lower precedence)
  V1 := ParseSemanticVersion('1.0.0');
  V2 := ParseSemanticVersion('1.0.0-alpha');
  Cmp := CompareSemanticVersions(V1, V2);
  Test('1.0.0 > 1.0.0-alpha', Cmp > 0);
end;

procedure TestSemanticVersionToString;
var
  V: TSemanticVersion;
  S: string;
begin
  V := ParseSemanticVersion('1.2.3');
  S := SemanticVersionToString(V);
  Test('ToString 1.2.3', S = '1.2.3');

  V := ParseSemanticVersion('2.0.0-rc1');
  S := SemanticVersionToString(V);
  Test('ToString 2.0.0-rc1', S = '2.0.0-rc1');

  V.Valid := False;
  S := SemanticVersionToString(V);
  Test('ToString invalid', S = '(invalid)');
end;

procedure TestIsValidSemanticVersion;
begin
  Test('IsValid 1.0.0', IsValidSemanticVersion('1.0.0'));
  Test('IsValid 3.2.2', IsValidSemanticVersion('3.2.2'));
  Test('IsValid 1.0.0-beta', IsValidSemanticVersion('1.0.0-beta'));
  Test('IsValid empty - false', not IsValidSemanticVersion(''));
  Test('IsValid abc - false', not IsValidSemanticVersion('abc'));
end;

{ TPackageInfo Tests }

procedure TestEmptyPackageInfo;
var
  Info: TPackageInfo;
begin
  Info := EmptyPackageInfo;
  Test('EmptyPackageInfo - Name empty', Info.Name = '');
  Test('EmptyPackageInfo - Version empty', Info.Version = '');
  Test('EmptyPackageInfo - Not installed', not Info.Installed);
  Test('EmptyPackageInfo - No deps', Length(Info.Dependencies) = 0);
end;

procedure TestPackageInfoToString;
var
  Info: TPackageInfo;
  S: string;
begin
  Info := EmptyPackageInfo;
  Info.Name := 'testpkg';
  Info.Version := '1.0.0';

  S := PackageInfoToString(Info);
  Test('PackageInfoToString basic', Pos('testpkg', S) > 0);
  Test('PackageInfoToString version', Pos('1.0.0', S) > 0);

  Info.Installed := True;
  S := PackageInfoToString(Info);
  Test('PackageInfoToString installed', Pos('installed', S) > 0);
end;

{ Type definitions tests }

procedure TestVerificationStatusEnum;
begin
  Test('vsValid = 0', Ord(vsValid) = 0);
  Test('vsInvalid = 1', Ord(vsInvalid) = 1);
  Test('vsMissingFiles = 2', Ord(vsMissingFiles) = 2);
  Test('vsMetadataError = 3', Ord(vsMetadataError) = 3);
end;

procedure TestPackageErrorCodeEnum;
begin
  Test('pecNone = 0', Ord(pecNone) = 0);
  Test('pecPackageNotFound = 1', Ord(pecPackageNotFound) = 1);
  Test('pecCircularDependency = 3', Ord(pecCircularDependency) = 3);
end;

begin
  WriteLn('=== fpdev.package.types Tests ===');
  WriteLn;

  // TSemanticVersion tests
  TestParseSimpleVersion;
  TestParseVersionWithPreRelease;
  TestParsePartialVersion;
  TestParseInvalidVersion;
  TestCompareVersions;
  TestSemanticVersionToString;
  TestIsValidSemanticVersion;

  // TPackageInfo tests
  TestEmptyPackageInfo;
  TestPackageInfoToString;

  // Enum tests
  TestVerificationStatusEnum;
  TestPackageErrorCodeEnum;

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
