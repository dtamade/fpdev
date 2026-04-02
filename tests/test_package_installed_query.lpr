program test_package_installed_query;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.package.types,
  fpdev.utils.fs,
  fpdev.package.query.info,
  fpdev.package.query.installed,
  test_temp_paths;

type
  TStubPackageReader = class
  public
    function ReadPackageInfo(const APackageName: string): TPackageInfo;
  end;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function TStubPackageReader.ReadPackageInfo(const APackageName: string): TPackageInfo;
begin
  Initialize(Result);
  Result.Name := APackageName;
  Result.Version := '1.0.0';
  Result.Description := 'installed:' + APackageName;
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('PASS: ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('FAIL: ', AMessage);
  end;
end;

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual,
    AMessage + ' (expected: ' + AExpected + ', got: ' + AActual + ')');
end;

function CreateTempDir(const ASuffix: string): string;
begin
  Result := CreateUniqueTempDir('fpdev-pkg-installed-' + ASuffix);
  AssertTrue(PathUsesSystemTempRoot(Result),
    'installed-query temp dir lives under system temp');
end;

procedure WriteTextFile(const APath, AContent: string);
var
  Content: TStringList;
begin
  Content := TStringList.Create;
  try
    Content.Text := AContent;
    Content.SaveToFile(APath);
  finally
    Content.Free;
  end;
end;

procedure TestGetPackageInstallPathCoreJoinsRegistryAndName;
var
  InstallPath: string;
begin
  InstallPath := GetPackageInstallPathCore('/tmp/fpdev-registry', 'alpha');
  AssertEquals('/tmp/fpdev-registry' + PathDelim + 'alpha', InstallPath,
    'install path is built from registry root and package name');
end;

procedure TestIsPackageInstalledCoreChecksDirectory;
var
  TempRoot: string;
  RegistryDir: string;
begin
  TempRoot := CreateTempDir('installed_flag');
  try
    RegistryDir := IncludeTrailingPathDelimiter(TempRoot) + 'packages';
    ForceDirectories(RegistryDir + PathDelim + 'alpha');

    AssertTrue(IsPackageInstalledCore(RegistryDir, 'alpha'),
      'installed package directory is detected');
    AssertTrue(not IsPackageInstalledCore(RegistryDir, 'missing'),
      'missing package directory is reported as not installed');
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestValidatePackageNameCoreRejectsInvalidNames;
begin
  AssertTrue(ValidatePackageNameCore('alpha', '/'),
    'plain package name is accepted');
  AssertTrue(not ValidatePackageNameCore('', '/'),
    'empty package name is rejected');
  AssertTrue(not ValidatePackageNameCore('alpha beta', '/'),
    'package name with spaces is rejected');
  AssertTrue(not ValidatePackageNameCore('scope/alpha', '/'),
    'package name with path separator is rejected');
end;

procedure TestGetPackageInfoCoreReadsMetadata;
var
  TempRoot: string;
  RegistryDir: string;
  PackageDir: string;
  Info: TPackageInfo;
begin
  TempRoot := CreateTempDir('info_metadata');
  try
    RegistryDir := IncludeTrailingPathDelimiter(TempRoot) + 'packages';
    PackageDir := RegistryDir + PathDelim + 'alpha';
    ForceDirectories(PackageDir);
    WriteTextFile(
      IncludeTrailingPathDelimiter(PackageDir) + 'package.json',
      '{' + LineEnding +
      '  "name": "alpha",' + LineEnding +
      '  "version": "1.2.3",' + LineEnding +
      '  "description": "alpha package",' + LineEnding +
      '  "homepage": "https://example.com",' + LineEnding +
      '  "license": "MIT",' + LineEnding +
      '  "repository": "https://repo.example.com",' + LineEnding +
      '  "source_path": "/src/alpha"' + LineEnding +
      '}'
    );

    Info := GetPackageInfoCore('alpha', RegistryDir, 'Installed package');
    AssertTrue(Info.Installed, 'metadata lookup marks installed package');
    AssertEquals('alpha', Info.Name, 'metadata name is loaded');
    AssertEquals('1.2.3', Info.Version, 'metadata version is loaded');
    AssertEquals('alpha package', Info.Description, 'metadata description is loaded');
    AssertEquals('https://example.com', Info.Homepage, 'metadata homepage is loaded');
    AssertEquals('MIT', Info.License, 'metadata license is loaded');
    AssertEquals('https://repo.example.com', Info.Repository, 'metadata repository is loaded');
    AssertEquals('/src/alpha', Info.SourcePath, 'metadata source path is loaded');
    AssertEquals(PackageDir, Info.InstallPath, 'install path comes from registry layout');
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestGetPackageInfoCoreFallsBackWhenMetadataMissing;
var
  TempRoot: string;
  RegistryDir: string;
  PackageDir: string;
  Info: TPackageInfo;
begin
  TempRoot := CreateTempDir('info_missing');
  try
    RegistryDir := IncludeTrailingPathDelimiter(TempRoot) + 'packages';
    PackageDir := RegistryDir + PathDelim + 'beta';
    ForceDirectories(PackageDir);

    Info := GetPackageInfoCore('beta', RegistryDir, 'Installed package');
    AssertTrue(Info.Installed, 'package without metadata is still treated as installed');
    AssertEquals('', Info.Version, 'missing metadata leaves version empty');
    AssertEquals('Installed package', Info.Description,
      'missing metadata uses fallback description');
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestGetPackageInfoCoreFallsBackWhenMetadataIsInvalid;
var
  TempRoot: string;
  RegistryDir: string;
  PackageDir: string;
  Info: TPackageInfo;
begin
  TempRoot := CreateTempDir('info_invalid');
  try
    RegistryDir := IncludeTrailingPathDelimiter(TempRoot) + 'packages';
    PackageDir := RegistryDir + PathDelim + 'gamma';
    ForceDirectories(PackageDir);
    WriteTextFile(
      IncludeTrailingPathDelimiter(PackageDir) + 'package.json',
      '{ invalid json }'
    );

    Info := GetPackageInfoCore('gamma', RegistryDir, 'Installed package');
    AssertTrue(Info.Installed, 'invalid metadata keeps installed package visible');
    AssertEquals('', Info.Version, 'invalid metadata leaves version empty');
    AssertEquals('Installed package', Info.Description,
      'invalid metadata uses fallback description');
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestGetInstalledPackagesCoreSkipsNonDirectories;
var
  TempRoot: string;
  RegistryDir: string;
  Packages: TPackageArray;
  Reader: TStubPackageReader;
  FoundAlpha: Boolean;
  FoundBeta: Boolean;
  Index: Integer;
begin
  TempRoot := CreateTempDir('installed_scan');
  try
    RegistryDir := IncludeTrailingPathDelimiter(TempRoot) + 'packages';
    ForceDirectories(RegistryDir + PathDelim + 'alpha');
    ForceDirectories(RegistryDir + PathDelim + 'beta');
    WriteTextFile(RegistryDir + PathDelim + 'README.txt', 'not a package directory');

    Reader := TStubPackageReader.Create;
    try
      Packages := GetInstalledPackagesCore(RegistryDir, @Reader.ReadPackageInfo);
      AssertTrue(Length(Packages) = 2, 'only package directories are returned');

      FoundAlpha := False;
      FoundBeta := False;
      for Index := 0 to High(Packages) do
      begin
        if Packages[Index].Name = 'alpha' then
        begin
          FoundAlpha := True;
          AssertEquals('installed:alpha', Packages[Index].Description,
            'alpha metadata is resolved through callback');
        end;
        if Packages[Index].Name = 'beta' then
        begin
          FoundBeta := True;
          AssertEquals('installed:beta', Packages[Index].Description,
            'beta metadata is resolved through callback');
        end;
      end;

      AssertTrue(FoundAlpha, 'alpha package directory is included');
      AssertTrue(FoundBeta, 'beta package directory is included');
    finally
      Reader.Free;
    end;
  finally
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestGetPackageInstallPathCoreJoinsRegistryAndName;
  TestIsPackageInstalledCoreChecksDirectory;
  TestValidatePackageNameCoreRejectsInvalidNames;
  TestGetPackageInfoCoreReadsMetadata;
  TestGetPackageInfoCoreFallsBackWhenMetadataMissing;
  TestGetPackageInfoCoreFallsBackWhenMetadataIsInvalid;
  TestGetInstalledPackagesCoreSkipsNonDirectories;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
