program test_package_index_parser;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.utils.fs,
  fpdev.package.types,
  fpdev.package.indexparser;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function BuildTempDir: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False))
    + 'fpdev_pkg_index_parser_' + IntToStr(GetTickCount64);
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

procedure TestParseIndexDeduplicatesAndFilters;
var
  TempDir: string;
  IndexPath: string;
  JsonLines: TStringList;
  Packages: TPackageArray;
begin
  TempDir := BuildTempDir;
  ForceDirectories(TempDir);
  try
    AssertTrue(Pos(IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False))),
      ExpandFileName(TempDir)) = 1, 'temp dir uses system temp root');

    IndexPath := IncludeTrailingPathDelimiter(TempDir) + 'index.json';

    JsonLines := TStringList.Create;
    try
      JsonLines.Add('{');
      JsonLines.Add('  "packages": [');
      JsonLines.Add('    {"name": "alpha", "version": "1.0.0", "url": "https://example.com/alpha-1.0.0.tar.gz", "description": "old"},');
      JsonLines.Add('    {"name": "alpha", "version": "1.2.0", "url": ["https://example.com/alpha-1.2.0.tar.gz"], "description": "new"},');
      JsonLines.Add('    {"name": "beta", "version": "2.0.0", "url": ""},');
      JsonLines.Add('    {"name": "gamma", "version": "3.0.0", "url": ["https://example.com/gamma-3.0.0.tar.gz"]}');
      JsonLines.Add('  ]');
      JsonLines.Add('}');
      JsonLines.SaveToFile(IndexPath);
    finally
      JsonLines.Free;
    end;

    Packages := ParseLocalPackageIndexCore(IndexPath);

    AssertTrue(Length(Packages) = 2, 'only valid deduplicated packages are returned');
    AssertEquals('alpha', Packages[0].Name, 'alpha package is preserved');
    AssertEquals('1.2.0', Packages[0].Version, 'highest alpha version is selected');
    AssertEquals('new', Packages[0].Description, 'metadata follows selected highest version');
    AssertEquals('gamma', Packages[1].Name, 'second valid package is preserved');
  finally
    if DirectoryExists(TempDir) then
      DeleteDirRecursive(TempDir);
  end;
end;

begin
  TestParseIndexDeduplicatesAndFilters;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
