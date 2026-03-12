program test_package_available_query;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.package.types,
  fpdev.resource.repo.types,
  fpdev.package.query.available;

type
  TStubAvailableQuery = class
  private
    FFallbackUsed: Boolean;
  public
    function ListRepoPackages(const ACategory: string): SysUtils.TStringArray;
    function GetRepoPackageInfo(const AName, AVersion: string; out AInfo: TRepoPackageInfo): Boolean;
    function IsInstalled(const APackageName: string): Boolean;
    function ParseLocalIndex(const AIndexPath: string): TPackageArray;
    property FallbackUsed: Boolean read FFallbackUsed;
  end;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function TStubAvailableQuery.ListRepoPackages(const ACategory: string): SysUtils.TStringArray;
begin
  Initialize(Result);
  SetLength(Result, 3);
  Result[0] := 'category/';
  Result[1] := 'alpha';
  Result[2] := 'beta';
end;

function TStubAvailableQuery.GetRepoPackageInfo(const AName, AVersion: string; out AInfo: TRepoPackageInfo): Boolean;
begin
  AInfo := EmptyRepoPackageInfo;
  if AName = 'alpha' then
  begin
    AInfo.Name := 'alpha';
    AInfo.Version := '1.0.0';
    AInfo.Description := 'repo alpha';
    Exit(True);
  end;
  if AName = 'beta' then
  begin
    AInfo.Name := 'beta';
    AInfo.Version := '2.0.0';
    AInfo.Description := 'repo beta';
    Exit(True);
  end;
  Result := False;
end;

function TStubAvailableQuery.IsInstalled(const APackageName: string): Boolean;
begin
  Result := APackageName = 'beta';
end;

function TStubAvailableQuery.ParseLocalIndex(const AIndexPath: string): TPackageArray;
begin
  FFallbackUsed := True;
  Initialize(Result);
  SetLength(Result, 1);
  Result[0].Name := ExtractFileName(AIndexPath);
  Result[0].Version := '9.9.9';
  Result[0].Description := 'fallback';
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

procedure TestGetAvailablePackagesCoreUsesRepoPackages;
var
  Stub: TStubAvailableQuery;
  Packages: TPackageArray;
begin
  Stub := TStubAvailableQuery.Create;
  try
    Packages := GetAvailablePackagesCore('/tmp/fpdev-registry', '/',
      @Stub.ListRepoPackages,
      @Stub.GetRepoPackageInfo,
      @Stub.IsInstalled,
      @Stub.ParseLocalIndex);

    AssertTrue(Length(Packages) = 2, 'repo path returns only real packages');
    AssertEquals('alpha', Packages[0].Name, 'first repo package is mapped');
    AssertEquals('beta', Packages[1].Name, 'second repo package is mapped');
    AssertTrue(not Packages[0].Installed, 'alpha installed flag is false');
    AssertTrue(Packages[1].Installed, 'beta installed flag is true');
    AssertTrue(not Stub.FallbackUsed, 'fallback is not used when repo packages exist');
  finally
    Stub.Free;
  end;
end;

procedure TestGetAvailablePackagesCoreFallsBackToLocalIndex;
var
  Stub: TStubAvailableQuery;
  Packages: TPackageArray;
begin
  Stub := TStubAvailableQuery.Create;
  try
    Packages := GetAvailablePackagesCore('/tmp/fpdev-registry', '/',
      nil,
      nil,
      @Stub.IsInstalled,
      @Stub.ParseLocalIndex);
    AssertTrue(Length(Packages) = 1, 'fallback returns local index packages');
    AssertEquals('index.json', Packages[0].Name, 'fallback receives index path');
    AssertTrue(Stub.FallbackUsed, 'fallback callback is used');
  finally
    Stub.Free;
  end;
end;

begin
  TestGetAvailablePackagesCoreUsesRepoPackages;
  TestGetAvailablePackagesCoreFallsBackToLocalIndex;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
