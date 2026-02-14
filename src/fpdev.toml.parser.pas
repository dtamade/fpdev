unit fpdev.toml.parser;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl;

type
  TTOMLValueType = (tvtString, tvtBoolean, tvtInteger, tvtArray);

  TTOMLValue = class
  private
    FValueType: TTOMLValueType;
    FStringValue: string;
    FBooleanValue: Boolean;
    FIntegerValue: Int64;
    FArrayValue: TStringList;
  public
    constructor Create(AType: TTOMLValueType);
    destructor Destroy; override;

    property ValueType: TTOMLValueType read FValueType;
    property StringValue: string read FStringValue write FStringValue;
    property BooleanValue: Boolean read FBooleanValue write FBooleanValue;
    property IntegerValue: Int64 read FIntegerValue write FIntegerValue;
    property ArrayValue: TStringList read FArrayValue;

    function AsString: string;
    function AsBoolean: Boolean;
    function AsInteger: Int64;
    function AsArray: TStringList;
  end;

  TTOMLSection = class;
  TTOMLSectionMap = specialize TFPGMap<string, TTOMLSection>;
  TTOMLValueMap = specialize TFPGMap<string, TTOMLValue>;

  TTOMLSection = class
  private
    FName: string;
    FValues: TTOMLValueMap;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;

    property Name: string read FName;
    property Values: TTOMLValueMap read FValues;

    function GetValue(const AKey: string): TTOMLValue;
    function HasKey(const AKey: string): Boolean;
    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetBoolean(const AKey: string; ADefault: Boolean = False): Boolean;
    function GetInteger(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetArray(const AKey: string): TStringList;
  end;

  TTOMLDocument = class
  private
    FSections: TTOMLSectionMap;
    FCurrentSection: TTOMLSection;
    FParseError: string;

    function ParseLine(const ALine: string): Boolean;
    function ParseSection(const ALine: string): Boolean;
    function ParseKeyValue(const ALine: string): Boolean;
    function ParseValue(const AValue: string): TTOMLValue;
    function ParseArray(const AValue: string): TTOMLValue;
    function UnquoteString(const AStr: string): string;
    function TrimComment(const ALine: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    function LoadFromFile(const AFileName: string): Boolean;
    function LoadFromString(const AContent: string): Boolean;
    function GetSection(const AName: string): TTOMLSection;
    function HasSection(const AName: string): Boolean;

    property ParseError: string read FParseError;
    property Sections: TTOMLSectionMap read FSections;
  end;

  ETOMLParseError = class(Exception);

implementation

{ TTOMLValue }

constructor TTOMLValue.Create(AType: TTOMLValueType);
begin
  inherited Create;
  FValueType := AType;
  if AType = tvtArray then
    FArrayValue := TStringList.Create;
end;

destructor TTOMLValue.Destroy;
begin
  if Assigned(FArrayValue) then
    FArrayValue.Free;
  inherited Destroy;
end;

function TTOMLValue.AsString: string;
begin
  if FValueType = tvtString then
    Result := FStringValue
  else
    raise ETOMLParseError.Create('Value is not a string');
end;

function TTOMLValue.AsBoolean: Boolean;
begin
  if FValueType = tvtBoolean then
    Result := FBooleanValue
  else
    raise ETOMLParseError.Create('Value is not a boolean');
end;

function TTOMLValue.AsInteger: Int64;
begin
  if FValueType = tvtInteger then
    Result := FIntegerValue
  else
    raise ETOMLParseError.Create('Value is not an integer');
end;

function TTOMLValue.AsArray: TStringList;
begin
  if FValueType = tvtArray then
    Result := FArrayValue
  else
    raise ETOMLParseError.Create('Value is not an array');
end;

{ TTOMLSection }

constructor TTOMLSection.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FValues := TTOMLValueMap.Create;
end;

destructor TTOMLSection.Destroy;
var
  I: Integer;
begin
  for I := 0 to FValues.Count - 1 do
    FValues.Data[I].Free;
  FValues.Free;
  inherited Destroy;
end;

function TTOMLSection.GetValue(const AKey: string): TTOMLValue;
var
  Index: Integer;
begin
  Index := FValues.IndexOf(AKey);
  if Index >= 0 then
    Result := FValues.Data[Index]
  else
    Result := nil;
end;

function TTOMLSection.HasKey(const AKey: string): Boolean;
begin
  Result := FValues.IndexOf(AKey) >= 0;
end;

function TTOMLSection.GetString(const AKey: string; const ADefault: string): string;
var
  Value: TTOMLValue;
begin
  Value := GetValue(AKey);
  if Assigned(Value) and (Value.ValueType = tvtString) then
    Result := Value.StringValue
  else
    Result := ADefault;
end;

function TTOMLSection.GetBoolean(const AKey: string; ADefault: Boolean): Boolean;
var
  Value: TTOMLValue;
begin
  Value := GetValue(AKey);
  if Assigned(Value) and (Value.ValueType = tvtBoolean) then
    Result := Value.BooleanValue
  else
    Result := ADefault;
end;

function TTOMLSection.GetInteger(const AKey: string; ADefault: Int64): Int64;
var
  Value: TTOMLValue;
begin
  Value := GetValue(AKey);
  if Assigned(Value) and (Value.ValueType = tvtInteger) then
    Result := Value.IntegerValue
  else
    Result := ADefault;
end;

function TTOMLSection.GetArray(const AKey: string): TStringList;
var
  Value: TTOMLValue;
begin
  Value := GetValue(AKey);
  if Assigned(Value) and (Value.ValueType = tvtArray) then
    Result := Value.ArrayValue
  else
    Result := nil;
end;

{ TTOMLDocument }

constructor TTOMLDocument.Create;
begin
  inherited Create;
  FSections := TTOMLSectionMap.Create;
  FCurrentSection := nil;
  FParseError := '';
end;

destructor TTOMLDocument.Destroy;
var
  I: Integer;
begin
  for I := 0 to FSections.Count - 1 do
    FSections.Data[I].Free;
  FSections.Free;
  inherited Destroy;
end;

function TTOMLDocument.TrimComment(const ALine: string): string;
var
  Pos: Integer;
begin
  Pos := System.Pos('#', ALine);
  if Pos > 0 then
    Result := Copy(ALine, 1, Pos - 1)
  else
    Result := ALine;
end;

function TTOMLDocument.LoadFromFile(const AFileName: string): Boolean;
var
  Content: TStringList;
begin
  Result := False;
  FParseError := '';

  if not FileExists(AFileName) then
  begin
    FParseError := 'File not found: ' + AFileName;
    Exit;
  end;

  Content := TStringList.Create;
  try
    Content.LoadFromFile(AFileName);
    Result := LoadFromString(Content.Text);
  finally
    Content.Free;
  end;
end;

function TTOMLDocument.LoadFromString(const AContent: string): Boolean;
var
  Lines: TStringList;
  I: Integer;
  Line: string;
begin
  Result := True;
  FParseError := '';

  Lines := TStringList.Create;
  try
    Lines.Text := AContent;

    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(TrimComment(Lines[I]));

      if Line = '' then
        Continue;

      if not ParseLine(Line) then
      begin
        FParseError := Format('Parse error at line %d: %s', [I + 1, Line]);
        Result := False;
        Break;
      end;
    end;
  finally
    Lines.Free;
  end;
end;

function TTOMLDocument.ParseLine(const ALine: string): Boolean;
begin
  if (Length(ALine) > 0) and (ALine[1] = '[') then
    Result := ParseSection(ALine)
  else
    Result := ParseKeyValue(ALine);
end;

function TTOMLDocument.ParseSection(const ALine: string): Boolean;
var
  SectionName: string;
  EndPos: Integer;
begin
  Result := False;

  EndPos := Pos(']', ALine);
  if EndPos = 0 then
    Exit;

  SectionName := Trim(Copy(ALine, 2, EndPos - 2));
  if SectionName = '' then
    Exit;

  FCurrentSection := TTOMLSection.Create(SectionName);
  FSections.Add(SectionName, FCurrentSection);
  Result := True;
end;

function TTOMLDocument.ParseKeyValue(const ALine: string): Boolean;
var
  EqualPos: Integer;
  Key, ValueStr: string;
  Value: TTOMLValue;
begin
  Result := False;

  if not Assigned(FCurrentSection) then
    Exit;

  EqualPos := Pos('=', ALine);
  if EqualPos = 0 then
    Exit;

  Key := Trim(Copy(ALine, 1, EqualPos - 1));
  ValueStr := Trim(Copy(ALine, EqualPos + 1, Length(ALine)));

  if (Key = '') or (ValueStr = '') then
    Exit;

  Value := ParseValue(ValueStr);
  if not Assigned(Value) then
    Exit;

  FCurrentSection.Values.Add(Key, Value);
  Result := True;
end;

function TTOMLDocument.ParseValue(const AValue: string): TTOMLValue;
var
  LowerValue: string;
  IntValue: Int64;
begin
  Result := nil;

  if (Length(AValue) > 0) and (AValue[1] = '[') then
  begin
    Result := ParseArray(AValue);
  end
  else if (Length(AValue) > 0) and ((AValue[1] = '"') or (AValue[1] = '''')) then
  begin
    Result := TTOMLValue.Create(tvtString);
    Result.StringValue := UnquoteString(AValue);
  end
  else
  begin
    LowerValue := LowerCase(AValue);
    if (LowerValue = 'true') or (LowerValue = 'false') then
    begin
      Result := TTOMLValue.Create(tvtBoolean);
      Result.BooleanValue := (LowerValue = 'true');
    end
    else if TryStrToInt64(AValue, IntValue) then
    begin
      Result := TTOMLValue.Create(tvtInteger);
      Result.IntegerValue := IntValue;
    end
    else
    begin
      Result := TTOMLValue.Create(tvtString);
      Result.StringValue := AValue;
    end;
  end;
end;

function TTOMLDocument.ParseArray(const AValue: string): TTOMLValue;
var
  Content: string;
  Items: TStringList;
  I, Start, Len: Integer;
  InQuote: Boolean;
  QuoteChar: Char;
  Item: string;
begin
  Result := TTOMLValue.Create(tvtArray);

  if (Length(AValue) < 2) or (AValue[1] <> '[') or (AValue[Length(AValue)] <> ']') then
    Exit;

  Content := Trim(Copy(AValue, 2, Length(AValue) - 2));
  if Content = '' then
    Exit;

  Items := TStringList.Create;
  try
    Start := 1;
    InQuote := False;
    QuoteChar := #0;
    Len := Length(Content);

    for I := 1 to Len do
    begin
      if not InQuote then
      begin
        if (Content[I] = '"') or (Content[I] = '''') then
        begin
          InQuote := True;
          QuoteChar := Content[I];
        end
        else if Content[I] = ',' then
        begin
          Item := Trim(Copy(Content, Start, I - Start));
          if Item <> '' then
            Items.Add(UnquoteString(Item));
          Start := I + 1;
        end;
      end
      else
      begin
        if Content[I] = QuoteChar then
          InQuote := False;
      end;
    end;

    Item := Trim(Copy(Content, Start, Len - Start + 1));
    if Item <> '' then
      Items.Add(UnquoteString(Item));

    for I := 0 to Items.Count - 1 do
      Result.ArrayValue.Add(Items[I]);
  finally
    Items.Free;
  end;
end;

function TTOMLDocument.UnquoteString(const AStr: string): string;
var
  Len: Integer;
begin
  Len := Length(AStr);
  if (Len >= 2) and ((AStr[1] = '"') or (AStr[1] = '''')) and (AStr[Len] = AStr[1]) then
    Result := Copy(AStr, 2, Len - 2)
  else
    Result := AStr;
end;

function TTOMLDocument.GetSection(const AName: string): TTOMLSection;
var
  Index: Integer;
begin
  Index := FSections.IndexOf(AName);
  if Index >= 0 then
    Result := FSections.Data[Index]
  else
    Result := nil;
end;

function TTOMLDocument.HasSection(const AName: string): Boolean;
begin
  Result := FSections.IndexOf(AName) >= 0;
end;

end.
