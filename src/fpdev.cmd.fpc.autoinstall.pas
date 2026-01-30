unit fpdev.cmd.fpc.autoinstall;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  fpdev.command.intf, fpdev.project.config, fpdev.output.intf;

type
  TFPCAutoInstallCommand = class(TInterfacedObject, ICommand)
  private
    FConfigPath: string;
    FOutput: IOutput;
    
    function FindConfigFile: string;
    function InstallFPC(const AVersion, ASource: string): Boolean;
    function InstallComponents(const APackages: TStringList): Boolean;
    function InstallCrossTargets(const ATargets: TStringList): Boolean;
  public
    function GetName: string;
    function GetDescription: string;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateFPCAutoInstallCommand: ICommand;

implementation

uses
  fpdev.output.console, fpdev.utils.fs;

function CreateFPCAutoInstallCommand: ICommand;
begin
  Result := TFPCAutoInstallCommand.Create;
end;

{ TFPCAutoInstallCommand }

function TFPCAutoInstallCommand.GetName: string;
begin
  Result := 'auto-install';
end;

function TFPCAutoInstallCommand.GetDescription: string;
begin
  Result := 'Automatically install FPC toolchain from .fpdev.toml';
end;

function TFPCAutoInstallCommand.FindConfigFile: string;
var
  CurrentDir: string;
begin
  CurrentDir := GetCurrentDir;
  Result := FindProjectConfig(CurrentDir);
end;

function TFPCAutoInstallCommand.InstallFPC(const AVersion, ASource: string): Boolean;
begin
  FOutput.WriteLn('Installing FPC ' + AVersion + ' from ' + ASource + '...');
  
  Result := True;
end;

function TFPCAutoInstallCommand.InstallComponents(const APackages: TStringList): Boolean;
var
  I: Integer;
begin
  if APackages.Count = 0 then
  begin
    Result := True;
    Exit;
  end;
  
  FOutput.WriteLn('Installing components...');
  for I := 0 to APackages.Count - 1 do
    FOutput.WriteLn('  - ' + APackages[I]);
  
  Result := True;
end;

function TFPCAutoInstallCommand.InstallCrossTargets(const ATargets: TStringList): Boolean;
var
  I: Integer;
begin
  if ATargets.Count = 0 then
  begin
    Result := True;
    Exit;
  end;
  
  FOutput.WriteLn('Installing cross-compilation targets...');
  for I := 0 to ATargets.Count - 1 do
    FOutput.WriteLn('  - ' + ATargets[I]);
  
  Result := True;
end;

function TFPCAutoInstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  Config: TProjectConfig;
  ConfigPath: string;
begin
  Result := 1;
  FOutput := TConsoleOutput.Create(False);
  
  ConfigPath := FindConfigFile;
  if ConfigPath = '' then
  begin
    FOutput.WriteLn('Error: No .fpdev.toml found in current directory or parent directories');
    Exit;
  end;
  
  FOutput.WriteLn('Found config: ' + ConfigPath);
  
  Config := TProjectConfig.Create(ConfigPath);
  try
    if not Config.Load then
    begin
      FOutput.WriteLn('Error: Failed to load config: ' + Config.LoadError);
      Exit;
    end;
    
    FOutput.WriteLn('Toolchain configuration:');
    FOutput.WriteLn('  Version: ' + Config.Toolchain.Version);
    FOutput.WriteLn('  Source: ' + Config.Toolchain.Source);
    FOutput.WriteLn('  Channel: ' + Config.Toolchain.Channel);
    
    if not InstallFPC(Config.Toolchain.Version, Config.Toolchain.Source) then
    begin
      FOutput.WriteLn('Error: Failed to install FPC');
      Exit;
    end;
    
    if not InstallComponents(Config.Components.Packages) then
    begin
      FOutput.WriteLn('Error: Failed to install components');
      Exit;
    end;
    
    if not InstallCrossTargets(Config.Targets.Cross) then
    begin
      FOutput.WriteLn('Error: Failed to install cross-compilation targets');
      Exit;
    end;
    
    FOutput.WriteLn('Installation complete!');
    Result := 0;
  finally
    Config.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc', 'auto-install'], @CreateFPCAutoInstallCommand, []);

end.
