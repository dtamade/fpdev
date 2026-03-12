program test_package_listview;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.package.types,
  fpdev.package.listview;

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

procedure TestBuildPackageListLinesInstalledOutput;
var
  Packages: TPackageArray;
  Lines: TStringArray;
begin
  SetLength(Packages, 1);
  Packages[0].Name := 'alpha';
  Packages[0].Version := '1.2.3';
  Packages[0].Description := 'alpha package';

  Lines := BuildPackageListLinesCore(
    Packages,
    False,
    'Installed packages:',
    'Available packages:',
    'No packages installed',
    'No packages available in index'
  );

  AssertEquals('Installed packages:', Lines[0], 'installed header is rendered');
  AssertEquals('  alpha             1.2.3       alpha package', Lines[1], 'installed row is formatted');
end;

procedure TestBuildPackageListLinesAvailableEmptyOutput;
var
  Packages: TPackageArray;
  Lines: TStringArray;
begin
  Packages := nil;
  Lines := BuildPackageListLinesCore(
    Packages,
    True,
    'Installed packages:',
    'Available packages:',
    'No packages installed',
    'No packages available in index'
  );

  AssertEquals('Available packages:', Lines[0], 'available header is rendered');
  AssertEquals('  No packages available in index', Lines[1], 'available empty state is rendered');
end;

begin
  TestBuildPackageListLinesInstalledOutput;
  TestBuildPackageListLinesAvailableEmptyOutput;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
