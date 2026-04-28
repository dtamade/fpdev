program test_resource_repo_packagesurfaceflow;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.resource.repo.types,
  fpdev.resource.repo.search,
  fpdev.resource.repo.packageflow;

type
  TPackageSurfaceProbe = class
  public
    InfoCalls: Integer;
    LowLevelListCalls: Integer;
    SurfaceListCalls: Integer;
    LogCalls: Integer;
    LastLog: string;
    LastInfoLocalPath: string;
    LastInfoName: string;
    LastListLocalPath: string;
    LastListCategory: string;
    function RaisingInfo(const ALocalPath, AName, AVersion: string;
      out AInfo: TRepoPackageInfo): Boolean;
    function LoadInfo(const ALocalPath, AName, AVersion: string;
      out AInfo: TRepoPackageInfo): Boolean;
    function ListPackagesLowLevel(const ALocalPath, ACategory: string): SysUtils.TStringArray;
    function ListPackagesSurface(const ACategory: string): SysUtils.TStringArray;
    function GetPackageInfoSurface(const AName, AVersion: string;
      out AInfo: TRepoPackageInfo): Boolean;
    procedure LogFmt(const AFormat: string; const AArgs: array of const);
  end;

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

function TPackageSurfaceProbe.RaisingInfo(const ALocalPath, AName, AVersion: string;
  out AInfo: TRepoPackageInfo): Boolean;
begin
  if AVersion = '' then;
  Inc(InfoCalls);
  LastInfoLocalPath := ALocalPath;
  LastInfoName := AName;
  AInfo := EmptyRepoPackageInfo;
  Result := False;
  raise Exception.Create('package boom');
end;

function TPackageSurfaceProbe.LoadInfo(const ALocalPath, AName, AVersion: string;
  out AInfo: TRepoPackageInfo): Boolean;
begin
  if ALocalPath = '' then;
  if AVersion = '' then;
  Inc(InfoCalls);
  LastInfoName := AName;
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

function TPackageSurfaceProbe.ListPackagesLowLevel(const ALocalPath,
  ACategory: string): SysUtils.TStringArray;
begin
  Inc(LowLevelListCalls);
  LastListLocalPath := ALocalPath;
  LastListCategory := ACategory;
  Result := nil;
  SetLength(Result, 2);
  Result[0] := 'jsonlib';
  Result[1] := 'httplib';
end;

function TPackageSurfaceProbe.ListPackagesSurface(
  const ACategory: string): SysUtils.TStringArray;
begin
  Inc(SurfaceListCalls);
  LastListCategory := ACategory;
  Result := nil;
  SetLength(Result, 2);
  Result[0] := 'jsonlib';
  Result[1] := 'httplib';
end;

function TPackageSurfaceProbe.GetPackageInfoSurface(const AName, AVersion: string;
  out AInfo: TRepoPackageInfo): Boolean;
begin
  Result := LoadInfo('/tmp/repo', AName, AVersion, AInfo);
end;

procedure TPackageSurfaceProbe.LogFmt(const AFormat: string; const AArgs: array of const);
begin
  Inc(LogCalls);
  LastLog := Format(AFormat, AArgs);
end;

procedure TestPackageInfoSurfaceLogsAndReturnsFalseOnException;
var
  Probe: TPackageSurfaceProbe;
  Info: TRepoPackageInfo;
begin
  Probe := TPackageSurfaceProbe.Create;
  try
    Check('package info surface returns false on exception',
      not ExecuteResourceRepoPackageInfoSurfaceCore(
        '/tmp/repo', 'jsonlib', '', Info, @Probe.LogFmt, @Probe.RaisingInfo
      ),
      'expected false');
    Check('package info surface logs exception text',
      Pos('package boom', Probe.LastLog) > 0,
      Probe.LastLog);
    Check('package info surface clears info on exception',
      (Info.Name = '') and (Info.Description = ''),
      'info should be empty');
  finally
    Probe.Free;
  end;
end;

procedure TestPackageListSurfacePassesThroughLowLevelResults;
var
  Probe: TPackageSurfaceProbe;
  Values: SysUtils.TStringArray;
begin
  Probe := TPackageSurfaceProbe.Create;
  try
    Values := ExecuteResourceRepoPackageListSurfaceCore(
      '/tmp/repo', 'core', @Probe.ListPackagesLowLevel
    );

    Check('package list surface calls low-level list helper once',
      Probe.LowLevelListCalls = 1,
      'calls=' + IntToStr(Probe.LowLevelListCalls));
    Check('package list surface forwards local path',
      Probe.LastListLocalPath = '/tmp/repo',
      Probe.LastListLocalPath);
    Check('package list surface forwards category',
      Probe.LastListCategory = 'core',
      Probe.LastListCategory);
    Check('package list surface returns low-level results verbatim',
      (Length(Values) = 2) and (Values[0] = 'jsonlib') and (Values[1] = 'httplib'),
      'unexpected result length=' + IntToStr(Length(Values)));
  finally
    Probe.Free;
  end;
end;

procedure TestPackageSearchSurfaceFiltersByDescription;
var
  Probe: TPackageSurfaceProbe;
  Results: SysUtils.TStringArray;
begin
  Probe := TPackageSurfaceProbe.Create;
  try
    Results := ExecuteResourceRepoPackageSearchSurfaceCore(
      'json', @Probe.ListPackagesSurface, @Probe.GetPackageInfoSurface,
      @ResourceRepoSearchPackagesCore
    );

    Check('package search surface lists root packages once',
      Probe.SurfaceListCalls = 1,
      'list calls=' + IntToStr(Probe.SurfaceListCalls));
    Check('package search surface lists with empty category',
      Probe.LastListCategory = '',
      'category=' + Probe.LastListCategory);
    Check('package search surface filters by metadata description',
      (Length(Results) = 1) and (Results[0] = 'jsonlib'),
      'unexpected result length=' + IntToStr(Length(Results)));
    Check('package search surface consults package info getter',
      Probe.InfoCalls >= 1,
      'info calls=' + IntToStr(Probe.InfoCalls));
  finally
    Probe.Free;
  end;
end;

begin
  TestPackageInfoSurfaceLogsAndReturnsFalseOnException;
  TestPackageListSurfacePassesThroughLowLevelResults;
  TestPackageSearchSurfaceFiltersByDescription;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
