unit fpdev.fpc.metadata;

{$mode objfpc}{$H+}

{
  FPC Installation Metadata Helper

  Provides functions to read and write .fpdev-meta.json files
  that store installation metadata for FPC versions.

  Extracted from TFPCManager for better separation of concerns.
}

interface

uses
  SysUtils, Classes, fpjson, jsonparser, fpdev.types, fpdev.fpc.types;

const
  META_FILENAME = '.fpdev-meta.json';

{ Write installation metadata to .fpdev-meta.json }
function WriteFPCMetadata(const AInstallPath: string; const AMeta: TFPDevMetadata): Boolean;

{ Read installation metadata from .fpdev-meta.json }
function ReadFPCMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;

{ Check if metadata file exists }
function HasFPCMetadata(const AInstallPath: string): Boolean;

{ Get metadata file path }
function GetMetadataPath(const AInstallPath: string): string;

implementation

uses
  DateUtils, fpdev.utils.fs;

function ParseISO8601OrZero(const AValue: string): TDateTime;
begin
  Result := 0;
  if Trim(AValue) = '' then
    Exit;
  try
    Result := ISO8601ToDate(AValue);
  except
    Result := 0;
  end;
end;

function GetMetadataPath(const AInstallPath: string): string;
begin
  Result := AInstallPath + PathDelim + META_FILENAME;
end;

function HasFPCMetadata(const AInstallPath: string): Boolean;
begin
  Result := FileExists(GetMetadataPath(AInstallPath));
end;

function ScopeToString(AScope: TInstallScope): string;
begin
  case AScope of
    isUser: Result := 'user';
    isProject: Result := 'project';
    isSystem: Result := 'system';
  end;
end;

function StringToScope(const AStr: string): TInstallScope;
begin
  if AStr = 'project' then
    Result := isProject
  else if AStr = 'system' then
    Result := isSystem
  else
    Result := isUser;
end;

function SourceModeToString(AMode: TSourceMode): string;
begin
  case AMode of
    smAuto: Result := 'auto';
    smBinary: Result := 'binary';
    smSource: Result := 'source';
  end;
end;

function StringToSourceMode(const AStr: string): TSourceMode;
begin
  if AStr = 'binary' then
    Result := smBinary
  else if AStr = 'source' then
    Result := smSource
  else
    Result := smAuto;
end;

function WriteFPCMetadata(const AInstallPath: string; const AMeta: TFPDevMetadata): Boolean;
var
  MetaPath: string;
  JSON, VerifyObj, OriginObj: TJSONObject;
begin
  Result := False;

  try
    MetaPath := GetMetadataPath(AInstallPath);

    // Build JSON object
    JSON := TJSONObject.Create;
    try
      JSON.Add('version', AMeta.Version);
      JSON.Add('scope', ScopeToString(AMeta.Scope));
      JSON.Add('source_mode', SourceModeToString(AMeta.SourceMode));
      JSON.Add('channel', AMeta.Channel);
      JSON.Add('prefix', AMeta.Prefix);

      // Verify object
      VerifyObj := TJSONObject.Create;
      VerifyObj.Add('timestamp', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', AMeta.Verify.Timestamp));
      VerifyObj.Add('ok', AMeta.Verify.OK);
      VerifyObj.Add('detected_version', AMeta.Verify.DetectedVersion);
      VerifyObj.Add('smoke_test_passed', AMeta.Verify.SmokeTestPassed);
      JSON.Add('verify', VerifyObj);

      // Origin object
      OriginObj := TJSONObject.Create;
      OriginObj.Add('repo_url', AMeta.Origin.RepoURL);
      OriginObj.Add('commit', AMeta.Origin.Commit);
      OriginObj.Add('built_from_source', AMeta.Origin.BuiltFromSource);
      JSON.Add('origin', OriginObj);

      JSON.Add('installed_at', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', AMeta.InstalledAt));

      // Write to file
      SafeWriteAllText(MetaPath, JSON.FormatJSON);
      Result := True;
    finally
      JSON.Free;
    end;

  except
    Result := False;
  end;
end;

function ReadFPCMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;
var
  MetaPath, JSONText: string;
  JSON, VerifyObj, OriginObj: TJSONObject;
  Parser: TJSONParser;
begin
  Result := False;
  Initialize(AMeta);

  try
    MetaPath := GetMetadataPath(AInstallPath);

    if not FileExists(MetaPath) then
      Exit;

    JSONText := ReadAllTextIfExists(MetaPath);
    if JSONText = '' then
      Exit;

    Parser := TJSONParser.Create(JSONText, []);
    try
      JSON := TJSONObject(Parser.Parse);
      try
        // Read basic fields
        AMeta.Version := JSON.Get('version', '');
        AMeta.Scope := StringToScope(JSON.Get('scope', 'user'));
        AMeta.SourceMode := StringToSourceMode(JSON.Get('source_mode', 'auto'));
        AMeta.Channel := JSON.Get('channel', '');
        AMeta.Prefix := JSON.Get('prefix', '');

        // Read verify object
        if JSON.Find('verify', VerifyObj) then
        begin
          AMeta.Verify.Timestamp := ParseISO8601OrZero(VerifyObj.Get('timestamp', ''));
          AMeta.Verify.OK := VerifyObj.Get('ok', False);
          AMeta.Verify.DetectedVersion := VerifyObj.Get('detected_version', '');
          AMeta.Verify.SmokeTestPassed := VerifyObj.Get('smoke_test_passed', False);
        end;

        // Read origin object
        if JSON.Find('origin', OriginObj) then
        begin
          AMeta.Origin.RepoURL := OriginObj.Get('repo_url', '');
          AMeta.Origin.Commit := OriginObj.Get('commit', '');
          AMeta.Origin.BuiltFromSource := OriginObj.Get('built_from_source', False);
        end;

        AMeta.InstalledAt := ParseISO8601OrZero(JSON.Get('installed_at', ''));

        Result := True;
      finally
        JSON.Free;
      end;
    finally
      Parser.Free;
    end;

  except
    Result := False;
  end;
end;

end.
