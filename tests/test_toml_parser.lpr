program test_toml_parser;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, fpcunit, testutils, testregistry, consoletestrunner,
  fpdev.toml.parser;

type
  TTOMLParserTest = class(TTestCase)
  published
    procedure TestParseSimpleString;
    procedure TestParseBoolean;
    procedure TestParseInteger;
    procedure TestParseArray;
    procedure TestParseSection;
    procedure TestParseMultipleSections;
    procedure TestParseKeyValue;
    procedure TestParseComments;
    procedure TestParseEmptyLines;
    procedure TestParseQuotedStrings;
    procedure TestParseArrayWithQuotes;
    procedure TestGetSectionValue;
    procedure TestHasSection;
    procedure TestHasKey;
    procedure TestGetStringWithDefault;
    procedure TestGetBooleanWithDefault;
    procedure TestGetIntegerWithDefault;
    procedure TestGetArray;
    procedure TestLoadFromFile;
    procedure TestLoadFromString;
    procedure TestParseError;
  end;

procedure TTOMLParserTest.TestParseSimpleString;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
begin
  Doc := TTOMLDocument.Create;
  try
    AssertTrue('Parse simple string', Doc.LoadFromString('[test]' + LineEnding + 'key = "value"'));
    Section := Doc.GetSection('test');
    AssertNotNull('Section exists', Section);
    AssertEquals('String value', 'value', Section.GetString('key'));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestParseBoolean;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
begin
  Doc := TTOMLDocument.Create;
  try
    AssertTrue('Parse boolean', Doc.LoadFromString('[test]' + LineEnding + 'enabled = true' + LineEnding + 'disabled = false'));
    Section := Doc.GetSection('test');
    AssertTrue('Boolean true', Section.GetBoolean('enabled'));
    AssertFalse('Boolean false', Section.GetBoolean('disabled'));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestParseInteger;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
begin
  Doc := TTOMLDocument.Create;
  try
    AssertTrue('Parse integer', Doc.LoadFromString('[test]' + LineEnding + 'count = 42'));
    Section := Doc.GetSection('test');
    AssertEquals('Integer value', 42, Section.GetInteger('count'));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestParseArray;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
  Arr: TStringList;
begin
  Doc := TTOMLDocument.Create;
  try
    AssertTrue('Parse array', Doc.LoadFromString('[test]' + LineEnding + 'items = ["a", "b", "c"]'));
    Section := Doc.GetSection('test');
    Arr := Section.GetArray('items');
    AssertNotNull('Array exists', Arr);
    AssertEquals('Array count', 3, Arr.Count);
    AssertEquals('Array item 0', 'a', Arr[0]);
    AssertEquals('Array item 1', 'b', Arr[1]);
    AssertEquals('Array item 2', 'c', Arr[2]);
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestParseSection;
var
  Doc: TTOMLDocument;
begin
  Doc := TTOMLDocument.Create;
  try
    AssertTrue('Parse section', Doc.LoadFromString('[mysection]'));
    AssertTrue('Section exists', Doc.HasSection('mysection'));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestParseMultipleSections;
var
  Doc: TTOMLDocument;
begin
  Doc := TTOMLDocument.Create;
  try
    AssertTrue('Parse multiple sections', Doc.LoadFromString('[section1]' + LineEnding + 'key1 = "value1"' + LineEnding + '[section2]' + LineEnding + 'key2 = "value2"'));
    AssertTrue('Section 1 exists', Doc.HasSection('section1'));
    AssertTrue('Section 2 exists', Doc.HasSection('section2'));
    AssertEquals('Section 1 value', 'value1', Doc.GetSection('section1').GetString('key1'));
    AssertEquals('Section 2 value', 'value2', Doc.GetSection('section2').GetString('key2'));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestParseKeyValue;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
begin
  Doc := TTOMLDocument.Create;
  try
    AssertTrue('Parse key-value', Doc.LoadFromString('[test]' + LineEnding + 'name = "John"' + LineEnding + 'age = 30'));
    Section := Doc.GetSection('test');
    AssertEquals('Name value', 'John', Section.GetString('name'));
    AssertEquals('Age value', 30, Section.GetInteger('age'));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestParseComments;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
begin
  Doc := TTOMLDocument.Create;
  try
    AssertTrue('Parse with comments', Doc.LoadFromString('[test]' + LineEnding + '# This is a comment' + LineEnding + 'key = "value"'));
    Section := Doc.GetSection('test');
    AssertEquals('Value after comment', 'value', Section.GetString('key'));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestParseEmptyLines;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
begin
  Doc := TTOMLDocument.Create;
  try
    AssertTrue('Parse with empty lines', Doc.LoadFromString('[test]' + LineEnding + LineEnding + 'key = "value"' + LineEnding + LineEnding));
    Section := Doc.GetSection('test');
    AssertEquals('Value with empty lines', 'value', Section.GetString('key'));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestParseQuotedStrings;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
begin
  Doc := TTOMLDocument.Create;
  try
    AssertTrue('Parse quoted strings', Doc.LoadFromString('[test]' + LineEnding + 'double = "value"' + LineEnding + 'single = ''value'''));
    Section := Doc.GetSection('test');
    AssertEquals('Double quoted', 'value', Section.GetString('double'));
    AssertEquals('Single quoted', 'value', Section.GetString('single'));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestParseArrayWithQuotes;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
  Arr: TStringList;
begin
  Doc := TTOMLDocument.Create;
  try
    AssertTrue('Parse array with quotes', Doc.LoadFromString('[test]' + LineEnding + 'items = ["item 1", "item 2", "item 3"]'));
    Section := Doc.GetSection('test');
    Arr := Section.GetArray('items');
    AssertEquals('Array item with space', 'item 1', Arr[0]);
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestGetSectionValue;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
  Value: TTOMLValue;
begin
  Doc := TTOMLDocument.Create;
  try
    Doc.LoadFromString('[test]' + LineEnding + 'key = "value"');
    Section := Doc.GetSection('test');
    Value := Section.GetValue('key');
    AssertNotNull('Value exists', Value);
    AssertEquals('Value type', Ord(tvtString), Ord(Value.ValueType));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestHasSection;
var
  Doc: TTOMLDocument;
begin
  Doc := TTOMLDocument.Create;
  try
    Doc.LoadFromString('[test]');
    AssertTrue('Has section', Doc.HasSection('test'));
    AssertFalse('No section', Doc.HasSection('nonexistent'));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestHasKey;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
begin
  Doc := TTOMLDocument.Create;
  try
    Doc.LoadFromString('[test]' + LineEnding + 'key = "value"');
    Section := Doc.GetSection('test');
    AssertTrue('Has key', Section.HasKey('key'));
    AssertFalse('No key', Section.HasKey('nonexistent'));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestGetStringWithDefault;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
begin
  Doc := TTOMLDocument.Create;
  try
    Doc.LoadFromString('[test]' + LineEnding + 'key = "value"');
    Section := Doc.GetSection('test');
    AssertEquals('Existing key', 'value', Section.GetString('key', 'default'));
    AssertEquals('Missing key', 'default', Section.GetString('missing', 'default'));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestGetBooleanWithDefault;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
begin
  Doc := TTOMLDocument.Create;
  try
    Doc.LoadFromString('[test]' + LineEnding + 'enabled = true');
    Section := Doc.GetSection('test');
    AssertTrue('Existing key', Section.GetBoolean('enabled', False));
    AssertFalse('Missing key', Section.GetBoolean('missing', False));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestGetIntegerWithDefault;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
begin
  Doc := TTOMLDocument.Create;
  try
    Doc.LoadFromString('[test]' + LineEnding + 'count = 42');
    Section := Doc.GetSection('test');
    AssertEquals('Existing key', 42, Section.GetInteger('count', 0));
    AssertEquals('Missing key', 0, Section.GetInteger('missing', 0));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestGetArray;
var
  Doc: TTOMLDocument;
  Section: TTOMLSection;
  Arr: TStringList;
begin
  Doc := TTOMLDocument.Create;
  try
    Doc.LoadFromString('[test]' + LineEnding + 'items = ["a", "b"]');
    Section := Doc.GetSection('test');
    Arr := Section.GetArray('items');
    AssertNotNull('Array exists', Arr);
    AssertEquals('Array count', 2, Arr.Count);
    Arr := Section.GetArray('missing');
    AssertNull('Missing array', Arr);
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestLoadFromFile;
var
  Doc: TTOMLDocument;
  FileName: string;
  F: TextFile;
begin
  FileName := GetTempFileName('', 'test');
  AssignFile(F, FileName);
  try
    Rewrite(F);
    WriteLn(F, '[test]');
    WriteLn(F, 'key = "value"');
    CloseFile(F);

    Doc := TTOMLDocument.Create;
    try
      AssertTrue('Load from file', Doc.LoadFromFile(FileName));
      AssertEquals('File value', 'value', Doc.GetSection('test').GetString('key'));
    finally
      Doc.Free;
    end;
  finally
    DeleteFile(FileName);
  end;
end;

procedure TTOMLParserTest.TestLoadFromString;
var
  Doc: TTOMLDocument;
begin
  Doc := TTOMLDocument.Create;
  try
    AssertTrue('Load from string', Doc.LoadFromString('[test]' + LineEnding + 'key = "value"'));
    AssertEquals('String value', 'value', Doc.GetSection('test').GetString('key'));
  finally
    Doc.Free;
  end;
end;

procedure TTOMLParserTest.TestParseError;
var
  Doc: TTOMLDocument;
begin
  Doc := TTOMLDocument.Create;
  try
    AssertFalse('Invalid TOML', Doc.LoadFromString('[test' + LineEnding + 'key = value'));
    AssertTrue('Error message set', Doc.ParseError <> '');
  finally
    Doc.Free;
  end;
end;

begin
  RegisterTest(TTOMLParserTest);
  
  with TTestRunner.Create(nil) do
  try
    Initialize;
    Run;
  finally
    Free;
  end;
end.
