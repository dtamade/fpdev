unit fpdev.cmd.config;

{
================================================================================
  fpdev.cmd.config - Configuration Management Command
================================================================================

  Provides commands for managing fpdev configuration:
  - fpdev config show          - Show current configuration
  - fpdev config set <key> <value> - Set a configuration value
  - fpdev config get <key>     - Get a configuration value

  Supported configuration keys:
  - mirror: 'auto', 'github', 'gitee', or custom URL
  - custom_repo_url: Custom repository URL (highest priority)
  - parallel_jobs: Number of parallel build jobs
  - auto_update: Enable/disable auto-update
  - keep_sources: Keep source files after build

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.config.interfaces, fpdev.config.managers,
  fpdev.output.intf, fpdev.paths, fpdev.exitcodes;

type
  { TConfigCommand - Main config command handler }
  TConfigCommand = class(TInterfacedObject, ICommand)
  private
    FConfigManager: IConfigManager;
    FOut: IOutput;
    FErr: IOutput;

    procedure ShowConfig;
    procedure ShowHelp;
    procedure GetConfigValue(const AKey: string);
    procedure SetConfigValue(const AKey, AValue: string);

  public
    constructor Create(AOut: IOutput = nil; AErr: IOutput = nil);

    // ICommand interface
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const {%H-} AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
    function GetHelp: string;
  end;

function CreateConfigCommand: ICommand;

implementation

uses
  fpdev.output.console;

function CreateConfigCommand: ICommand;
begin
  Result := TConfigCommand.Create;
end;

{ TConfigCommand }

constructor TConfigCommand.Create(AOut: IOutput; AErr: IOutput);
begin
  inherited Create;
  if Assigned(AOut) then
    FOut := AOut
  else
    FOut := TConsoleOutput.Create;

  if Assigned(AErr) then
    FErr := AErr
  else
    FErr := TConsoleOutput.Create;
end;

function TConfigCommand.Name: string;
begin
  Result := 'config';
end;

function TConfigCommand.Aliases: TStringArray;
begin
  Result := nil;  // No aliases
end;

function TConfigCommand.FindSub(const {%H-} AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;  // No subcommands - handled internally
end;

procedure TConfigCommand.ShowHelp;
begin
  FOut.WriteLn('Usage: fpdev config <command> [options]');
  FOut.WriteLn('');
  FOut.WriteLn('Commands:');
  FOut.WriteLn('  show                    Show current configuration');
  FOut.WriteLn('  get <key>               Get a configuration value');
  FOut.WriteLn('  set <key> <value>       Set a configuration value');
  FOut.WriteLn('');
  FOut.WriteLn('Configuration keys:');
  FOut.WriteLn('  mirror                  Mirror source: auto, github, gitee, or custom URL');
  FOut.WriteLn('  custom_repo_url         Custom repository URL (overrides mirror)');
  FOut.WriteLn('  parallel_jobs           Number of parallel build jobs');
  FOut.WriteLn('  auto_update             Enable auto-update: true/false');
  FOut.WriteLn('  keep_sources            Keep source files: true/false');
  FOut.WriteLn('');
  FOut.WriteLn('Examples:');
  FOut.WriteLn('  fpdev config show');
  FOut.WriteLn('  fpdev config set mirror gitee');
  FOut.WriteLn('  fpdev config set mirror github');
  FOut.WriteLn('  fpdev config set custom_repo_url https://my-server.com/fpdev-repo.git');
  FOut.WriteLn('  fpdev config get mirror');
end;

procedure TConfigCommand.ShowConfig;
var
  Settings: TFPDevSettings;
begin
  FConfigManager := TConfigManager.Create(GetConfigPath);
  FConfigManager.LoadConfig;

  Settings := FConfigManager.GetSettingsManager.GetSettings;

  FOut.WriteLn('FPDev Configuration');
  FOut.WriteLn('===================');
  FOut.WriteLn('');
  FOut.WriteLn('Mirror Settings:');
  FOut.WriteLn('  mirror:           ' + Settings.Mirror);
  FOut.WriteLn('  custom_repo_url:  ' + Settings.CustomRepoURL);
  FOut.WriteLn('');
  FOut.WriteLn('Build Settings:');
  FOut.WriteLn('  parallel_jobs:    ' + IntToStr(Settings.ParallelJobs));
  FOut.WriteLn('  keep_sources:     ' + BoolToStr(Settings.KeepSources, 'true', 'false'));
  FOut.WriteLn('');
  FOut.WriteLn('Update Settings:');
  FOut.WriteLn('  auto_update:      ' + BoolToStr(Settings.AutoUpdate, 'true', 'false'));
  FOut.WriteLn('');
  FOut.WriteLn('Paths:');
  FOut.WriteLn('  config_file:      ' + GetConfigPath);
  FOut.WriteLn('  install_root:     ' + Settings.InstallRoot);
  FOut.WriteLn('  toolchains_dir:   ' + GetToolchainsDir);
  FOut.WriteLn('  resources_dir:    ' + GetDataRoot + PathDelim + 'resources');
end;

procedure TConfigCommand.GetConfigValue(const AKey: string);
var
  Settings: TFPDevSettings;
  Value: string;
begin
  FConfigManager := TConfigManager.Create(GetConfigPath);
  FConfigManager.LoadConfig;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
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
    FErr.WriteLn('Error: Unknown configuration key: ' + AKey);
    FErr.WriteLn('Run "fpdev config show" to see available keys.');
    Exit;
  end;

  FOut.WriteLn(Value);
end;

procedure TConfigCommand.SetConfigValue(const AKey, AValue: string);
var
  Settings: TFPDevSettings;
begin
  FConfigManager := TConfigManager.Create(GetConfigPath);
  FConfigManager.LoadConfig;

  Settings := FConfigManager.GetSettingsManager.GetSettings;

  if SameText(AKey, 'mirror') then
  begin
    // Validate mirror value
    if not (SameText(AValue, 'auto') or SameText(AValue, 'github') or
            SameText(AValue, 'gitee') or (Pos('://', AValue) > 0)) then
    begin
      FErr.WriteLn('Error: Invalid mirror value: ' + AValue);
      FErr.WriteLn('Valid values: auto, github, gitee, or a custom URL');
      Exit;
    end;
    Settings.Mirror := AValue;
  end
  else if SameText(AKey, 'custom_repo_url') then
  begin
    Settings.CustomRepoURL := AValue;
  end
  else if SameText(AKey, 'parallel_jobs') then
  begin
    Settings.ParallelJobs := StrToIntDef(AValue, 2);
    if Settings.ParallelJobs < 1 then
      Settings.ParallelJobs := 1;
  end
  else if SameText(AKey, 'auto_update') then
  begin
    Settings.AutoUpdate := SameText(AValue, 'true') or SameText(AValue, '1') or
                           SameText(AValue, 'yes') or SameText(AValue, 'on');
  end
  else if SameText(AKey, 'keep_sources') then
  begin
    Settings.KeepSources := SameText(AValue, 'true') or SameText(AValue, '1') or
                            SameText(AValue, 'yes') or SameText(AValue, 'on');
  end
  else if SameText(AKey, 'install_root') then
  begin
    Settings.InstallRoot := AValue;
  end
  else
  begin
    FErr.WriteLn('Error: Unknown or read-only configuration key: ' + AKey);
    FErr.WriteLn('Run "fpdev config show" to see available keys.');
    Exit;
  end;

  FConfigManager.GetSettingsManager.SetSettings(Settings);
  FConfigManager.SaveConfig;

  FOut.WriteLn('Configuration updated: ' + AKey + ' = ' + AValue);
end;

function TConfigCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  SubCommand: string;
begin
  Result := 0;

  // Use Ctx.Out/Err if available (replaces constructor-injected FOut/FErr)
  if Assigned(Ctx) then
  begin
    if Assigned(Ctx.Out) then
      FOut := Ctx.Out;
    if Assigned(Ctx.Err) then
      FErr := Ctx.Err;
  end;

  if Length(AParams) = 0 then
  begin
    ShowHelp;
    Exit;
  end;

  SubCommand := LowerCase(AParams[0]);

  if (SubCommand = 'help') or (SubCommand = '-h') or (SubCommand = '--help') then
  begin
    ShowHelp;
  end
  else if SubCommand = 'show' then
  begin
    ShowConfig;
  end
  else if SubCommand = 'get' then
  begin
    if Length(AParams) < 2 then
    begin
      FErr.WriteLn('Error: Missing key argument');
      FErr.WriteLn('Usage: fpdev config get <key>');
      Result := EXIT_USAGE_ERROR;
      Exit;
    end;
    GetConfigValue(AParams[1]);
  end
  else if SubCommand = 'set' then
  begin
    if Length(AParams) < 3 then
    begin
      FErr.WriteLn('Error: Missing key or value argument');
      FErr.WriteLn('Usage: fpdev config set <key> <value>');
      Result := EXIT_USAGE_ERROR;
      Exit;
    end;
    SetConfigValue(AParams[1], AParams[2]);
  end
  else
  begin
    FErr.WriteLn('Error: Unknown subcommand: ' + SubCommand);
    ShowHelp;
    Result := EXIT_USAGE_ERROR;
  end;
end;

function TConfigCommand.GetHelp: string;
begin
  Result := 'Manage fpdev configuration settings';
end;

initialization
  GlobalCommandRegistry.RegisterPath(['config'], @CreateConfigCommand, []);

end.
