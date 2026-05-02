program test_lazarus_config_envoptionsflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.lazarus.config.envoptionsflow,
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

procedure WriteTextFile(const APath: string; const ALines: array of string);
var
  Lines: TStringList;
  Index: Integer;
begin
  Lines := TStringList.Create;
  try
    for Index := 0 to High(ALines) do
      Lines.Add(ALines[Index]);
    ForceDirectories(ExtractFileDir(APath));
    Lines.SaveToFile(APath);
  finally
    Lines.Free;
  end;
end;

procedure TestSetEnvOptionCreatesNewConfig;
var
  TempRoot: string;
  EnvOptionsPath: string;
begin
  TempRoot := CreateUniqueTempDir('test_lazarus_config_envoptionsflow_create');
  try
    EnvOptionsPath := IncludeTrailingPathDelimiter(TempRoot) + 'environmentoptions.xml';
    Check('envoptionsflow creates new config file',
      SetLazarusEnvOptionValueCore(EnvOptionsPath, 'CompilerFilename', '/usr/bin/fpc'),
      'set should succeed');
    Check('envoptionsflow writes environmentoptions.xml',
      FileExists(EnvOptionsPath),
      'missing ' + EnvOptionsPath);
    Check('envoptionsflow reads created compiler value',
      GetLazarusEnvOptionValueCore(EnvOptionsPath, 'CompilerFilename') = '/usr/bin/fpc',
      'compiler=' + GetLazarusEnvOptionValueCore(EnvOptionsPath, 'CompilerFilename'));
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestSetEnvOptionUpdatesExistingNode;
var
  TempRoot: string;
  EnvOptionsPath: string;
begin
  TempRoot := CreateUniqueTempDir('test_lazarus_config_envoptionsflow_update');
  try
    EnvOptionsPath := IncludeTrailingPathDelimiter(TempRoot) + 'environmentoptions.xml';
    Check('envoptionsflow writes initial target cpu',
      SetLazarusEnvOptionValueCore(EnvOptionsPath, 'TargetCPU', 'x86_64'),
      'initial set should succeed');
    Check('envoptionsflow updates target cpu',
      SetLazarusEnvOptionValueCore(EnvOptionsPath, 'TargetCPU', 'aarch64'),
      'update should succeed');
    Check('envoptionsflow returns updated target cpu',
      GetLazarusEnvOptionValueCore(EnvOptionsPath, 'TargetCPU') = 'aarch64',
      'targetcpu=' + GetLazarusEnvOptionValueCore(EnvOptionsPath, 'TargetCPU'));
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestGetEnvOptionReturnsEmptyWhenFileMissing;
var
  TempRoot: string;
  EnvOptionsPath: string;
begin
  TempRoot := CreateUniqueTempDir('test_lazarus_config_envoptionsflow_missingfile');
  try
    EnvOptionsPath := IncludeTrailingPathDelimiter(TempRoot) + 'environmentoptions.xml';
    Check('envoptionsflow returns empty when file missing',
      GetLazarusEnvOptionValueCore(EnvOptionsPath, 'MakeFilename') = '',
      'expected empty string');
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestGetEnvOptionReturnsEmptyWhenNodeMissing;
var
  TempRoot: string;
  EnvOptionsPath: string;
begin
  TempRoot := CreateUniqueTempDir('test_lazarus_config_envoptionsflow_missingnode');
  try
    EnvOptionsPath := IncludeTrailingPathDelimiter(TempRoot) + 'environmentoptions.xml';
    WriteTextFile(EnvOptionsPath, [
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<CONFIG>',
      '  <EnvironmentOptions>',
      '    <CompilerFilename Value="/usr/bin/fpc"/>',
      '  </EnvironmentOptions>',
      '</CONFIG>'
    ]);
    Check('envoptionsflow returns empty when node missing',
      GetLazarusEnvOptionValueCore(EnvOptionsPath, 'TargetOS') = '',
      'expected empty string');
  finally
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestSetEnvOptionCreatesNewConfig;
  TestSetEnvOptionUpdatesExistingNode;
  TestGetEnvOptionReturnsEmptyWhenFileMissing;
  TestGetEnvOptionReturnsEmptyWhenNodeMissing;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
