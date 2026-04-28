program test_cross_searchpaths;

{$mode objfpc}{$H+}

uses
  SysUtils,
  test_temp_paths,
  fpdev.config.interfaces,
  fpdev.cross.searchpaths,
  fpdev.utils;

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

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

function FirstOrNone(const AValues: TStringArray): string;
begin
  if Length(AValues) > 0 then
    Result := AValues[0]
  else
    Result := '<none>';
end;

function MakeTarget(const ACPU, AOS: string): TCrossTarget;
begin
  Result := Default(TCrossTarget);
  Result.Enabled := True;
  Result.CPU := ACPU;
  Result.OS := AOS;
end;

procedure TestGetCrossPrefixCandidatesCoreUsesConfiguredPrefixOnly;
var
  Target: TCrossTarget;
  Prefixes: TStringArray;
begin
  Target := MakeTarget('arm', 'linux');
  Target.BinutilsPrefix := 'custom-prefix-';

  Prefixes := GetCrossPrefixCandidatesCore(Target);

  Check('configured prefix count', Length(Prefixes) = 1,
    'count=' + IntToStr(Length(Prefixes)));
  if Length(Prefixes) > 0 then
    Check('configured prefix value', Prefixes[0] = 'custom-prefix-',
      'value=' + Prefixes[0]);
end;

procedure TestGetCrossPrefixCandidatesCoreARMOrder;
var
  Prefixes: TStringArray;
begin
  Prefixes := GetCrossPrefixCandidatesCore(MakeTarget('arm', 'linux'));

  Check('arm prefix count', Length(Prefixes) = 4,
    'count=' + IntToStr(Length(Prefixes)));
  if Length(Prefixes) >= 2 then
  begin
    Check('arm first prefix', Prefixes[0] = 'arm-linux-gnueabihf-',
      'value=' + Prefixes[0]);
    Check('arm second prefix', Prefixes[1] = 'arm-linux-gnueabi-',
      'value=' + Prefixes[1]);
  end;
end;

procedure TestGetCrossPrefixCandidatesCoreAArch64Linux;
var
  Prefixes: TStringArray;
begin
  Prefixes := GetCrossPrefixCandidatesCore(MakeTarget('aarch64', 'linux'));

  Check('aarch64 first prefix', (Length(Prefixes) >= 1) and
    (Prefixes[0] = 'aarch64-linux-gnu-'),
    'value=' + FirstOrNone(Prefixes));
end;

procedure TestGetCrossPrefixCandidatesCoreWin64;
var
  Prefixes: TStringArray;
begin
  Prefixes := GetCrossPrefixCandidatesCore(MakeTarget('x86_64', 'win64'));

  Check('win64 mingw prefix', (Length(Prefixes) = 1) and
    (Prefixes[0] = 'x86_64-w64-mingw32-'),
    'value=' + FirstOrNone(Prefixes));
end;

procedure TestBuildCrossLibraryCandidatesCoreConfiguredPathFirst;
var
  Target: TCrossTarget;
  Prefixes: TStringArray;
  TempDir: string;
  Libs: TStringArray;
begin
  TempDir := CreateUniqueTempDir('fpdev-cross-searchpaths-libs');
  try
    Target := MakeTarget('arm', 'linux');
    Target.LibrariesPath := TempDir;
    Prefixes := GetCrossPrefixCandidatesCore(Target);
    Libs := BuildCrossLibraryCandidatesCore(Target, Prefixes);

    Check('configured libs first count', Length(Libs) >= 1,
      'count=' + IntToStr(Length(Libs)));
    if Length(Libs) > 0 then
      Check('configured libs first value', Libs[0] = TempDir,
        'value=' + Libs[0]);
  finally
    CleanupTempDir(TempDir);
  end;
end;

procedure TestBuildCrossLibraryCandidatesCoreDedupesConfiguredAndManagedPath;
var
  Target: TCrossTarget;
  Prefixes: TStringArray;
  TempRoot: string;
  SharedLibDir: string;
  SavedDataRoot: string;
  Libs: TStringArray;
  Index: Integer;
  SeenSharedCount: Integer;
begin
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  TempRoot := CreateUniqueTempDir('fpdev-cross-searchpaths-dedup');
  SharedLibDir := IncludeTrailingPathDelimiter(TempRoot) + 'cross' + PathDelim +
    'arm-linux' + PathDelim + 'lib';
  ForceDirectories(SharedLibDir);
  try
    set_env('FPDEV_DATA_ROOT', TempRoot);
    Target := MakeTarget('arm', 'linux');
    Target.LibrariesPath := SharedLibDir;
    Prefixes := GetCrossPrefixCandidatesCore(Target);
    Libs := BuildCrossLibraryCandidatesCore(Target, Prefixes);

    SeenSharedCount := 0;
    for Index := 0 to High(Libs) do
      if Libs[Index] = SharedLibDir then
        Inc(SeenSharedCount);

    Check('dedupe keeps shared dir first', Length(Libs) >= 1,
      'count=' + IntToStr(Length(Libs)));
    if Length(Libs) > 0 then
      Check('dedupe keeps configured/managed dir value first', Libs[0] = SharedLibDir,
        'value=' + Libs[0]);
    Check('dedupe keeps shared dir once', SeenSharedCount = 1,
      'count=' + IntToStr(SeenSharedCount));
  finally
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestGetCrossPrefixCandidatesCoreUsesConfiguredPrefixOnly;
  TestGetCrossPrefixCandidatesCoreARMOrder;
  TestGetCrossPrefixCandidatesCoreAArch64Linux;
  TestGetCrossPrefixCandidatesCoreWin64;
  TestBuildCrossLibraryCandidatesCoreConfiguredPathFirst;
  TestBuildCrossLibraryCandidatesCoreDedupesConfiguredAndManagedPath;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
