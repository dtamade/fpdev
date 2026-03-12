unit fpdev.cross.manifest;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser, DateUtils;

const
  ERR_NONE = 0;
  ERR_MISSING_FIELD = 1;
  ERR_INVALID_JSON = 2;
  ERR_INVALID_DATE = 3;
  ERR_EMPTY_ARRAY = 4;

type
  { THostPlatform - Host platform specification }
  THostPlatform = record
    OS: string;
    Arch: string;
  end;

  { TCrossToolchainEntry - Single toolchain entry }
  TCrossToolchainEntry = record
    Target: string;
    ComponentType: string;
    Version: string;
    HostPlatforms: array of THostPlatform;
    URLs: array of string;
    SHA256: string;
    ArchiveFormat: string;
  end;

  TCrossToolchainEntryArray = array of TCrossToolchainEntry;

  { Legacy type aliases for backward compatibility }
  TCrossBinutils = record
    URLs: array of string;
    Sha256: string;
  end;

  TCrossManifestTarget = record
    Name: string;
    Libraries: TCrossBinutils;
  end;

  { TManifestError - Error information }
  TManifestError = record
    Code: Integer;
    Message: string;
  end;

  { TCrossToolchainManifest - Cross-compilation toolchain manifest }
  TCrossToolchainManifest = class
  private
    FVersion: string;
    FLastUpdated: TDateTime;
    FEntries: TCrossToolchainEntryArray;
    FLastError: TManifestError;

    function ParseJSON(const AJSON: string): Boolean;
    function ParseHostPlatform(AObj: TJSONObject): THostPlatform;
    function ParseEntry(AObj: TJSONObject): TCrossToolchainEntry;
    procedure ClearError;
    procedure SetError(ACode: Integer; const AMessage: string);

  public
    constructor Create;
    destructor Destroy; override;

    { Load manifest from file }
    function LoadFromFile(const AFileName: string): Boolean;

    { Load manifest from JSON string }
    function LoadFromString(const AJSON: string): Boolean;

    { Find entry by target, component type, and host platform }
    function FindEntry(const ATarget, AComponentType: string; const AHost: THostPlatform): TCrossToolchainEntry;

    { Check if manifest needs update (older than 7 days) }
    function NeedsUpdate: Boolean;

    { Serialize manifest to JSON }
    function ToJSON: string;

    { Legacy compatibility methods }
    function GetTarget(const ATarget: string; out AManifestTarget: TCrossManifestTarget): Boolean;
    function GetBinutilsForHost(
      const AManifestTarget: TCrossManifestTarget;
      const {%H-} AHostPlatform: string;
      out ABinutils: TCrossBinutils
    ): Boolean;

    { Properties }
    property Version: string read FVersion;
    property LastUpdated: TDateTime read FLastUpdated;
    property Entries: TCrossToolchainEntryArray read FEntries;
    property LastError: TManifestError read FLastError;
  end;

  { Type alias for backward compatibility }
  TCrossManifest = TCrossToolchainManifest;

{ Helper function to check if two host platforms match }
function HostPlatformMatches(const A, B: THostPlatform): Boolean;

implementation

{ Helper Functions }

function HostPlatformMatches(const A, B: THostPlatform): Boolean;
begin
  Result := SameText(A.OS, B.OS) and SameText(A.Arch, B.Arch);
end;

{ TCrossToolchainManifest }

constructor TCrossToolchainManifest.Create;
begin
  inherited Create;
  FVersion := '';
  FLastUpdated := 0;
  SetLength(FEntries, 0);
  ClearError;
end;

destructor TCrossToolchainManifest.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(FEntries) do
  begin
    SetLength(FEntries[i].HostPlatforms, 0);
    SetLength(FEntries[i].URLs, 0);
  end;
  SetLength(FEntries, 0);
  inherited Destroy;
end;

procedure TCrossToolchainManifest.ClearError;
begin
  FLastError.Code := ERR_NONE;
  FLastError.Message := '';
end;

procedure TCrossToolchainManifest.SetError(ACode: Integer; const AMessage: string);
begin
  FLastError.Code := ACode;
  FLastError.Message := AMessage;
end;

function TCrossToolchainManifest.ParseHostPlatform(AObj: TJSONObject): THostPlatform;
begin
  Result.OS := AObj.Get('os', '');
  Result.Arch := AObj.Get('arch', '');
end;

function TCrossToolchainManifest.ParseEntry(AObj: TJSONObject): TCrossToolchainEntry;
var
  HostPlatformsArray: TJSONArray;
  URLsArray: TJSONArray;
  i: Integer;
begin
  // Initialize managed type fields
  Result.Target := '';
  Result.ComponentType := '';
  Result.Version := '';
  Result.SHA256 := '';
  Result.ArchiveFormat := '';
  SetLength(Result.HostPlatforms, 0);
  SetLength(Result.URLs, 0);

  // Required fields
  Result.Target := AObj.Get('target', '');
  Result.ComponentType := AObj.Get('componentType', '');
  Result.Version := AObj.Get('version', '');
  Result.SHA256 := AObj.Get('sha256', '');
  Result.ArchiveFormat := AObj.Get('archiveFormat', '');

  // Parse hostPlatforms array
  if AObj.Find('hostPlatforms') <> nil then
  begin
    HostPlatformsArray := AObj.Arrays['hostPlatforms'];
    SetLength(Result.HostPlatforms, HostPlatformsArray.Count);
    for i := 0 to HostPlatformsArray.Count - 1 do
    begin
      if HostPlatformsArray.Items[i] is TJSONObject then
        Result.HostPlatforms[i] := ParseHostPlatform(TJSONObject(HostPlatformsArray.Items[i]));
    end;
  end;

  // Parse urls array
  if AObj.Find('urls') <> nil then
  begin
    URLsArray := AObj.Arrays['urls'];
    SetLength(Result.URLs, URLsArray.Count);
    for i := 0 to URLsArray.Count - 1 do
      Result.URLs[i] := URLsArray.Strings[i];
  end;
end;

function TCrossToolchainManifest.ParseJSON(const AJSON: string): Boolean;
var
  JSONData: TJSONData;
  RootObj: TJSONObject;
  ToolchainsArray: TJSONArray;
  i: Integer;
  DateStr: string;
begin
  Result := False;
  ClearError;

  try
    JSONData := GetJSON(AJSON);
    try
      if not (JSONData is TJSONObject) then
      begin
        SetError(ERR_INVALID_JSON, 'Root element must be an object');
        Exit;
      end;

      RootObj := TJSONObject(JSONData);

      // Check required fields
      if RootObj.Find('version') = nil then
      begin
        SetError(ERR_MISSING_FIELD, 'Missing required field: version');
        Exit;
      end;

      if RootObj.Find('lastUpdated') = nil then
      begin
        SetError(ERR_MISSING_FIELD, 'Missing required field: lastUpdated');
        Exit;
      end;

      if RootObj.Find('toolchains') = nil then
      begin
        SetError(ERR_MISSING_FIELD, 'Missing required field: toolchains');
        Exit;
      end;

      // Parse version
      FVersion := RootObj.Get('version', '');

      // Parse lastUpdated (ISO 8601 format)
      DateStr := RootObj.Get('lastUpdated', '');
      try
        FLastUpdated := ISO8601ToDate(DateStr);
      except
        on E: Exception do
        begin
          SetError(ERR_INVALID_DATE, 'Invalid date format: ' + DateStr);
          Exit;
        end;
      end;

      // Parse toolchains array
      ToolchainsArray := RootObj.Arrays['toolchains'];
      if ToolchainsArray.Count = 0 then
      begin
        SetError(ERR_EMPTY_ARRAY, 'Toolchains array cannot be empty');
        Exit;
      end;

      SetLength(FEntries, ToolchainsArray.Count);
      for i := 0 to ToolchainsArray.Count - 1 do
      begin
        if not (ToolchainsArray.Items[i] is TJSONObject) then
        begin
          SetError(ERR_INVALID_JSON, 'Toolchain entry must be an object');
          Exit;
        end;

        FEntries[i] := ParseEntry(TJSONObject(ToolchainsArray.Items[i]));

        // Validate required entry fields
        if FEntries[i].Target = '' then
        begin
          SetError(ERR_MISSING_FIELD, 'Entry missing required field: target');
          Exit;
        end;

        if FEntries[i].ComponentType = '' then
        begin
          SetError(ERR_MISSING_FIELD, 'Entry missing required field: componentType');
          Exit;
        end;

        if Length(FEntries[i].HostPlatforms) = 0 then
        begin
          SetError(ERR_EMPTY_ARRAY, 'Entry hostPlatforms array cannot be empty');
          Exit;
        end;
      end;

      Result := True;
    finally
      JSONData.Free;
    end;
  except
    on E: Exception do
    begin
      SetError(ERR_INVALID_JSON, 'JSON parse error: ' + E.Message);
      Exit;
    end;
  end;
end;

function TCrossToolchainManifest.LoadFromFile(const AFileName: string): Boolean;
var
  SL: TStringList;
  JSON: string;
begin
  Result := False;
  ClearError;

  if not FileExists(AFileName) then
  begin
    SetError(ERR_INVALID_JSON, 'File not found: ' + AFileName);
    Exit;
  end;

  SL := TStringList.Create;
  try
    try
      SL.LoadFromFile(AFileName);
      JSON := SL.Text;
      Result := ParseJSON(JSON);
    except
      on E: Exception do
      begin
        SetError(ERR_INVALID_JSON, 'Error reading file: ' + E.Message);
        Exit;
      end;
    end;
  finally
    SL.Free;
  end;
end;

function TCrossToolchainManifest.LoadFromString(const AJSON: string): Boolean;
begin
  Result := ParseJSON(AJSON);
end;

function TCrossToolchainManifest.FindEntry(
  const ATarget, AComponentType: string;
  const AHost: THostPlatform
): TCrossToolchainEntry;
var
  i, j: Integer;
begin
  // Initialize managed type fields
  Result.Target := '';
  Result.ComponentType := '';
  Result.Version := '';
  Result.SHA256 := '';
  Result.ArchiveFormat := '';
  SetLength(Result.HostPlatforms, 0);
  SetLength(Result.URLs, 0);

  for i := 0 to High(FEntries) do
  begin
    if SameText(FEntries[i].Target, ATarget) and
       SameText(FEntries[i].ComponentType, AComponentType) then
    begin
      // Check if host platform matches
      for j := 0 to High(FEntries[i].HostPlatforms) do
      begin
        if HostPlatformMatches(FEntries[i].HostPlatforms[j], AHost) then
        begin
          Result := FEntries[i];
          Exit;
        end;
      end;
    end;
  end;
end;

function TCrossToolchainManifest.NeedsUpdate: Boolean;
const
  UPDATE_INTERVAL_DAYS = 7;
begin
  // Empty manifest needs update
  if FLastUpdated = 0 then
    Exit(True);

  // Check if older than 7 days
  Result := DaysBetween(Now, FLastUpdated) > UPDATE_INTERVAL_DAYS;
end;

function TCrossToolchainManifest.ToJSON: string;
var
  Root: TJSONObject;
  ToolchainsArray: TJSONArray;
  EntryObj: TJSONObject;
  HostPlatformsArray: TJSONArray;
  HostObj: TJSONObject;
  URLsArray: TJSONArray;
  i, j: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('version', FVersion);
    Root.Add('lastUpdated', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', FLastUpdated));

    ToolchainsArray := TJSONArray.Create;
    for i := 0 to High(FEntries) do
    begin
      EntryObj := TJSONObject.Create;
      EntryObj.Add('target', FEntries[i].Target);
      EntryObj.Add('componentType', FEntries[i].ComponentType);
      EntryObj.Add('version', FEntries[i].Version);

      // Add hostPlatforms
      HostPlatformsArray := TJSONArray.Create;
      for j := 0 to High(FEntries[i].HostPlatforms) do
      begin
        HostObj := TJSONObject.Create;
        HostObj.Add('os', FEntries[i].HostPlatforms[j].OS);
        HostObj.Add('arch', FEntries[i].HostPlatforms[j].Arch);
        HostPlatformsArray.Add(HostObj);
      end;
      EntryObj.Add('hostPlatforms', HostPlatformsArray);

      // Add urls
      URLsArray := TJSONArray.Create;
      for j := 0 to High(FEntries[i].URLs) do
        URLsArray.Add(FEntries[i].URLs[j]);
      EntryObj.Add('urls', URLsArray);

      EntryObj.Add('sha256', FEntries[i].SHA256);
      EntryObj.Add('archiveFormat', FEntries[i].ArchiveFormat);

      ToolchainsArray.Add(EntryObj);
    end;
    Root.Add('toolchains', ToolchainsArray);

    Result := Root.AsJSON;
  finally
    Root.Free;
  end;
end;

{ Legacy compatibility methods }

function TCrossToolchainManifest.GetTarget(const ATarget: string; out AManifestTarget: TCrossManifestTarget): Boolean;
var
  i: Integer;
begin
  Result := False;
  // Initialize managed type fields
  AManifestTarget.Name := '';
  SetLength(AManifestTarget.Libraries.URLs, 0);
  AManifestTarget.Libraries.Sha256 := '';

  for i := 0 to High(FEntries) do
  begin
    if SameText(FEntries[i].Target, ATarget) then
    begin
      AManifestTarget.Name := FEntries[i].Target;
      SetLength(AManifestTarget.Libraries.URLs, Length(FEntries[i].URLs));
      if Length(FEntries[i].URLs) > 0 then
        AManifestTarget.Libraries.URLs := Copy(FEntries[i].URLs, 0, Length(FEntries[i].URLs));
      AManifestTarget.Libraries.Sha256 := FEntries[i].SHA256;
      Result := True;
      Exit;
    end;
  end;
end;

function TCrossToolchainManifest.GetBinutilsForHost(
  const AManifestTarget: TCrossManifestTarget;
  const {%H-} AHostPlatform: string;
  out ABinutils: TCrossBinutils
): Boolean;
var
  i: Integer;
begin
  Result := False;
  if AHostPlatform <> '' then;
  // Initialize managed type fields
  ABinutils := Default(TCrossBinutils);

  // Find the entry for this target
  for i := 0 to High(FEntries) do
  begin
    if SameText(FEntries[i].Target, AManifestTarget.Name) and
       SameText(FEntries[i].ComponentType, 'binutils') then
    begin
      SetLength(ABinutils.URLs, Length(FEntries[i].URLs));
      if Length(FEntries[i].URLs) > 0 then
        ABinutils.URLs := Copy(FEntries[i].URLs, 0, Length(FEntries[i].URLs));
      ABinutils.Sha256 := FEntries[i].SHA256;
      Result := True;
      Exit;
    end;
  end;
end;

end.
