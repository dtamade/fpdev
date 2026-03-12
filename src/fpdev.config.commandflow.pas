unit fpdev.config.commandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.intf;

procedure WriteConfigHelp(const Ctx: IContext);
procedure RunConfigShow(const Ctx: IContext);
function RunConfigGet(const AKey: string; const Ctx: IContext): Integer;
function RunConfigSet(const AKey, AValue: string; const Ctx: IContext): Integer;
function RunConfigExport(const AFilePath: string; const Ctx: IContext): Integer;
function RunConfigImport(const AFilePath: string; const Ctx: IContext): Integer;

implementation

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.help.details.system,
  fpdev.system.view,
  fpdev.config.interfaces, fpdev.config.managers,
  fpdev.paths, fpdev.exitcodes;

procedure WriteConfigHelp(const Ctx: IContext);
begin
  WriteSystemConfigHelpCore(Ctx);
end;

procedure RunConfigShow(const Ctx: IContext);
var
  ConfigManager: IConfigManager;
  Settings: TFPDevSettings;
  Lines: TStringArray;
  Line: string;
begin
  ConfigManager := TConfigManager.Create(GetConfigPath);
  ConfigManager.LoadConfig;

  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Lines := BuildSystemConfigShowLinesCore(
    Settings.Mirror,
    Settings.CustomRepoURL,
    IntToStr(Settings.ParallelJobs),
    BoolToStr(Settings.KeepSources, 'true', 'false'),
    BoolToStr(Settings.AutoUpdate, 'true', 'false'),
    GetConfigPath,
    Settings.InstallRoot,
    GetToolchainsDir,
    GetDataRoot + PathDelim + 'resources'
  );
  for Line in Lines do
    Ctx.Out.WriteLn(Line);
end;

function RunConfigGet(const AKey: string; const Ctx: IContext): Integer;
var
  ConfigManager: IConfigManager;
  Settings: TFPDevSettings;
  Value: string;
begin
  Result := EXIT_OK;
  ConfigManager := TConfigManager.Create(GetConfigPath);
  ConfigManager.LoadConfig;
  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Value := '';

  if SameText(AKey, 'mirror') then
    Value := Settings.Mirror
  else if SameText(AKey, 'custom_repo_url') then
    Value := Settings.CustomRepoURL
  else if SameText(AKey, 'parallel_jobs') then
    Value := IntToStr(Settings.ParallelJobs)
  else if SameText(AKey, 'auto_update') then
    Value := BoolToStr(Settings.AutoUpdate, 'true', 'false')
  else if SameText(AKey, 'keep_sources') then
    Value := BoolToStr(Settings.KeepSources, 'true', 'false')
  else if SameText(AKey, 'install_root') then
    Value := Settings.InstallRoot
  else if SameText(AKey, 'default_repo') then
    Value := Settings.DefaultRepo
  else
  begin
    Ctx.Err.WriteLn('Error: Unknown configuration key: ' + AKey);
    Ctx.Err.WriteLn('Run "fpdev system config show" to see available keys.');
    Exit(EXIT_USAGE_ERROR);
  end;

  Ctx.Out.WriteLn(Value);
end;

function RunConfigSet(const AKey, AValue: string; const Ctx: IContext): Integer;
var
  ConfigManager: IConfigManager;
  Settings: TFPDevSettings;
begin
  Result := EXIT_OK;
  ConfigManager := TConfigManager.Create(GetConfigPath);
  ConfigManager.LoadConfig;
  Settings := ConfigManager.GetSettingsManager.GetSettings;

  if SameText(AKey, 'mirror') then
  begin
    if not (SameText(AValue, 'auto') or SameText(AValue, 'github') or
            SameText(AValue, 'gitee') or (Pos('://', AValue) > 0)) then
    begin
      Ctx.Err.WriteLn('Error: Invalid mirror value: ' + AValue);
      Ctx.Err.WriteLn('Valid values: auto, github, gitee, or a custom URL');
      Exit(EXIT_USAGE_ERROR);
    end;
    Settings.Mirror := AValue;
  end
  else if SameText(AKey, 'custom_repo_url') then
    Settings.CustomRepoURL := AValue
  else if SameText(AKey, 'parallel_jobs') then
  begin
    Settings.ParallelJobs := StrToIntDef(AValue, 2);
    if Settings.ParallelJobs < 1 then
      Settings.ParallelJobs := 1;
  end
  else if SameText(AKey, 'auto_update') then
    Settings.AutoUpdate := SameText(AValue, 'true') or SameText(AValue, '1') or
                           SameText(AValue, 'yes') or SameText(AValue, 'on')
  else if SameText(AKey, 'keep_sources') then
    Settings.KeepSources := SameText(AValue, 'true') or SameText(AValue, '1') or
                            SameText(AValue, 'yes') or SameText(AValue, 'on')
  else if SameText(AKey, 'install_root') then
    Settings.InstallRoot := AValue
  else
  begin
    Ctx.Err.WriteLn('Error: Unknown or read-only configuration key: ' + AKey);
    Ctx.Err.WriteLn('Run "fpdev system config show" to see available keys.');
    Exit(EXIT_USAGE_ERROR);
  end;

  ConfigManager.GetSettingsManager.SetSettings(Settings);
  ConfigManager.SaveConfig;
  Ctx.Out.WriteLn('Configuration updated: ' + AKey + ' = ' + AValue);
end;

function RunConfigExport(const AFilePath: string; const Ctx: IContext): Integer;
var
  SrcPath: string;
  SL: TStringList;
begin
  Result := EXIT_OK;
  SrcPath := GetConfigPath;
  if not FileExists(SrcPath) then
  begin
    Ctx.Err.WriteLn('Error: Configuration file not found: ' + SrcPath);
    Exit(EXIT_IO_ERROR);
  end;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(SrcPath);
    SL.SaveToFile(AFilePath);
    Ctx.Out.WriteLn('Configuration exported to: ' + AFilePath);
  finally
    SL.Free;
  end;
end;

function RunConfigImport(const AFilePath: string; const Ctx: IContext): Integer;
var
  DestPath: string;
  SL: TStringList;
  J: TJSONData;
begin
  Result := EXIT_OK;
  if not FileExists(AFilePath) then
  begin
    Ctx.Err.WriteLn('Error: File not found: ' + AFilePath);
    Exit(EXIT_IO_ERROR);
  end;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(AFilePath);
    try
      J := GetJSON(SL.Text);
      J.Free;
    except
      on E: Exception do
      begin
        Ctx.Err.WriteLn('Error: Invalid JSON format: ' + E.Message);
        Exit(EXIT_USAGE_ERROR);
      end;
    end;

    DestPath := GetConfigPath;
    SL.SaveToFile(DestPath);
    Ctx.Out.WriteLn('Configuration imported from: ' + AFilePath);
  finally
    SL.Free;
  end;
end;

end.
