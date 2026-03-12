program test_package_create_metadata_helper;

{$mode objfpc}{$H+}

uses
  SysUtils, fpjson, jsonparser,
  fpdev.cmd.package, fpdev.package.types;

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

procedure TestGeneratePackageMetadataJsonIncludesDefaultFields;
var
  Options: TPackageCreationOptions;
  MetaJson: string;
  JsonData: TJSONData;
  JsonObject: TJSONObject;
begin
  FillChar(Options, SizeOf(Options), 0);
  Options.Name := 'demo-pkg';
  Options.Version := '1.0.0';
  Options.SourcePath := '/tmp/demo';

  MetaJson := GeneratePackageMetadataJson(Options);
  JsonData := GetJSON(MetaJson);
  try
    JsonObject := TJSONObject(JsonData);
    AssertTrue(JsonObject.Get('name', '') = 'demo-pkg', 'metadata contains name');
    AssertTrue(JsonObject.Get('version', '') = '1.0.0', 'metadata contains version');
    AssertTrue(JsonObject.Get('homepage', '') = '', 'metadata contains homepage default');
    AssertTrue(JsonObject.Get('repository', '') = '', 'metadata contains repository default');
    AssertTrue(Assigned(JsonObject.Arrays['keywords']) and (JsonObject.Arrays['keywords'].Count = 0), 'metadata contains empty keywords array');
  finally
    JsonData.Free;
  end;
end;

begin
  TestGeneratePackageMetadataJsonIncludesDefaultFields;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
