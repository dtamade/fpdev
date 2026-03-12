program test_package_fetch;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.package.types,
  fpdev.toolchain.fetcher,
  fpdev.package.fetch;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  DownloadCalled: Boolean = False;
  DownloadDest: string = '';
  DownloadHash: string = '';
  DownloadTimeout: Integer = 0;
  DownloadURLCount: Integer = 0;

function StubDownloadRunner(
  const AURLs: array of string;
  const DestFile: string;
  const Opt: TFetchOptions;
  out AErr: string
): Boolean;
begin
  DownloadCalled := True;
  DownloadDest := DestFile;
  DownloadHash := Opt.Hash;
  DownloadTimeout := Opt.TimeoutMS;
  DownloadURLCount := Length(AURLs);
  AErr := '';
  Result := True;
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

procedure AssertEqualsInt(AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual,
    AMessage + ' (expected: ' + IntToStr(AExpected) + ', got: ' + IntToStr(AActual) + ')');
end;

procedure ResetDownloadCapture;
begin
  DownloadCalled := False;
  DownloadDest := '';
  DownloadHash := '';
  DownloadTimeout := 0;
  DownloadURLCount := 0;
end;


procedure TestBuildPackageDownloadPlanSelectsHighestVersion;
var
  Packages: TPackageArray;
  Plan: TPackageDownloadPlan;
begin
  SetLength(Packages, 2);

  Packages[0].Name := 'alpha';
  Packages[0].Version := '1.0.0';
  Packages[0].Sha256 := 'sha-old';
  SetLength(Packages[0].URLs, 1);
  Packages[0].URLs[0] := 'https://example.com/alpha-1.0.0.zip';

  Packages[1].Name := 'alpha';
  Packages[1].Version := '1.2.0';
  Packages[1].Sha256 := 'sha-new';
  SetLength(Packages[1].URLs, 2);
  Packages[1].URLs[0] := 'https://example.com/alpha-1.2.0.zip';
  Packages[1].URLs[1] := 'https://mirror.example.com/alpha-1.2.0.zip';

  AssertTrue(
    BuildPackageDownloadPlanCore('alpha', '', '/tmp/fpdev-cache', Packages, Plan),
    'download plan is built for highest available version'
  );
  AssertEquals('1.2.0', Plan.PackageInfo.Version, 'plan selects highest version');
  AssertEquals('/tmp/fpdev-cache/packages/alpha-1.2.0.zip', Plan.ZipPath, 'plan builds cache path');
  AssertEquals('sha-new', Plan.FetchOptions.Hash, 'plan forwards hash');
  AssertEqualsInt(2, Length(Plan.URLs), 'plan forwards URLs');
end;

procedure TestBuildPackageDownloadPlanSkipsMissingPackage;
var
  Packages: TPackageArray;
  Plan: TPackageDownloadPlan;
begin
  SetLength(Packages, 1);
  Packages[0].Name := 'alpha';
  Packages[0].Version := '1.0.0';
  SetLength(Packages[0].URLs, 1);
  Packages[0].URLs[0] := 'https://example.com/alpha.zip';

  AssertTrue(
    not BuildPackageDownloadPlanCore('missing', '', '/tmp/fpdev-cache', Packages, Plan),
    'missing package does not build a download plan'
  );
end;

procedure TestDownloadPackageCoreSelectsHighestVersion;
var
  Packages: TPackageArray;
begin
  ResetDownloadCapture;
  SetLength(Packages, 3);

  Packages[0].Name := 'alpha';
  Packages[0].Version := '1.0.0';
  Packages[0].Sha256 := 'sha-old';
  SetLength(Packages[0].URLs, 1);
  Packages[0].URLs[0] := 'https://example.com/alpha-1.0.0.zip';

  Packages[1].Name := 'alpha';
  Packages[1].Version := '1.2.0';
  Packages[1].Sha256 := 'sha-new';
  SetLength(Packages[1].URLs, 2);
  Packages[1].URLs[0] := 'https://example.com/alpha-1.2.0.zip';
  Packages[1].URLs[1] := 'https://mirror.example.com/alpha-1.2.0.zip';

  Packages[2].Name := 'beta';
  Packages[2].Version := '2.0.0';
  SetLength(Packages[2].URLs, 1);
  Packages[2].URLs[0] := 'https://example.com/beta-2.0.0.zip';

  AssertTrue(
    DownloadPackageCore('alpha', '', '/tmp/fpdev-cache', Packages, @StubDownloadRunner),
    'download succeeds for highest available version'
  );
  AssertTrue(DownloadCalled, 'download callback is invoked');
  AssertEquals('/tmp/fpdev-cache/packages/alpha-1.2.0.zip', DownloadDest, 'cache path uses selected highest version');
  AssertEquals('sha-new', DownloadHash, 'selected package hash is forwarded');
  AssertEqualsInt(DEFAULT_DOWNLOAD_TIMEOUT_MS, DownloadTimeout, 'default timeout is forwarded');
  AssertEqualsInt(2, DownloadURLCount, 'all package URLs are forwarded');
end;

procedure TestDownloadPackageCoreSkipsMissingPackage;
var
  Packages: TPackageArray;
begin
  ResetDownloadCapture;
  SetLength(Packages, 1);
  Packages[0].Name := 'alpha';
  Packages[0].Version := '1.0.0';
  SetLength(Packages[0].URLs, 1);
  Packages[0].URLs[0] := 'https://example.com/alpha.zip';

  AssertTrue(
    not DownloadPackageCore('missing', '', '/tmp/fpdev-cache', Packages, @StubDownloadRunner),
    'missing package returns false'
  );
  AssertTrue(not DownloadCalled, 'download callback is not invoked for missing package');
end;

procedure TestDownloadPackageCoreSkipsEntriesWithoutURLs;
var
  Packages: TPackageArray;
begin
  ResetDownloadCapture;
  SetLength(Packages, 1);
  Packages[0].Name := 'alpha';
  Packages[0].Version := '1.0.0';
  SetLength(Packages[0].URLs, 0);

  AssertTrue(
    not DownloadPackageCore('alpha', '', '/tmp/fpdev-cache', Packages, @StubDownloadRunner),
    'package without URLs returns false'
  );
  AssertTrue(not DownloadCalled, 'download callback is not invoked without URLs');
end;

begin
  TestBuildPackageDownloadPlanSelectsHighestVersion;
  TestBuildPackageDownloadPlanSkipsMissingPackage;
  TestDownloadPackageCoreSelectsHighestVersion;
  TestDownloadPackageCoreSkipsMissingPackage;
  TestDownloadPackageCoreSkipsEntriesWithoutURLs;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
