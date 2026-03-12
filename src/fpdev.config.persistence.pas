unit fpdev.config.persistence;

{$mode objfpc}{$H+}

interface

uses
  fpdev.config.interfaces;

function LoadConfigFromFileCore(const AConfigPath, ADefaultVersion: string;
  AToolchainManager: IToolchainManager;
  ALazarusManager: ILazarusManager;
  ACrossTargetManager: ICrossTargetManager;
  ARepositoryManager: IRepositoryManager;
  ASettingsManager: ISettingsManager;
  out AVersion: string): Boolean;
function SaveConfigToFileCore(const AConfigPath, AVersion: string;
  AToolchainManager: IToolchainManager;
  ALazarusManager: ILazarusManager;
  ACrossTargetManager: ICrossTargetManager;
  ARepositoryManager: IRepositoryManager;
  ASettingsManager: ISettingsManager): Boolean;

implementation

uses
  SysUtils, Classes, fpjson, jsonparser;

function LoadConfigFromFileCore(const AConfigPath, ADefaultVersion: string;
  AToolchainManager: IToolchainManager;
  ALazarusManager: ILazarusManager;
  ACrossTargetManager: ICrossTargetManager;
  ARepositoryManager: IRepositoryManager;
  ASettingsManager: ISettingsManager;
  out AVersion: string): Boolean;
var
  JSONStr: string;
  JSONData: TJSONData;
  ConfigJSON: TJSONObject;
  ConfigText: TStringList;
begin
  Result := False;
  AVersion := ADefaultVersion;

  try
    ConfigText := TStringList.Create;
    try
      ConfigText.LoadFromFile(AConfigPath);
      JSONStr := ConfigText.Text;
    finally
      ConfigText.Free;
    end;

    JSONData := GetJSON(JSONStr);
    try
      if not (JSONData is TJSONObject) then
        Exit;

      ConfigJSON := TJSONObject(JSONData);
      AVersion := ConfigJSON.Get('version', ADefaultVersion);

      AToolchainManager.LoadFromJSON(
        ConfigJSON.Objects['toolchains'],
        ConfigJSON.Get('default_toolchain', '')
      );
      ALazarusManager.LoadFromJSON(ConfigJSON.Objects['lazarus']);
      ACrossTargetManager.LoadFromJSON(ConfigJSON.Objects['cross_targets']);
      ARepositoryManager.LoadFromJSON(
        ConfigJSON.Objects['repositories'],
        ConfigJSON.Get('default_repo', '')
      );
      ASettingsManager.LoadFromJSON(ConfigJSON.Objects['settings']);

      Result := True;
    finally
      JSONData.Free;
    end;
  except
    on E: Exception do
      Result := False;
  end;
end;

function SaveConfigToFileCore(const AConfigPath, AVersion: string;
  AToolchainManager: IToolchainManager;
  ALazarusManager: ILazarusManager;
  ACrossTargetManager: ICrossTargetManager;
  ARepositoryManager: IRepositoryManager;
  ASettingsManager: ISettingsManager): Boolean;
var
  ConfigJSON: TJSONObject;
  ToolchainsJSON: TJSONObject;
  LazarusJSON: TJSONObject;
  CrossTargetsJSON: TJSONObject;
  ReposJSON: TJSONObject;
  SettingsJSON: TJSONObject;
  DefaultToolchain: string;
  DefaultRepo: string;
  ConfigText: TStringList;
begin
  Result := False;

  try
    ConfigJSON := TJSONObject.Create;
    try
      ConfigJSON.Add('version', AVersion);

      AToolchainManager.SaveToJSON(ToolchainsJSON, DefaultToolchain);
      ConfigJSON.Add('default_toolchain', DefaultToolchain);
      ConfigJSON.Add('toolchains', ToolchainsJSON);

      ALazarusManager.SaveToJSON(LazarusJSON);
      ConfigJSON.Add('lazarus', LazarusJSON);

      ACrossTargetManager.SaveToJSON(CrossTargetsJSON);
      ConfigJSON.Add('cross_targets', CrossTargetsJSON);

      ARepositoryManager.SaveToJSON(ReposJSON, DefaultRepo);
      ConfigJSON.Add('repositories', ReposJSON);

      ASettingsManager.SaveToJSON(SettingsJSON);
      ConfigJSON.Add('settings', SettingsJSON);

      ConfigText := TStringList.Create;
      try
        ConfigText.Text := ConfigJSON.FormatJSON;
        ConfigText.SaveToFile(AConfigPath);
        Result := True;
      finally
        ConfigText.Free;
      end;
    finally
      ConfigJSON.Free;
    end;
  except
    on E: Exception do
      Result := False;
  end;
end;

end.
