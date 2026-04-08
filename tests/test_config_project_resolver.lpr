program test_config_project_resolver;

{$mode objfpc}{$H+}

uses
  SysUtils,
  test_temp_paths,
  fpdev.config.project,
  fpdev.utils;

var
  Passed: Integer = 0;
  Failed: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(Passed);
    WriteLn('[PASS] ', AMessage);
  end
  else
  begin
    Inc(Failed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

procedure CheckEquals(const AExpected, AActual, AMessage: string);
begin
  Check(AExpected = AActual,
    AMessage + ' (expected "' + AExpected + '", got "' + AActual + '")');
end;

procedure CheckSource(AExpected, AActual: TConfigSource; const AMessage: string);
begin
  Check(AExpected = AActual,
    AMessage + ' (expected ' + ConfigSourceToString(AExpected) +
    ', got ' + ConfigSourceToString(AActual) + ')');
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

procedure TestEnvironmentOverridesProjectAndGlobalDefaults;
var
  TempRoot: string;
  ConfigPath: string;
  SavedFPC: string;
  SavedLazarus: string;
  Resolver: TProjectConfigResolver;
  Resolved: TResolvedConfig;
begin
  TempRoot := CreateUniqueTempDir('config_project_resolver_env');
  ConfigPath := IncludeTrailingPathDelimiter(TempRoot) + 'fpdev.toml';
  SafeWriteAllText(ConfigPath,
    '[toolchain]' + LineEnding +
    'fpc = "3.2.0"' + LineEnding +
    'lazarus = "3.4"' + LineEnding);

  SavedFPC := get_env('FPDEV_FPC_VERSION');
  SavedLazarus := get_env('FPDEV_LAZARUS_VERSION');
  Resolver := TProjectConfigResolver.Create('3.1.1', '3.0');
  try
    unset_env('FPDEV_FPC_VERSION');
    unset_env('FPDEV_LAZARUS_VERSION');

    Resolved := Resolver.ResolveConfig(TempRoot);
    CheckEquals('3.2.0', Resolved.FPCVersion,
      'project config sets fpc version before env override');
    CheckSource(csProject, Resolved.FPCSource,
      'project config owns fpc source before env override');
    CheckEquals('3.4', Resolved.LazarusVersion,
      'project config sets lazarus version before env override');
    CheckSource(csProject, Resolved.LazarusSource,
      'project config owns lazarus source before env override');

    Check(set_env('FPDEV_FPC_VERSION', '9.9.9'),
      'set_env should expose FPDEV_FPC_VERSION to resolver');
    Check(set_env('FPDEV_LAZARUS_VERSION', '8.8.8'),
      'set_env should expose FPDEV_LAZARUS_VERSION to resolver');

    Resolved := Resolver.ResolveConfig(TempRoot);
    CheckEquals('9.9.9', Resolved.FPCVersion,
      'env fpc override beats project/global/default in same process');
    CheckSource(csEnvironment, Resolved.FPCSource,
      'env fpc override reports environment source');
    CheckEquals('FPDEV_FPC_VERSION', Resolved.FPCSourceFile,
      'env fpc override records environment source file');

    CheckEquals('8.8.8', Resolved.LazarusVersion,
      'env lazarus override beats project/global/default in same process');
    CheckSource(csEnvironment, Resolved.LazarusSource,
      'env lazarus override reports environment source');
    CheckEquals('FPDEV_LAZARUS_VERSION', Resolved.LazarusSourceFile,
      'env lazarus override records environment source file');
  finally
    RestoreEnv('FPDEV_FPC_VERSION', SavedFPC);
    RestoreEnv('FPDEV_LAZARUS_VERSION', SavedLazarus);
    Resolver.Free;
    CleanupTempDir(TempRoot);
  end;
end;

begin
  WriteLn('=== Config Project Resolver Tests ===');
  TestEnvironmentOverridesProjectAndGlobalDefaults;
  WriteLn('Passed: ', Passed);
  WriteLn('Failed: ', Failed);
  if Failed > 0 then
    Halt(1);
end.
