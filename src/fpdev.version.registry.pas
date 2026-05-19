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
// acq:allow-hardcoded-constants-file

interface

uses
  SysUtils, Classes, fpdev.constants;

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

    procedure ApplyOverrides;

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
  fpjson, jsonparser,
  fpdev.paths, fpdev.version.registry.loadflow;

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
  LoadData: TVersionRegistryLoadData;
  ResolvedPath: string;
  ExeDir: string;
begin
  ExeDir := ExtractFileDir(ParamStr(0));
  InitVersionRegistryLoadData(LoadData);
  try
    Result := TryLoadVersionRegistryDataCore(
      FDataPath,
      ExeDir,
      GetDataRoot,
      ResolvedPath,
      LoadData
    );
    if not Result then
      Exit;

    FSchemaVersion := LoadData.SchemaVersion;
    FUpdatedAt := LoadData.UpdatedAt;
    FFPCReleases := Copy(LoadData.FPCReleases, 0, Length(LoadData.FPCReleases));
    FFPCDefaultVersion := LoadData.FPCDefaultVersion;
    FFPCRepository := LoadData.FPCRepository;
    FLazarusReleases := Copy(LoadData.LazarusReleases, 0, Length(LoadData.LazarusReleases));
    FLazarusDefaultVersion := LoadData.LazarusDefaultVersion;
    FLazarusRepository := LoadData.LazarusRepository;
    FBootstrapMap.Assign(LoadData.BootstrapMap);
    FBootstrapFallbackChain.Assign(LoadData.BootstrapFallbackChain);

    if ResolvedPath <> '' then
      FDataPath := ResolvedPath;

    FLoaded := True;
    ApplyOverrides;
  finally
    DoneVersionRegistryLoadData(LoadData);
  end;
end;

procedure TVersionRegistry.ApplyOverrides;
var
  OverridesPath: string;
  SL: TStringList;
  J: TJSONData;
  Root, FPCObj, Versions, Entry: TJSONObject;
  I, K, Idx: Integer;
  Key: string;
  NewRelease: TFPCReleaseInfo;
begin
  OverridesPath := IncludeTrailingPathDelimiter(GetDataRoot) + 'overrides.json';
  if not FileExists(OverridesPath) then Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(OverridesPath);
    try
      J := GetJSON(SL.Text);
    except
      Exit;
    end;
  finally
    SL.Free;
  end;

  if (J = nil) or (J.JSONType <> jtObject) then
  begin
    J.Free;
    Exit;
  end;

  Root := TJSONObject(J);
  try
    if Root.Find('fpc') = nil then Exit;
    if Root.Find('fpc').JSONType <> jtObject then Exit;
    FPCObj := Root.Objects['fpc'];

    if FPCObj.Find('versions') = nil then Exit;
    if FPCObj.Find('versions').JSONType <> jtObject then Exit;
    Versions := FPCObj.Objects['versions'];

    for I := 0 to Versions.Count - 1 do
    begin
      Key := Versions.Names[I];
      if Versions.Items[I].JSONType <> jtObject then Continue;
      Entry := TJSONObject(Versions.Items[I]);

      Idx := -1;
      for K := 0 to High(FFPCReleases) do
        if SameText(FFPCReleases[K].Version, Key) then
        begin
          Idx := K;
          Break;
        end;

      NewRelease := Default(TFPCReleaseInfo);
      NewRelease.Version := Key;
      NewRelease.ReleaseDate := Entry.Get('release_date', 'custom');
      NewRelease.GitTag := Entry.Get('ref', Key);
      NewRelease.Branch := Entry.Get('branch', '');
      NewRelease.Channel := Entry.Get('channel', 'custom');
      NewRelease.LTS := False;

      if Idx >= 0 then
        FFPCReleases[Idx] := NewRelease
      else
      begin
        SetLength(FFPCReleases, Length(FFPCReleases) + 1);
        FFPCReleases[High(FFPCReleases)] := NewRelease;
      end;
    end;
  finally
    Root.Free;
  end;
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
