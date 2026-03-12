program test_package_searchview;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.package.types,
  fpdev.package.searchview;

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

procedure TestBuildPackageSearchLinesMatchesNameAndDescription;
var
  Packages: TPackageArray;
  Lines: TStringArray;
begin
  SetLength(Packages, 2);
  Packages[0].Name := 'alpha';
  Packages[0].Version := '1.0.0';
  Packages[0].Description := 'network helper';
  Packages[0].Installed := True;

  Packages[1].Name := 'beta';
  Packages[1].Version := '2.0.0';
  Packages[1].Description := 'json tools';
  Packages[1].Installed := False;

  Lines := BuildPackageSearchLinesCore(
    Packages,
    'JSON',
    'Installed',
    'Available',
    'No packages found'
  );

  AssertEquals('beta              2.0.0       Available   json tools', Lines[0], 'description match is rendered case-insensitively');

  Lines := BuildPackageSearchLinesCore(
    Packages,
    'alp',
    'Installed',
    'Available',
    'No packages found'
  );
  AssertEquals('alpha             1.0.0       Installed   network helper', Lines[0], 'name match renders installed status');
end;

procedure TestBuildPackageSearchLinesNoResults;
var
  Packages: TPackageArray;
  Lines: TStringArray;
begin
  SetLength(Packages, 1);
  Packages[0].Name := 'alpha';
  Packages[0].Version := '1.0.0';
  Packages[0].Description := 'network helper';

  Lines := BuildPackageSearchLinesCore(
    Packages,
    'missing',
    'Installed',
    'Available',
    'No packages found'
  );

  AssertEquals('No packages found: missing', Lines[0], 'no-results line is rendered');
end;

begin
  TestBuildPackageSearchLinesMatchesNameAndDescription;
  TestBuildPackageSearchLinesNoResults;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
