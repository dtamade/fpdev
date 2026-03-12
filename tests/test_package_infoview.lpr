program test_package_infoview;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.package.types,
  fpdev.package.infoview;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

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

procedure TestBuildPackageInfoLinesForInstalledPackage;
var
  Info: TPackageInfo;
  Lines: TStringArray;
begin
  Initialize(Info);
  Info.Name := 'alpha';
  Info.Version := '1.2.3';
  Info.Description := 'alpha package';
  Info.Installed := True;
  Info.InstallPath := '/tmp/fpdev/alpha';

  Lines := BuildPackageInfoLinesCore(
    Info,
    'Package: %s',
    'Version: %s',
    'Description: %s',
    'Install path: %s'
  );

  AssertEquals('Package: alpha', Lines[0], 'name line is rendered');
  AssertEquals('Version: 1.2.3', Lines[1], 'version line is rendered');
  AssertEquals('Description: alpha package', Lines[2], 'description line is rendered');
  AssertEquals('Install path: /tmp/fpdev/alpha', Lines[3], 'install path line is rendered when installed');
end;

procedure TestBuildPackageInfoLinesForNonInstalledPackage;
var
  Info: TPackageInfo;
  Lines: TStringArray;
begin
  Initialize(Info);
  Info.Name := 'beta';
  Info.Version := '2.0.0';
  Info.Description := 'beta package';
  Info.Installed := False;

  Lines := BuildPackageInfoLinesCore(
    Info,
    'Package: %s',
    'Version: %s',
    'Description: %s',
    'Install path: %s'
  );

  AssertTrue(Length(Lines) = 3, 'install path is omitted when package is not installed');
end;

begin
  TestBuildPackageInfoLinesForInstalledPackage;
  TestBuildPackageInfoLinesForNonInstalledPackage;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
