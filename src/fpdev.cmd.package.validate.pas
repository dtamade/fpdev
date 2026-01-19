unit fpdev.cmd.package.validate;

{$mode objfpc}{$H+}

(*
  Package Validation Command Module

  Provides functionality for validating package structure and metadata:
  - Validate package.json metadata (required fields, version format)
  - Validate files existence
  - Validate dependencies format
  - Validate LICENSE file
  - Validate README.md file
  - Detect sensitive files

  Usage:
    Validator := TPackageValidator.Create('/path/to/package');
    if Validator.Validate then
      WriteLn('Package is valid')
    else
      WriteLn('Validation failed: ', Validator.GetErrors);
*)

interface

uses
  SysUtils, Classes, fpjson, jsonparser, StrUtils;

type
  TValidationLevel = (vlError, vlWarning, vlInfo);

  TValidationMessage = record
    Level: TValidationLevel;
    Message: string;
  end;

  { TPackageValidator }
  TPackageValidator = class
  private
    FPackageDir: string;
    FMessages: array of TValidationMessage;
    FHasErrors: Boolean;

    procedure AddMessage(ALevel: TValidationLevel; const AMessage: string);
    function LoadMetadata(out AMetadata: TJSONObject): Boolean;
    function IsValidSemVer(const AVersion: string): Boolean;
    function IsSensitiveFile(const AFileName: string): Boolean;

  public
    constructor Create(const APackageDir: string);
    destructor Destroy; override;

    { Validate package metadata }
    function ValidateMetadata: Boolean;

    { Validate files in package.json exist }
    function ValidateFiles: Boolean;

    { Validate dependencies format }
    function ValidateDependencies: Boolean;

    { Validate LICENSE file exists }
    function ValidateLicense: Boolean;

    { Validate README.md file exists }
    function ValidateReadme: Boolean;

    { Detect sensitive files }
    function ValidateSensitiveFiles: Boolean;

    { Complete package validation }
    function Validate: Boolean;

    { Get validation messages }
    function GetMessages: TStringList;

    { Get error messages only }
    function GetErrors: string;

    { Check if validation has errors }
    function HasErrors: Boolean;

    property PackageDir: string read FPackageDir;
  end;

implementation

{ TPackageValidator }

constructor TPackageValidator.Create(const APackageDir: string);
begin
  inherited Create;
  FPackageDir := ExpandFileName(APackageDir);
  SetLength(FMessages, 0);
  FHasErrors := False;
end;

destructor TPackageValidator.Destroy;
begin
  SetLength(FMessages, 0);
  inherited Destroy;
end;

procedure TPackageValidator.AddMessage(ALevel: TValidationLevel; const AMessage: string);
var
  Len: Integer;
begin
  Len := Length(FMessages);
  SetLength(FMessages, Len + 1);
  FMessages[Len].Level := ALevel;
  FMessages[Len].Message := AMessage;

  if ALevel = vlError then
    FHasErrors := True;
end;

function TPackageValidator.LoadMetadata(out AMetadata: TJSONObject): Boolean;
var
  MetaPath: string;
  J: TJSONData;
  FS: TFileStream;
begin
  Result := False;
  AMetadata := nil;

  MetaPath := FPackageDir + PathDelim + 'package.json';
  if not FileExists(MetaPath) then
  begin
    AddMessage(vlError, 'package.json not found');
    Exit;
  end;

  try
    FS := TFileStream.Create(MetaPath, fmOpenRead or fmShareDenyWrite);
    try
      J := GetJSON(FS);
      if J is TJSONObject then
      begin
        AMetadata := TJSONObject(J);
        Result := True;
      end
      else
      begin
        J.Free;
        AddMessage(vlError, 'package.json is not a valid JSON object');
      end;
    finally
      FS.Free;
    end;
  except
    on E: Exception do
    begin
      AddMessage(vlError, 'Failed to load package.json: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TPackageValidator.IsValidSemVer(const AVersion: string): Boolean;
var
  Parts: TStringArray;
  I, Num: Integer;
begin
  Result := False;

  // Basic semver format: major.minor.patch
  Parts := AVersion.Split('.');
  if Length(Parts) < 3 then
    Exit;

  // Check each part is a valid number
  for I := 0 to 2 do
  begin
    if not TryStrToInt(Parts[I], Num) then
      Exit;
    if Num < 0 then
      Exit;
  end;

  Result := True;
end;

function TPackageValidator.IsSensitiveFile(const AFileName: string): Boolean;
var
  LowerName: string;
begin
  LowerName := LowerCase(AFileName);
  Result := (LowerName = '.env') or
            (LowerName = '.env.local') or
            (LowerName = '.env.production') or
            (Pos('credential', LowerName) > 0) or
            (Pos('secret', LowerName) > 0) or
            (Pos('password', LowerName) > 0) or
            (Pos('.key', LowerName) > 0) or
            (Pos('.pem', LowerName) > 0) or
            (Pos('private', LowerName) > 0);
end;

function TPackageValidator.ValidateMetadata: Boolean;
var
  Metadata: TJSONObject;
  RequiredFields: array[0..4] of string = ('name', 'version', 'description', 'author', 'license');
  I: Integer;
  FieldName, Version: string;
begin
  Result := False;

  if not LoadMetadata(Metadata) then
    Exit;

  try
    // Check required fields
    for I := 0 to High(RequiredFields) do
    begin
      FieldName := RequiredFields[I];
      if Metadata.Find(FieldName) = nil then
      begin
        AddMessage(vlError, 'Missing required field: ' + FieldName);
      end;
    end;

    // Validate version format
    if Metadata.Find('version') <> nil then
    begin
      Version := Metadata.Get('version', '');
      if not IsValidSemVer(Version) then
      begin
        AddMessage(vlError, 'Invalid version format: ' + Version + ' (expected semver: major.minor.patch)');
      end;
    end;

    Result := not FHasErrors;
  finally
    Metadata.Free;
  end;
end;

function TPackageValidator.ValidateFiles: Boolean;
var
  Metadata: TJSONObject;
  FilesArray: TJSONArray;
  I: Integer;
  FileName, FilePath: string;
begin
  Result := False;

  if not LoadMetadata(Metadata) then
    Exit;

  try
    // Check if files array exists
    if Metadata.Find('files') = nil then
    begin
      AddMessage(vlInfo, 'No files array specified in package.json');
      Result := True;
      Exit;
    end;

    FilesArray := Metadata.Arrays['files'];
    if FilesArray.Count = 0 then
    begin
      AddMessage(vlWarning, 'Files array is empty');
      Result := True;
      Exit;
    end;

    // Check each file exists
    for I := 0 to FilesArray.Count - 1 do
    begin
      FileName := FilesArray.Strings[I];
      FilePath := FPackageDir + PathDelim + FileName;

      if not FileExists(FilePath) then
      begin
        AddMessage(vlError, 'File not found: ' + FileName);
      end;
    end;

    Result := not FHasErrors;
  finally
    Metadata.Free;
  end;
end;

function TPackageValidator.ValidateDependencies: Boolean;
var
  Metadata: TJSONObject;
  Dependencies: TJSONObject;
  I: Integer;
  DepName, DepVersion: string;
begin
  Result := False;

  if not LoadMetadata(Metadata) then
    Exit;

  try
    // Check if dependencies exist
    if Metadata.Find('dependencies') = nil then
    begin
      AddMessage(vlInfo, 'No dependencies specified');
      Result := True;
      Exit;
    end;

    Dependencies := Metadata.Objects['dependencies'];
    if Dependencies.Count = 0 then
    begin
      AddMessage(vlInfo, 'Dependencies object is empty');
      Result := True;
      Exit;
    end;

    // Validate each dependency format
    for I := 0 to Dependencies.Count - 1 do
    begin
      DepName := Dependencies.Names[I];
      DepVersion := Dependencies.Items[I].AsString;

      // Check for valid version constraint format
      if (Length(DepVersion) = 0) or
         ((DepVersion[1] <> '^') and
          (DepVersion[1] <> '~') and
          (DepVersion[1] <> '>') and
          (DepVersion[1] <> '<') and
          (DepVersion[1] <> '=') and
          not (DepVersion[1] in ['0'..'9'])) then
      begin
        AddMessage(vlError, 'Invalid dependency version format for ' + DepName + ': ' + DepVersion);
      end;
    end;

    Result := not FHasErrors;
  finally
    Metadata.Free;
  end;
end;

function TPackageValidator.ValidateLicense: Boolean;
var
  LicensePath: string;
begin
  Result := False;

  LicensePath := FPackageDir + PathDelim + 'LICENSE';
  if not FileExists(LicensePath) then
  begin
    AddMessage(vlError, 'LICENSE file not found');
    Exit;
  end;

  AddMessage(vlInfo, 'LICENSE file found');
  Result := True;
end;

function TPackageValidator.ValidateReadme: Boolean;
var
  ReadmePath: string;
begin
  Result := True;

  ReadmePath := FPackageDir + PathDelim + 'README.md';
  if not FileExists(ReadmePath) then
  begin
    AddMessage(vlWarning, 'README.md file not found (recommended)');
  end
  else
  begin
    AddMessage(vlInfo, 'README.md file found');
  end;
end;

function TPackageValidator.ValidateSensitiveFiles: Boolean;
var
  Metadata: TJSONObject;
  FilesArray: TJSONArray;
  I: Integer;
  FileName: string;
begin
  Result := False;

  if not LoadMetadata(Metadata) then
    Exit;

  try
    // Check if files array exists
    if Metadata.Find('files') = nil then
    begin
      Result := True;
      Exit;
    end;

    FilesArray := Metadata.Arrays['files'];

    // Check each file for sensitive patterns
    for I := 0 to FilesArray.Count - 1 do
    begin
      FileName := FilesArray.Strings[I];

      if IsSensitiveFile(FileName) then
      begin
        AddMessage(vlError, 'Sensitive file detected in files array: ' + FileName);
      end;
    end;

    Result := not FHasErrors;
  finally
    Metadata.Free;
  end;
end;

function TPackageValidator.Validate: Boolean;
begin
  // Reset state
  SetLength(FMessages, 0);
  FHasErrors := False;

  // Run all validations
  ValidateMetadata;
  ValidateFiles;
  ValidateDependencies;
  ValidateLicense;
  ValidateReadme;
  ValidateSensitiveFiles;

  Result := not FHasErrors;
end;

function TPackageValidator.GetMessages: TStringList;
var
  I: Integer;
  Prefix: string;
begin
  Result := TStringList.Create;

  for I := 0 to High(FMessages) do
  begin
    case FMessages[I].Level of
      vlError: Prefix := '[ERROR] ';
      vlWarning: Prefix := '[WARNING] ';
      vlInfo: Prefix := '[INFO] ';
    end;

    Result.Add(Prefix + FMessages[I].Message);
  end;
end;

function TPackageValidator.GetErrors: string;
var
  I: Integer;
  Errors: TStringList;
begin
  Errors := TStringList.Create;
  try
    for I := 0 to High(FMessages) do
    begin
      if FMessages[I].Level = vlError then
        Errors.Add(FMessages[I].Message);
    end;

    Result := Errors.Text;
  finally
    Errors.Free;
  end;
end;

function TPackageValidator.HasErrors: Boolean;
begin
  Result := FHasErrors;
end;

end.
