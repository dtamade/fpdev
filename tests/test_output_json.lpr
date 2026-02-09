program test_output_json;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.output.json, fpdev.fpc.version;

var
  TestCount, PassCount: Integer;

procedure Test(const AName: string; ACondition: Boolean);
begin
  Inc(TestCount);
  if ACondition then
  begin
    Inc(PassCount);
    WriteLn('PASS: ', AName);
  end
  else
    WriteLn('FAIL: ', AName);
end;

procedure TestVersionInfoToJson;
var
  Info: TFPCVersionInfo;
  Json: TJSONObject;
begin
  Info.Version := '3.2.2';
  Info.ReleaseDate := '2021-05-19';
  Info.GitTag := '3_2_2';
  Info.Branch := 'fixes_3_2';
  Info.Available := True;
  Info.Installed := True;

  Json := TJsonOutputHelper.VersionInfoToJson(Info);
  try
    Test('VersionInfoToJson - version field', Json.Get('version', '') = '3.2.2');
    Test('VersionInfoToJson - release_date field', Json.Get('release_date', '') = '2021-05-19');
    Test('VersionInfoToJson - git_tag field', Json.Get('git_tag', '') = '3_2_2');
    Test('VersionInfoToJson - branch field', Json.Get('branch', '') = 'fixes_3_2');
    Test('VersionInfoToJson - available field', Json.Get('available', False) = True);
    Test('VersionInfoToJson - installed field', Json.Get('installed', False) = True);
  finally
    Json.Free;
  end;
end;

procedure TestVersionArrayToJson;
var
  Arr: TFPCVersionArray;
  JsonArr: TJSONArray;
begin
  SetLength(Arr, 2);
  Arr[0].Version := '3.2.2';
  Arr[0].Installed := True;
  Arr[1].Version := '3.2.0';
  Arr[1].Installed := False;

  JsonArr := TJsonOutputHelper.VersionArrayToJson(Arr);
  try
    Test('VersionArrayToJson - array length', JsonArr.Count = 2);
    Test('VersionArrayToJson - first version', TJSONObject(JsonArr.Items[0]).Get('version', '') = '3.2.2');
    Test('VersionArrayToJson - second version', TJSONObject(JsonArr.Items[1]).Get('version', '') = '3.2.0');
    Test('VersionArrayToJson - first installed', TJSONObject(JsonArr.Items[0]).Get('installed', False) = True);
    Test('VersionArrayToJson - second installed', TJSONObject(JsonArr.Items[1]).Get('installed', False) = False);
  finally
    JsonArr.Free;
  end;
end;

procedure TestSimpleObject;
var
  Json: TJSONObject;
begin
  Json := TJsonOutputHelper.SimpleObject('key', 'value');
  try
    Test('SimpleObject - has key', Json.Get('key', '') = 'value');
    Test('SimpleObject - count is 1', Json.Count = 1);
  finally
    Json.Free;
  end;
end;

procedure TestErrorObject;
var
  Json: TJSONObject;
begin
  Json := TJsonOutputHelper.ErrorObject('Something went wrong', 42);
  try
    Test('ErrorObject - error is true', Json.Get('error', False) = True);
    Test('ErrorObject - code is 42', Json.Get('code', 0) = 42);
    Test('ErrorObject - message set', Json.Get('message', '') = 'Something went wrong');
  finally
    Json.Free;
end;
end;

procedure TestFormatJson;
var
  Json: TJSONObject;
  Formatted: string;
begin
  Json := TJSONObject.Create;
  try
    Json.Add('test', 'value');
    Formatted := TJsonOutputHelper.FormatJson(Json);
    Test('FormatJson - not empty', Formatted <> '');
    Test('FormatJson - contains key', Pos('test', Formatted) > 0);
    Test('FormatJson - contains value', Pos('value', Formatted) > 0);
  finally
    Json.Free;
  end;
end;

procedure TestEmptyVersionArray;
var
  Arr: TFPCVersionArray;
  JsonArr: TJSONArray;
begin
  SetLength(Arr, 0);
  JsonArr := TJsonOutputHelper.VersionArrayToJson(Arr);
  try
    Test('EmptyVersionArray - count is 0', JsonArr.Count = 0);
  finally
    JsonArr.Free;
  end;
end;

begin
  TestCount := 0;
  PassCount := 0;

  WriteLn('=== TJsonOutputHelper Tests ===');
  WriteLn;

  TestVersionInfoToJson;
  TestVersionArrayToJson;
  TestSimpleObject;
  TestErrorObject;
  TestFormatJson;
  TestEmptyVersionArray;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', PassCount, '/', TestCount);

  if PassCount = TestCount then
    WriteLn('All tests passed!')
  else
  begin
    WriteLn('Some tests failed!');
    Halt(1);
  end;
end.
