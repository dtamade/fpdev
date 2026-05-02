program test_version_registry_loadflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.constants,
  fpdev.version.registry.loadflow,
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

procedure TestLoadVersionRegistryDataFromJSONCoreParsesSections;
var
  TempRoot: string;
  JSONPath: string;
  Data: TVersionRegistryLoadData;
  JSONLines: TStringList;
begin
  TempRoot := CreateUniqueTempDir('test_version_registry_loadflow_json');
  InitVersionRegistryLoadData(Data);
  try
    JSONPath := TempRoot + PathDelim + 'versions.json';
    JSONLines := TStringList.Create;
    try
      JSONLines.Add('{');
      JSONLines.Add('  "schema_version": "2.0",');
      JSONLines.Add('  "updated_at": "2026-05-02T10:00:00Z",');
      JSONLines.Add('  "fpc": {');
      JSONLines.Add('    "default_version": "3.3.1",');
      JSONLines.Add('    "repository": "https://example.invalid/fpc.git",');
      JSONLines.Add('    "releases": [');
      JSONLines.Add('      {');
      JSONLines.Add('        "version": "3.3.1",');
      JSONLines.Add('        "release_date": "rolling",');
      JSONLines.Add('        "git_tag": "main",');
      JSONLines.Add('        "branch": "main",');
      JSONLines.Add('        "channel": "development",');
      JSONLines.Add('        "lts": false');
      JSONLines.Add('      }');
      JSONLines.Add('    ]');
      JSONLines.Add('  },');
      JSONLines.Add('  "lazarus": {');
      JSONLines.Add('    "default_version": "main",');
      JSONLines.Add('    "repository": "https://example.invalid/lazarus.git",');
      JSONLines.Add('    "releases": [');
      JSONLines.Add('      {');
      JSONLines.Add('        "version": "main",');
      JSONLines.Add('        "release_date": "rolling",');
      JSONLines.Add('        "git_tag": "main",');
      JSONLines.Add('        "branch": "main",');
      JSONLines.Add('        "channel": "development",');
      JSONLines.Add('        "fpc_compatible": ["3.3.1", "main"]');
      JSONLines.Add('      }');
      JSONLines.Add('    ]');
      JSONLines.Add('  },');
      JSONLines.Add('  "bootstrap": {');
      JSONLines.Add('    "version_map": {');
      JSONLines.Add('      "main": "3.2.2"');
      JSONLines.Add('    },');
      JSONLines.Add('    "fallback_chain": ["3.2.2", "3.2.0"]');
      JSONLines.Add('  }');
      JSONLines.Add('}');
      JSONLines.SaveToFile(JSONPath);
    finally
      JSONLines.Free;
    end;

    Check('loadflow parses json file',
      TryLoadVersionRegistryDataFromJSONCore(JSONPath, Data),
      'expected json parse success');
    Check('loadflow preserves schema version',
      Data.SchemaVersion = '2.0',
      'schema=' + Data.SchemaVersion);
    Check('loadflow preserves updated_at',
      Data.UpdatedAt = '2026-05-02T10:00:00Z',
      'updated_at=' + Data.UpdatedAt);
    Check('loadflow preserves fpc default version',
      Data.FPCDefaultVersion = '3.3.1',
      'default=' + Data.FPCDefaultVersion);
    Check('loadflow preserves fpc repository',
      Data.FPCRepository = 'https://example.invalid/fpc.git',
      'repository=' + Data.FPCRepository);
    Check('loadflow parses fpc releases',
      (Length(Data.FPCReleases) = 1) and (Data.FPCReleases[0].Version = '3.3.1'),
      'count=' + IntToStr(Length(Data.FPCReleases)));
    Check('loadflow parses lazarus compatibility',
      (Length(Data.LazarusReleases) = 1) and
      (Length(Data.LazarusReleases[0].FPCCompatible) = 2) and
      (Data.LazarusReleases[0].FPCCompatible[0] = '3.3.1'),
      'unexpected lazarus compatibility data');
    Check('loadflow parses bootstrap map',
      Data.BootstrapMap.Values['main'] = '3.2.2',
      'map=' + Data.BootstrapMap.Text);
    Check('loadflow parses bootstrap fallback chain',
      (Data.BootstrapFallbackChain.Count = 2) and
      (Data.BootstrapFallbackChain[1] = '3.2.0'),
      'chain=' + Data.BootstrapFallbackChain.CommaText);
  finally
    DoneVersionRegistryLoadData(Data);
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestLoadDefaultVersionRegistryDataCoreProvidesEmbeddedDefaults;
var
  Data: TVersionRegistryLoadData;
begin
  InitVersionRegistryLoadData(Data);
  try
    LoadDefaultVersionRegistryDataCore(Data);

    Check('loadflow defaults set embedded updated_at',
      Data.UpdatedAt = 'embedded',
      'updated_at=' + Data.UpdatedAt);
    Check('loadflow defaults keep official fpc repository',
      Data.FPCRepository = FPC_OFFICIAL_REPO,
      'repository=' + Data.FPCRepository);
    Check('loadflow defaults include 3.2.2 release',
      Length(Data.FPCReleases) >= 1,
      'count=' + IntToStr(Length(Data.FPCReleases)));
    Check('loadflow defaults include bootstrap fallback chain',
      Data.BootstrapFallbackChain.Count >= 4,
      'count=' + IntToStr(Data.BootstrapFallbackChain.Count));
  finally
    DoneVersionRegistryLoadData(Data);
  end;
end;

procedure TestTryLoadVersionRegistryDataCoreUsesFirstExistingSearchPath;
var
  TempRoot: string;
  RequestedPath: string;
  ExeDir: string;
  DataRoot: string;
  ResolvedPath: string;
  Data: TVersionRegistryLoadData;
  JSONLines: TStringList;
begin
  TempRoot := CreateUniqueTempDir('test_version_registry_loadflow_search_paths');
  InitVersionRegistryLoadData(Data);
  try
    RequestedPath := TempRoot + PathDelim + 'requested' + PathDelim + 'versions.json';
    ExeDir := TempRoot + PathDelim + 'bin';
    DataRoot := TempRoot + PathDelim + 'data-root';
    ForceDirectories(ExtractFileDir(RequestedPath));
    ForceDirectories(ExeDir);
    ForceDirectories(DataRoot);

    JSONLines := TStringList.Create;
    try
      JSONLines.Add('{');
      JSONLines.Add('  "schema_version": "1.1",');
      JSONLines.Add('  "updated_at": "search-path-hit",');
      JSONLines.Add('  "fpc": {');
      JSONLines.Add('    "default_version": "3.2.0",');
      JSONLines.Add('    "releases": []');
      JSONLines.Add('  }');
      JSONLines.Add('}');
      JSONLines.SaveToFile(RequestedPath);
    finally
      JSONLines.Free;
    end;

    Check('loadflow resolves first existing search path',
      TryLoadVersionRegistryDataCore(RequestedPath, ExeDir, DataRoot, ResolvedPath, Data),
      'expected search path load success');
    Check('loadflow reports resolved requested path',
      ResolvedPath = RequestedPath,
      'resolved=' + ResolvedPath);
    Check('loadflow preserves requested path payload',
      Data.UpdatedAt = 'search-path-hit',
      'updated_at=' + Data.UpdatedAt);
  finally
    DoneVersionRegistryLoadData(Data);
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestLoadVersionRegistryDataFromJSONCoreParsesSections;
  TestLoadDefaultVersionRegistryDataCoreProvidesEmbeddedDefaults;
  TestTryLoadVersionRegistryDataCoreUsesFirstExistingSearchPath;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
