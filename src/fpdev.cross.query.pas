unit fpdev.cross.query;

{
================================================================================
  fpdev.cross.query - Cross-compilation Target Query Helper
================================================================================

  Provides target query operations extracted from TCrossCompilerManager:
  - GetAvailableTargets: List all available cross-compilation targets
  - GetInstalledTargets: List installed targets
  - GetTargetInfo: Get detailed target information

  Extracted from fpdev.cmd.cross.pas to reduce file size.

  Author: FPDev Team
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config.interfaces, fpdev.cross.targets, fpdev.cross.platform,
  fpdev.resource.repo, fpdev.resource.repo.types;

type
  { TCrossTargetQueryInfo - Query result record }
  TCrossTargetQueryInfo = record
    Platform: TCrossTargetPlatform;
    Name: string;
    DisplayName: string;
    CPU: string;
    OS: string;
    BinutilsPrefix: string;
    LibrariesURL: string;
    BinutilsURL: string;
    Available: Boolean;
    Installed: Boolean;
  end;

  TCrossTargetQueryArray = array of TCrossTargetQueryInfo;

  { TCrossTargetQuery - Target query helper }
  TCrossTargetQuery = class
  private
    FConfigManager: IConfigManager;
    FResourceRepo: TResourceRepository;
    FInstallRoot: string;
  public
    constructor Create(AConfigManager: IConfigManager; AResourceRepo: TResourceRepository; const AInstallRoot: string);

    { Check if target is installed and enabled }
    function IsTargetInstalled(const ATarget: string): Boolean;

    { Query all available targets from registry or repo }
    function GetAvailableTargets: TCrossTargetQueryArray;

    { Query only installed targets }
    function GetInstalledTargets: TCrossTargetQueryArray;

    { Get detailed info for a specific target }
    function GetTargetInfo(const ATarget: string): TCrossTargetQueryInfo;

    { Validate if target is supported }
    function ValidateTarget(const ATarget: string): Boolean;

    { Get installation path for target }
    function GetTargetInstallPath(const ATarget: string): string;
  end;

implementation

{ TCrossTargetQuery }

constructor TCrossTargetQuery.Create(
  AConfigManager: IConfigManager;
  AResourceRepo: TResourceRepository;
  const AInstallRoot: string
);
begin
  inherited Create;
  FConfigManager := AConfigManager;
  FResourceRepo := AResourceRepo;
  FInstallRoot := AInstallRoot;
end;

function TCrossTargetQuery.GetTargetInstallPath(const ATarget: string): string;
begin
  Result := FInstallRoot + PathDelim + 'cross' + PathDelim + ATarget;
end;

function TCrossTargetQuery.IsTargetInstalled(const ATarget: string): Boolean;
var
  CrossTarget: TCrossTarget;
begin
  Result := FConfigManager.GetCrossTargetManager.GetCrossTarget(ATarget, CrossTarget) and CrossTarget.Enabled;
end;

function TCrossTargetQuery.ValidateTarget(const ATarget: string): Boolean;
var
  LRegistry: TCrossTargetRegistry;
begin
  LRegistry := TCrossTargetRegistry.Create;
  try
    LRegistry.LoadBuiltinTargets;
    Result := LRegistry.HasTarget(ATarget);
  finally
    LRegistry.Free;
  end;
end;

function TCrossTargetQuery.GetTargetInfo(const ATarget: string): TCrossTargetQueryInfo;
var
  LRegistry: TCrossTargetRegistry;
  LDef: TCrossTargetDef;
begin
  System.Initialize(Result);
  LRegistry := TCrossTargetRegistry.Create;
  try
    LRegistry.LoadBuiltinTargets;
    if LRegistry.GetTarget(ATarget, LDef) then
    begin
      Result.Platform := StringToPlatform(LDef.Name);
      Result.Name := LDef.Name;
      Result.DisplayName := LDef.DisplayName;
      Result.CPU := LDef.CPU;
      Result.OS := LDef.OS;
      Result.BinutilsPrefix := LDef.BinutilsPrefix;
      Result.Available := True;
      Result.Installed := IsTargetInstalled(ATarget);
    end;
  finally
    LRegistry.Free;
  end;
end;

function TCrossTargetQuery.GetAvailableTargets: TCrossTargetQueryArray;
var
  i: Integer;
  RepoTargets: SysUtils.TStringArray;
  RepoInfo: TCrossToolchainInfo;
  HostPlatform: string;
  LRegistry: TCrossTargetRegistry;
  LRegDefs: TCrossTargetDefArray;
begin
  Result := nil;

  // First try to get targets from fpdev-repo
  if Assigned(FResourceRepo) then
  begin
    RepoTargets := FResourceRepo.ListCrossTargets;
    HostPlatform := GetCurrentPlatform;

    if Length(RepoTargets) > 0 then
    begin
      SetLength(Result, Length(RepoTargets));
      for i := 0 to High(RepoTargets) do
      begin
        Result[i].Platform := StringToPlatform(RepoTargets[i]);
        Result[i].Name := RepoTargets[i];
        Result[i].Available := FResourceRepo.HasCrossToolchain(RepoTargets[i], HostPlatform);
        Result[i].Installed := IsTargetInstalled(RepoTargets[i]);

        // Get detailed info from fpdev-repo
        if FResourceRepo.GetCrossToolchainInfo(RepoTargets[i], HostPlatform, RepoInfo) then
        begin
          Result[i].DisplayName := RepoInfo.DisplayName;
          Result[i].CPU := RepoInfo.CPU;
          Result[i].OS := RepoInfo.OS;
          Result[i].BinutilsPrefix := RepoInfo.BinutilsPrefix;
        end
        else
        begin
          // Fallback to built-in info
          Result[i].DisplayName := RepoTargets[i];
          Result[i].CPU := '';
          Result[i].OS := '';
          Result[i].BinutilsPrefix := '';
        end;
      end;
      Exit;
    end;
  end;

  // Fallback to target registry (replaces hardcoded CROSS_TARGETS)
  begin
    LRegistry := TCrossTargetRegistry.Create;
    try
      LRegistry.LoadBuiltinTargets;
      LRegDefs := LRegistry.ListTargetDefs;
      SetLength(Result, Length(LRegDefs));
      for i := 0 to High(LRegDefs) do
      begin
        Result[i].Platform := StringToPlatform(LRegDefs[i].Name);
        Result[i].Name := LRegDefs[i].Name;
        Result[i].DisplayName := LRegDefs[i].DisplayName;
        Result[i].CPU := LRegDefs[i].CPU;
        Result[i].OS := LRegDefs[i].OS;
        Result[i].BinutilsPrefix := LRegDefs[i].BinutilsPrefix;
        Result[i].LibrariesURL := '';
        Result[i].BinutilsURL := '';
        Result[i].Available := True;
        Result[i].Installed := IsTargetInstalled(LRegDefs[i].Name);
      end;
    finally
      LRegistry.Free;
    end;
  end;
end;

function TCrossTargetQuery.GetInstalledTargets: TCrossTargetQueryArray;
var
  AllTargets: TCrossTargetQueryArray;
  i, Count: Integer;
begin
  Result := nil;
  AllTargets := GetAvailableTargets;
  Count := 0;

  // Count installed targets
  for i := 0 to High(AllTargets) do
    if AllTargets[i].Installed then
      Inc(Count);

  // Create result array
  SetLength(Result, Count);
  Count := 0;

  for i := 0 to High(AllTargets) do
  begin
    if AllTargets[i].Installed then
    begin
      Result[Count] := AllTargets[i];
      Inc(Count);
    end;
  end;
end;

end.
