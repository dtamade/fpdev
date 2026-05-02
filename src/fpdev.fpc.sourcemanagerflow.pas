unit fpdev.fpc.sourcemanagerflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.build.manager;

const
  FPC_SOURCE_MANAGER_ACTION_BUILD_COMPILER = 1;
  FPC_SOURCE_MANAGER_ACTION_BUILD_RTL = 2;
  FPC_SOURCE_MANAGER_ACTION_BUILD_PACKAGES = 3;
  FPC_SOURCE_MANAGER_ACTION_INSTALL_BINARIES = 4;
  FPC_SOURCE_MANAGER_ACTION_CONFIGURE_ENVIRONMENT = 5;
  FPC_SOURCE_MANAGER_ACTION_TEST_RESULTS = 6;

type
  TFPCSourceBuildManagerFactoryFunc = function(
    const AAllowInstall: Boolean
  ): TBuildManager of object;

  TFPCSourceBuildManagerDispatchFunc = function(
    ABuildManager: TBuildManager;
    AAction: Integer;
    const AVersion: string
  ): Boolean of object;

function ExecuteFPCSourceBuildManagerBridgeCore(
  const AVersion: string;
  const AAllowInstall: Boolean;
  const AAction: Integer;
  ACreateBuildManager: TFPCSourceBuildManagerFactoryFunc;
  ADispatchAction: TFPCSourceBuildManagerDispatchFunc
): Boolean;

function WriteFPCSourceCacheMarkerCore(
  const ASourceRoot, AVersion: string;
  const ABuiltAt: TDateTime
): Boolean;

implementation

function ExecuteFPCSourceBuildManagerBridgeCore(
  const AVersion: string;
  const AAllowInstall: Boolean;
  const AAction: Integer;
  ACreateBuildManager: TFPCSourceBuildManagerFactoryFunc;
  ADispatchAction: TFPCSourceBuildManagerDispatchFunc
): Boolean;
var
  BuildManager: TBuildManager;
begin
  Result := False;
  if (not Assigned(ACreateBuildManager)) or (not Assigned(ADispatchAction)) then
    Exit(False);

  BuildManager := ACreateBuildManager(AAllowInstall);
  if BuildManager = nil then
    Exit(False);

  try
    Result := ADispatchAction(BuildManager, AAction, AVersion);
  finally
    BuildManager.Free;
  end;
end;

function WriteFPCSourceCacheMarkerCore(
  const ASourceRoot, AVersion: string;
  const ABuiltAt: TDateTime
): Boolean;
var
  CacheDir: string;
  CachePath: string;
  CacheMeta: TStringList;
begin
  Result := False;
  CacheDir := IncludeTrailingPathDelimiter(ASourceRoot) + 'cache';

  try
    ForceDirectories(CacheDir);
    CachePath := CacheDir + PathDelim + 'fpc-' + AVersion + '.cache';
    CacheMeta := TStringList.Create;
    try
      CacheMeta.Add('version=' + AVersion);
      CacheMeta.Add('built_at=' + DateTimeToStr(ABuiltAt));
      CacheMeta.SaveToFile(CachePath);
      Result := True;
    finally
      CacheMeta.Free;
    end;
  except
    Result := False;
  end;
end;

end.
