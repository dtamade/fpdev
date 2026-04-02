program test_resource_repo_query;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, test_temp_paths,
  fpdev.resource.repo.types,
  fpdev.resource.repo.package,
  fpdev.resource.repo.search;

type
  TStubRepoInfoLoader = class
    function LoadInfo(const AName, AVersion: string; out AInfo: TRepoPackageInfo): Boolean;
  end;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TempDir: string;

function TStubRepoInfoLoader.LoadInfo(const AName, AVersion: string; out AInfo: TRepoPackageInfo): Boolean;
begin
  if AVersion = '' then;
  AInfo := EmptyRepoPackageInfo;
  if AName = 'jsonlib' then
  begin
    AInfo.Name := 'jsonlib';
    AInfo.Description := 'JSON parsing library';
    Exit(True);
  end;
  if AName = 'httplib' then
  begin
    AInfo.Name := 'httplib';
    AInfo.Description := 'HTTP client';
    Exit(True);
  end;
  Result := False;
end;

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

procedure CreateTextFile(const APath, AContent: string);
var
  SL: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  SL := TStringList.Create;
  try
    SL.Text := AContent;
    SL.SaveToFile(APath);
  finally
    SL.Free;
  end;
end;

procedure TestLoadPackageInfoFromFile;
var
  MetaPath: string;
  Info: TRepoPackageInfo;
begin
  MetaPath := TempDir + PathDelim + 'packages' + PathDelim + 'jsonlib' + PathDelim + 'jsonlib.json';
  CreateTextFile(MetaPath,
    '{' +
    '"name":"jsonlib",' +
    '"version":"1.0.0",' +
    '"description":"JSON parsing library",' +
    '"category":"utils",' +
    '"archive":"jsonlib-1.0.0.zip",' +
    '"sha256":"abc123",' +
    '"fpc_min":"3.2.0",' +
    '"dependencies":["fpjson","classes"]' +
    '}');

  Check(ResourceRepoLoadPackageInfoFromFile(MetaPath, 'jsonlib', Info), 'LoadPackageInfo: parse succeeds');
  Check(Info.Name = 'jsonlib', 'LoadPackageInfo: name parsed');
  Check(Length(Info.Dependencies) = 2, 'LoadPackageInfo: dependencies parsed');
end;

procedure TestListPackagesCore;
var
  Items: SysUtils.TStringArray;
begin
  ForceDirectories(TempDir + PathDelim + 'packages' + PathDelim + 'core' + PathDelim + 'corelib');
  ForceDirectories(TempDir + PathDelim + 'packages' + PathDelim + 'utils' + PathDelim + 'utillib');

  Items := ResourceRepoListPackagesCore(TempDir, 'core');
  Check((Length(Items) = 1) and (Items[0] = 'corelib'), 'ListPackagesCore: category returns package names');

  Items := ResourceRepoListPackagesCore(TempDir, '');
  Check(Length(Items) >= 2, 'ListPackagesCore: root returns directory entries');
  Check((Pos('core/', #10 + String.Join(#10, Items)) > 0), 'ListPackagesCore: root keeps core category suffix');
  Check((Pos('utils/', #10 + String.Join(#10, Items)) > 0), 'ListPackagesCore: root keeps utils category suffix');
end;

procedure TestSearchPackagesCore;
var
  Loader: TStubRepoInfoLoader;
  AllPackages: SysUtils.TStringArray;
  Results: SysUtils.TStringArray;
begin
  Loader := TStubRepoInfoLoader.Create;
  try
    SetLength(AllPackages, 2);
    AllPackages[0] := 'jsonlib';
    AllPackages[1] := 'httplib';

    Results := ResourceRepoSearchPackagesCore(AllPackages, 'json', @Loader.LoadInfo);
    Check((Length(Results) = 1) and (Results[0] = 'jsonlib'), 'SearchPackagesCore: filters by description');
  finally
    Loader.Free;
  end;
end;

begin
  Randomize;
  TempDir := CreateUniqueTempDir('test_repo_query');
  try
    Check(PathUsesSystemTempRoot(TempDir), 'TempDir lives under system temp');
    TestLoadPackageInfoFromFile;
    TestListPackagesCore;
    TestSearchPackagesCore;
  finally
    CleanupTempDir(TempDir);
  end;

  WriteLn;
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
