program test_package_registry_queryflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson,
  fpdev.package.registry.queryflow,
  test_temp_paths;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

function BuildSampleIndex: TJSONObject;
var
  Packages: TJSONObject;
  Json: TJSONObject;
  Pkg: TJSONObject;
  Versions: TJSONArray;
begin
  Json := TJSONObject.Create;
  Json.Add('version', '1.0');
  Packages := TJSONObject.Create;
  Json.Add('packages', Packages);

  Pkg := TJSONObject.Create;
  Pkg.Add('name', 'jsonlib');
  Pkg.Add('description', 'JSON parsing library');
  Pkg.Add('author', 'Test Author');
  Pkg.Add('license', 'MIT');
  Versions := TJSONArray.Create;
  Versions.Add('1.0.0');
  Versions.Add('1.1.0');
  Pkg.Add('versions', Versions);
  Pkg.Add('latest', '1.1.0');
  Packages.Add('jsonlib', Pkg);

  Pkg := TJSONObject.Create;
  Pkg.Add('name', 'xmllib');
  Pkg.Add('description', 'XML utilities');
  Pkg.Add('author', 'Another Author');
  Pkg.Add('license', 'BSD');
  Versions := TJSONArray.Create;
  Versions.Add('2.0.0');
  Pkg.Add('versions', Versions);
  Pkg.Add('latest', '2.0.0');
  Packages.Add('xmllib', Pkg);

  Result := Json;
end;

procedure TestGetPackageMetadataCoreReturnsClone;
var
  Index: TJSONObject;
  Metadata: TJSONObject;
begin
  Index := BuildSampleIndex;
  try
    Metadata := GetPackageMetadataCore(Index, 'jsonlib');
    try
      Check('queryflow returns cloned metadata',
        Metadata <> nil,
        'metadata is nil');
      if Metadata <> nil then
      begin
        Metadata.Strings['description'] := 'mutated';
        Check('queryflow clone does not mutate source index',
          Index.Objects['packages'].Objects['jsonlib'].Get('description', '') = 'JSON parsing library',
          'source description changed');
      end;
    finally
      Metadata.Free;
    end;
  finally
    Index.Free;
  end;
end;

procedure TestGetPackageVersionsCoreReturnsCopiedList;
var
  Index: TJSONObject;
  Versions: TStringList;
begin
  Index := BuildSampleIndex;
  try
    Versions := GetPackageVersionsCore(Index, 'jsonlib');
    try
      Check('queryflow copies package versions into list',
        (Versions.Count = 2) and (Versions[0] = '1.0.0') and (Versions[1] = '1.1.0'),
        'versions=' + Versions.CommaText);
      Versions.Add('9.9.9');
      Check('queryflow returned list is detached from source',
        Index.Objects['packages'].Objects['jsonlib'].Arrays['versions'].Count = 2,
        'source count=' + IntToStr(Index.Objects['packages'].Objects['jsonlib'].Arrays['versions'].Count));
    finally
      Versions.Free;
    end;
  finally
    Index.Free;
  end;
end;

procedure TestHasPackageVersionCoreUsesSharedQuerySurface;
var
  Index: TJSONObject;
begin
  Index := BuildSampleIndex;
  try
    Check('queryflow finds known version',
      HasPackageVersionCore(Index, 'jsonlib', '1.1.0'),
      'expected version hit');
    Check('queryflow rejects unknown version',
      not HasPackageVersionCore(Index, 'jsonlib', '9.9.9'),
      'expected version miss');
  finally
    Index.Free;
  end;
end;

procedure TestGetPackageArchiveCoreReturnsEmptyWhenMissing;
var
  Index: TJSONObject;
  TempRoot: string;
  ArchivePath: string;
  ArchiveFile: TextFile;
begin
  Index := BuildSampleIndex;
  TempRoot := CreateUniqueTempDir('test_package_registry_queryflow_archive');
  try
    Check('queryflow returns empty archive path when file is missing',
      GetPackageArchiveCore(TempRoot, Index, 'jsonlib', '1.1.0') = '',
      'expected empty archive path');

    ForceDirectories(TempRoot + PathDelim + 'packages' + PathDelim + 'jsonlib' + PathDelim + '1.1.0');
    ArchivePath := TempRoot + PathDelim + 'packages' + PathDelim + 'jsonlib' + PathDelim + '1.1.0'
      + PathDelim + 'jsonlib-1.1.0.tar.gz';
    AssignFile(ArchiveFile, ArchivePath);
    Rewrite(ArchiveFile);
    Write(ArchiveFile, 'archive');
    CloseFile(ArchiveFile);

    Check('queryflow returns archive path when file exists',
      GetPackageArchiveCore(TempRoot, Index, 'jsonlib', '1.1.0') = ArchivePath,
      'path=' + GetPackageArchiveCore(TempRoot, Index, 'jsonlib', '1.1.0'));
  finally
    CleanupTempDir(TempRoot);
    Index.Free;
  end;
end;

procedure TestSearchPackagesCoreIsCaseInsensitive;
var
  Index: TJSONObject;
  Results: TStringList;
begin
  Index := BuildSampleIndex;
  try
    Results := SearchPackagesCore(Index, 'json');
    try
      Check('queryflow search matches package name',
        (Results.Count = 1) and (Results[0] = 'jsonlib'),
        'results=' + Results.CommaText);
    finally
      Results.Free;
    end;

    Results := SearchPackagesCore(Index, 'UTILITIES');
    try
      Check('queryflow search matches description case-insensitively',
        (Results.Count = 1) and (Results[0] = 'xmllib'),
        'results=' + Results.CommaText);
    finally
      Results.Free;
    end;
  finally
    Index.Free;
  end;
end;

begin
  TestGetPackageMetadataCoreReturnsClone;
  TestGetPackageVersionsCoreReturnsCopiedList;
  TestHasPackageVersionCoreUsesSharedQuerySurface;
  TestGetPackageArchiveCoreReturnsEmptyWhenMissing;
  TestSearchPackagesCoreIsCaseInsensitive;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
