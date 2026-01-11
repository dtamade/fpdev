unit fpdev.version.registry;

{
================================================================================
  fpdev.version.registry - Version Registry Service
================================================================================

  Provides centralized version information management:
  - Load version data from external JSON file (data/versions.json)
  - Query FPC/Lazarus release information
  - Bootstrap compiler version mapping
  - Fallback to embedded defaults if external file unavailable

  This replaces hardcoded version arrays scattered across the codebase.

  Usage:
    Registry := TVersionRegistry.Instance;
    Versions := Registry.GetFPCReleases;
    BootstrapVer := Registry.GetBootstrapVersion('3.2.2');

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser;

type
  { TFPCReleaseInfo - FPC version release information }
  TFPCReleaseInfo = record
    Version: string;
    ReleaseDate: string;
    GitTag: string;
    Branch: string;
    Channel: string;      // stable, legacy, development
    LTS: Boolean;
  end;
  TFPCReleaseArray = array of TFPCReleaseInfo;

  { TLazarusReleaseInfo - Lazarus version release information }
  TLazarusReleaseInfo = record
    Version: string;
    ReleaseDate: string;
    GitTag: string;
    Branch: string;
    FPCCompatible: array of string;
    Channel: string;
  end;
  TLazarusReleaseArray = array of TLazarusReleaseInfo;

  { TVersionRegistry - Singleton version registry }
  TVersionRegistry = class
  private
    class var FInstance: TVersionRegistry;
    class var FInstanceLock: TRTLCriticalSection;
  private
    FLoaded: Boolean;
    FDataPath: string;
    FSchemaVersion: string;
    FUpdatedAt: string;

    // FPC data
    FFPCReleases: TFPCReleaseArray;
    FFPCDefaultVersion: string;
    FFPCRepository: string;

    // Lazarus data
    FLazarusReleases: TLazarusReleaseArray;
    FLazarusDefaultVersion: string;
    FLazarusRepository: string;

    // Bootstrap data
    FBootstrapMap: TStringList;  // Key=TargetVersion, Value=RequiredVersion
    FBootstrapFallbackChain: TStringList;

    procedure LoadFromJSON(const APath: string);
    procedure LoadDefaults;
    procedure ParseFPCReleases(AArray: TJSONArray);
    procedure ParseLazarusReleases(AArray: TJSONArray);
    procedure ParseBootstrapMap(AObj: TJSONObject);

  public
    constructor Create;
    destructor Destroy; override;

    { Singleton instance accessor }
    class function Instance: TVersionRegistry;
    class procedure ReleaseInstance;

    { Reload data from file }
    function Reload: Boolean;

    { FPC version queries }
    function GetFPCReleases: TFPCReleaseArray;
    function GetFPCRelease(const AVersion: string): TFPCReleaseInfo;
    function IsFPCVersionValid(const AVersion: string): Boolean;
    function GetFPCDefaultVersion: string;
    function GetFPCRepository: string;
    function GetFPCGitTag(const AVersion: string): string;
    function GetFPCBranch(const AVersion: string): string;

    { Lazarus version queries }
    function GetLazarusReleases: TLazarusReleaseArray;
    function GetLazarusRelease(const AVersion: string): TLazarusReleaseInfo;
    function IsLazarusVersionValid(const AVersion: string): Boolean;
    function GetLazarusDefaultVersion: string;
    function GetLazarusRepository: string;
    function GetLazarusGitTag(const AVersion: string): string;
    function GetLazarusBranch(const AVersion: string): string;
    function GetLazarusRecommendedFPC(const AVersion: string): string;
    function IsLazarusFPCCompatible(const ALazVersion, AFPCVersion: string): Boolean;

    { Bootstrap compiler queries }
    function GetBootstrapVersion(const ATargetVersion: string): string;
    function GetBootstrapFallbackChain: TStringList;

    { Properties }
    property Loaded: Boolean read FLoaded;
    property SchemaVersion: string read FSchemaVersion;
    property UpdatedAt: string read FUpdatedAt;
    property DataPath: string read FDataPath write FDataPath;
  end;

implementation

uses
  fpdev.paths;

{ TVersionRegistry }

constructor TVersionRegistry.Create;
begin
  inherited Create;
  FLoaded := False;
  FDataPath := '';
  FBootstrapMap := TStringList.Create;
  FBootstrapMap.Sorted := True;
  FBootstrapMap.Duplicates := dupIgnore;
  FBootstrapFallbackChain := TStringList.Create;

  // Try to load from default locations
  Reload;
end;

destructor TVersionRegistry.Destroy;
begin
  FBootstrapMap.Free;
  FBootstrapFallbackChain.Free;
  inherited Destroy;
end;

class function TVersionRegistry.Instance: TVersionRegistry;
begin
  if FInstance = nil then
  begin
    EnterCriticalSection(FInstanceLock);
    try
      if FInstance = nil then
        FInstance := TVersionRegistry.Create;
    finally
      LeaveCriticalSection(FInstanceLock);
    end;
  end;
  Result := FInstance;
end;

class procedure TVersionRegistry.ReleaseInstance;
begin
  EnterCriticalSection(FInstanceLock);
  try
    FreeAndNil(FInstance);
  finally
    LeaveCriticalSection(FInstanceLock);
  end;
end;

function TVersionRegistry.Reload: Boolean;
var
  SearchPaths: array[0..3] of string;
  i: Integer;
  ExeDir: string;
begin
  Result := False;

  // Determine search paths
  ExeDir := ExtractFileDir(ParamStr(0));
  SearchPaths[0] := FDataPath;  // User-specified path
  SearchPaths[1] := ExeDir + PathDelim + 'data' + PathDelim + 'versions.json';
  SearchPaths[2] := GetDataRoot + PathDelim + 'versions.json';
  SearchPaths[3] := ExeDir + PathDelim + '..' + PathDelim + 'data' + PathDelim + 'versions.json';

  // Try each path
  for i := 0 to High(SearchPaths) do
  begin
    if (SearchPaths[i] <> '') and FileExists(SearchPaths[i]) then
    begin
      try
        LoadFromJSON(SearchPaths[i]);
        FDataPath := SearchPaths[i];
        FLoaded := True;
        Result := True;
        Exit;
      except
        // Continue to next path on error
      end;
    end;
  end;

  // Fallback to embedded defaults
  LoadDefaults;
  FLoaded := True;
  Result := True;
end;

procedure TVersionRegistry.LoadFromJSON(const APath: string);
var
  JSONText: string;
  Parser: TJSONParser;
  Root: TJSONObject;
  FPCObj, LazObj, BootstrapObj: TJSONObject;
  F: TStringList;
begin
  F := TStringList.Create;
  try
    F.LoadFromFile(APath);
    JSONText := F.Text;
  finally
    F.Free;
  end;

  Parser := TJSONParser.Create(JSONText, []);
  try
    Root := Parser.Parse as TJSONObject;
    try
      FSchemaVersion := Root.Get('schema_version', '1.0');
      FUpdatedAt := Root.Get('updated_at', '');

      // Parse FPC section
      if Root.Find('fpc') <> nil then
      begin
        FPCObj := Root.Objects['fpc'];
        FFPCDefaultVersion := FPCObj.Get('default_version', '3.2.2');
        FFPCRepository := FPCObj.Get('repository', 'https://gitlab.com/freepascal.org/fpc/source.git');
        if FPCObj.Find('releases') <> nil then
          ParseFPCReleases(FPCObj.Arrays['releases']);
      end;

      // Parse Lazarus section
      if Root.Find('lazarus') <> nil then
      begin
        LazObj := Root.Objects['lazarus'];
        FLazarusDefaultVersion := LazObj.Get('default_version', '3.6');
        FLazarusRepository := LazObj.Get('repository', 'https://gitlab.com/freepascal.org/lazarus/lazarus.git');
        if LazObj.Find('releases') <> nil then
          ParseLazarusReleases(LazObj.Arrays['releases']);
      end;

      // Parse Bootstrap section
      if Root.Find('bootstrap') <> nil then
      begin
        BootstrapObj := Root.Objects['bootstrap'];
        ParseBootstrapMap(BootstrapObj);
      end;

    finally
      Root.Free;
    end;
  finally
    Parser.Free;
  end;
end;

procedure TVersionRegistry.ParseFPCReleases(AArray: TJSONArray);
var
  i: Integer;
  Item: TJSONObject;
begin
  SetLength(FFPCReleases, AArray.Count);
  for i := 0 to AArray.Count - 1 do
  begin
    Item := AArray.Objects[i];
    FFPCReleases[i].Version := Item.Get('version', '');
    FFPCReleases[i].ReleaseDate := Item.Get('release_date', '');
    FFPCReleases[i].GitTag := Item.Get('git_tag', '');
    FFPCReleases[i].Branch := Item.Get('branch', '');
    FFPCReleases[i].Channel := Item.Get('channel', 'stable');
    FFPCReleases[i].LTS := Item.Get('lts', False);
  end;
end;

procedure TVersionRegistry.ParseLazarusReleases(AArray: TJSONArray);
var
  i, j: Integer;
  Item: TJSONObject;
  CompatArray: TJSONArray;
begin
  SetLength(FLazarusReleases, AArray.Count);
  for i := 0 to AArray.Count - 1 do
  begin
    Item := AArray.Objects[i];
    FLazarusReleases[i].Version := Item.Get('version', '');
    FLazarusReleases[i].ReleaseDate := Item.Get('release_date', '');
    FLazarusReleases[i].GitTag := Item.Get('git_tag', '');
    FLazarusReleases[i].Branch := Item.Get('branch', '');
    FLazarusReleases[i].Channel := Item.Get('channel', 'stable');

    // Parse FPC compatible versions
    if Item.Find('fpc_compatible') <> nil then
    begin
      CompatArray := Item.Arrays['fpc_compatible'];
      SetLength(FLazarusReleases[i].FPCCompatible, CompatArray.Count);
      for j := 0 to CompatArray.Count - 1 do
        FLazarusReleases[i].FPCCompatible[j] := CompatArray.Strings[j];
    end;
  end;
end;

procedure TVersionRegistry.ParseBootstrapMap(AObj: TJSONObject);
var
  MapObj: TJSONObject;
  ChainArray: TJSONArray;
  i: Integer;
begin
  FBootstrapMap.Clear;
  FBootstrapFallbackChain.Clear;

  // Parse version map
  if AObj.Find('version_map') <> nil then
  begin
    MapObj := AObj.Objects['version_map'];
    for i := 0 to MapObj.Count - 1 do
      FBootstrapMap.Values[MapObj.Names[i]] := MapObj.Items[i].AsString;
  end;

  // Parse fallback chain
  if AObj.Find('fallback_chain') <> nil then
  begin
    ChainArray := AObj.Arrays['fallback_chain'];
    for i := 0 to ChainArray.Count - 1 do
      FBootstrapFallbackChain.Add(ChainArray.Strings[i]);
  end;
end;

procedure TVersionRegistry.LoadDefaults;
begin
  // Embedded defaults - used when versions.json is not available
  FSchemaVersion := '1.0';
  FUpdatedAt := 'embedded';

  // FPC defaults
  FFPCDefaultVersion := '3.2.2';
  FFPCRepository := 'https://gitlab.com/freepascal.org/fpc/source.git';
  SetLength(FFPCReleases, 5);

  FFPCReleases[0].Version := '3.2.2';
  FFPCReleases[0].ReleaseDate := '2021-05-19';
  FFPCReleases[0].GitTag := 'release_3_2_2';
  FFPCReleases[0].Branch := 'fixes_3_2';
  FFPCReleases[0].Channel := 'stable';
  FFPCReleases[0].LTS := True;

  FFPCReleases[1].Version := '3.2.0';
  FFPCReleases[1].ReleaseDate := '2020-06-19';
  FFPCReleases[1].GitTag := 'release_3_2_0';
  FFPCReleases[1].Branch := 'fixes_3_2';
  FFPCReleases[1].Channel := 'stable';
  FFPCReleases[1].LTS := False;

  FFPCReleases[2].Version := '3.0.4';
  FFPCReleases[2].ReleaseDate := '2017-11-21';
  FFPCReleases[2].GitTag := 'release_3_0_4';
  FFPCReleases[2].Branch := 'fixes_3_0';
  FFPCReleases[2].Channel := 'legacy';
  FFPCReleases[2].LTS := False;

  FFPCReleases[3].Version := '3.3.1';
  FFPCReleases[3].ReleaseDate := 'rolling';
  FFPCReleases[3].GitTag := 'main';
  FFPCReleases[3].Branch := 'main';
  FFPCReleases[3].Channel := 'development';
  FFPCReleases[3].LTS := False;

  FFPCReleases[4].Version := 'main';
  FFPCReleases[4].ReleaseDate := 'rolling';
  FFPCReleases[4].GitTag := 'main';
  FFPCReleases[4].Branch := 'main';
  FFPCReleases[4].Channel := 'development';
  FFPCReleases[4].LTS := False;

  // Lazarus defaults
  FLazarusDefaultVersion := '3.6';
  FLazarusRepository := 'https://gitlab.com/freepascal.org/lazarus/lazarus.git';
  SetLength(FLazarusReleases, 2);

  FLazarusReleases[0].Version := '3.6';
  FLazarusReleases[0].ReleaseDate := '2024-10-14';
  FLazarusReleases[0].GitTag := 'lazarus_3_6';
  FLazarusReleases[0].Branch := 'lazarus_3_6';
  FLazarusReleases[0].Channel := 'stable';
  SetLength(FLazarusReleases[0].FPCCompatible, 2);
  FLazarusReleases[0].FPCCompatible[0] := '3.2.2';
  FLazarusReleases[0].FPCCompatible[1] := '3.2.0';

  FLazarusReleases[1].Version := 'main';
  FLazarusReleases[1].ReleaseDate := 'rolling';
  FLazarusReleases[1].GitTag := 'main';
  FLazarusReleases[1].Branch := 'main';
  FLazarusReleases[1].Channel := 'development';
  SetLength(FLazarusReleases[1].FPCCompatible, 3);
  FLazarusReleases[1].FPCCompatible[0] := '3.2.2';
  FLazarusReleases[1].FPCCompatible[1] := '3.3.1';
  FLazarusReleases[1].FPCCompatible[2] := 'main';

  // Bootstrap defaults
  FBootstrapMap.Clear;
  FBootstrapMap.Values['main'] := '3.2.2';
  FBootstrapMap.Values['3.3.1'] := '3.2.2';
  FBootstrapMap.Values['3.2.2'] := '3.2.0';
  FBootstrapMap.Values['3.2.0'] := '3.0.4';
  FBootstrapMap.Values['3.0.4'] := '3.0.2';

  FBootstrapFallbackChain.Clear;
  FBootstrapFallbackChain.Add('3.2.2');
  FBootstrapFallbackChain.Add('3.2.0');
  FBootstrapFallbackChain.Add('3.0.4');
  FBootstrapFallbackChain.Add('3.0.2');
  FBootstrapFallbackChain.Add('3.0.0');
  FBootstrapFallbackChain.Add('2.6.4');
end;

{ FPC queries }

function TVersionRegistry.GetFPCReleases: TFPCReleaseArray;
begin
  Result := FFPCReleases;
end;

function TVersionRegistry.GetFPCRelease(const AVersion: string): TFPCReleaseInfo;
var
  i: Integer;
begin
  Initialize(Result);
  for i := 0 to High(FFPCReleases) do
  begin
    if SameText(FFPCReleases[i].Version, AVersion) then
    begin
      Result := FFPCReleases[i];
      Exit;
    end;
  end;
end;

function TVersionRegistry.IsFPCVersionValid(const AVersion: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FFPCReleases) do
  begin
    if SameText(FFPCReleases[i].Version, AVersion) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TVersionRegistry.GetFPCDefaultVersion: string;
begin
  Result := FFPCDefaultVersion;
end;

function TVersionRegistry.GetFPCRepository: string;
begin
  Result := FFPCRepository;
end;

function TVersionRegistry.GetFPCGitTag(const AVersion: string): string;
var
  Info: TFPCReleaseInfo;
begin
  Info := GetFPCRelease(AVersion);
  Result := Info.GitTag;
end;

function TVersionRegistry.GetFPCBranch(const AVersion: string): string;
var
  Info: TFPCReleaseInfo;
begin
  Info := GetFPCRelease(AVersion);
  Result := Info.Branch;
end;

{ Lazarus queries }

function TVersionRegistry.GetLazarusReleases: TLazarusReleaseArray;
begin
  Result := FLazarusReleases;
end;

function TVersionRegistry.GetLazarusRelease(const AVersion: string): TLazarusReleaseInfo;
var
  i: Integer;
begin
  Initialize(Result);
  for i := 0 to High(FLazarusReleases) do
  begin
    if SameText(FLazarusReleases[i].Version, AVersion) then
    begin
      Result := FLazarusReleases[i];
      Exit;
    end;
  end;
end;

function TVersionRegistry.IsLazarusVersionValid(const AVersion: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FLazarusReleases) do
  begin
    if SameText(FLazarusReleases[i].Version, AVersion) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TVersionRegistry.GetLazarusDefaultVersion: string;
begin
  Result := FLazarusDefaultVersion;
end;

function TVersionRegistry.GetLazarusRepository: string;
begin
  Result := FLazarusRepository;
end;

function TVersionRegistry.GetLazarusGitTag(const AVersion: string): string;
var
  Info: TLazarusReleaseInfo;
begin
  Info := GetLazarusRelease(AVersion);
  Result := Info.GitTag;
end;

function TVersionRegistry.GetLazarusBranch(const AVersion: string): string;
var
  Info: TLazarusReleaseInfo;
begin
  Info := GetLazarusRelease(AVersion);
  Result := Info.Branch;
end;

function TVersionRegistry.GetLazarusRecommendedFPC(const AVersion: string): string;
var
  Info: TLazarusReleaseInfo;
begin
  Result := '3.2.2';  // Default
  Info := GetLazarusRelease(AVersion);
  if Length(Info.FPCCompatible) > 0 then
    Result := Info.FPCCompatible[0];  // First compatible version is recommended
end;

function TVersionRegistry.IsLazarusFPCCompatible(const ALazVersion, AFPCVersion: string): Boolean;
var
  Info: TLazarusReleaseInfo;
  i: Integer;
begin
  Result := False;
  Info := GetLazarusRelease(ALazVersion);
  for i := 0 to High(Info.FPCCompatible) do
  begin
    if SameText(Info.FPCCompatible[i], AFPCVersion) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

{ Bootstrap queries }

function TVersionRegistry.GetBootstrapVersion(const ATargetVersion: string): string;
begin
  Result := FBootstrapMap.Values[ATargetVersion];
  if Result = '' then
    Result := FBootstrapMap.Values[LowerCase(ATargetVersion)];
end;

function TVersionRegistry.GetBootstrapFallbackChain: TStringList;
begin
  Result := FBootstrapFallbackChain;
end;

initialization
  InitCriticalSection(TVersionRegistry.FInstanceLock);
  TVersionRegistry.FInstance := nil;

finalization
  TVersionRegistry.ReleaseInstance;
  DoneCriticalSection(TVersionRegistry.FInstanceLock);

end.
