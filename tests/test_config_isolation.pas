unit test_config_isolation;

{$mode objfpc}{$H+}

interface

uses
  fpdev.config.interfaces;

procedure UseIsolatedDefaultConfigPath(const ATestName: string = '');
procedure CleanupIsolatedDefaultConfigPath;
function GetIsolatedDefaultConfigPath: string;
function CreateIsolatedConfigManager: IConfigManager;

implementation

uses
  SysUtils, fpdev.config.managers, test_temp_paths;

var
  GIsolatedConfigPath: string = '';

function BuildIsolatedConfigPath(const ATestName: string): string;
var
  TestName: string;
begin
  TestName := ATestName;
  if TestName = '' then
    TestName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');

  Result := CreateUniqueTempDir(TestName + '-config') + PathDelim + 'config.json';
end;

procedure UseIsolatedDefaultConfigPath(const ATestName: string);
var
  ConfigDir: string;
begin
  CleanupIsolatedDefaultConfigPath;
  GIsolatedConfigPath := BuildIsolatedConfigPath(ATestName);
  ConfigDir := ExtractFileDir(GIsolatedConfigPath);
  if (ConfigDir <> '') and (not DirectoryExists(ConfigDir)) then
    ForceDirectories(ConfigDir);
  SetDefaultConfigPathOverride(GIsolatedConfigPath);
end;

procedure CleanupIsolatedDefaultConfigPath;
var
  ConfigDir: string;
begin
  ClearDefaultConfigPathOverride;
  if GIsolatedConfigPath = '' then
    Exit;

  ConfigDir := ExtractFileDir(GIsolatedConfigPath);
  if (ConfigDir <> '') and DirectoryExists(ConfigDir) then
    CleanupTempDir(ConfigDir);
  GIsolatedConfigPath := '';
end;

function GetIsolatedDefaultConfigPath: string;
begin
  Result := GIsolatedConfigPath;
end;

function CreateIsolatedConfigManager: IConfigManager;
begin
  Result := TConfigManager.Create('');
  if not Result.LoadConfig then
    Result.CreateDefaultConfig;
end;

initialization
  UseIsolatedDefaultConfigPath;

finalization
  CleanupIsolatedDefaultConfigPath;

end.
