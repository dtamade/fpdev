unit fpdev.project.config;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  fpdev.toml.parser;

type
  TToolchainConfig = record
    Version: string;
    Source: string;
    Channel: string;
  end;

  TComponentsConfig = record
    RTL: Boolean;
    FCL: Boolean;
    Packages: TStringList;
  end;

  TTargetsConfig = record
    Cross: TStringList;
  end;

  TBuildConfig = record
    Mode: string;
    Optimization: string;
    TargetCPU: string;
    CustomOptions: TStringList;
  end;

  TLazarusConfig = record
    Version: string;
    AutoConfigure: Boolean;
  end;

  TProjectMetadata = record
    Name: string;
    ProjectType: string;
    Main: string;
  end;

  TProjectConfig = class
  private
    FConfigPath: string;
    FDocument: TTOMLDocument;
    FToolchain: TToolchainConfig;
    FComponents: TComponentsConfig;
    FTargets: TTargetsConfig;
    FBuild: TBuildConfig;
    FLazarus: TLazarusConfig;
    FProject: TProjectMetadata;
    FLoadError: string;
    
    procedure InitializeDefaults;
    procedure LoadToolchainSection;
    procedure LoadComponentsSection;
    procedure LoadTargetsSection;
    procedure LoadBuildSection;
    procedure LoadLazarusSection;
    procedure LoadProjectSection;
  public
    constructor Create(const AConfigPath: string);
    destructor Destroy; override;
    
    function Load: Boolean;
    function Validate: Boolean;
    
    property ConfigPath: string read FConfigPath;
    property LoadError: string read FLoadError;
    
    property Toolchain: TToolchainConfig read FToolchain;
    property Components: TComponentsConfig read FComponents;
    property Targets: TTargetsConfig read FTargets;
    property Build: TBuildConfig read FBuild;
    property Lazarus: TLazarusConfig read FLazarus;
    property Project: TProjectMetadata read FProject;
  end;

  function FindProjectConfig(const AStartDir: string): string;

implementation

uses
  fpdev.utils.fs;

function FindProjectConfig(const AStartDir: string): string;
var
  Dir: string;
  ConfigFile: string;
begin
  Result := '';
  Dir := AStartDir;
  
  while Dir <> '' do
  begin
    ConfigFile := Dir + PathDelim + '.fpdev.toml';
    if FileExists(ConfigFile) then
    begin
      Result := ConfigFile;
      Exit;
    end;
    
    ConfigFile := Dir + PathDelim + 'fpdev.toml';
    if FileExists(ConfigFile) then
    begin
      Result := ConfigFile;
      Exit;
    end;
    
    Dir := ExtractFileDir(Dir);
    if Dir = ExtractFileDir(Dir) then
      Break;
  end;
end;

{ TProjectConfig }

constructor TProjectConfig.Create(const AConfigPath: string);
begin
  inherited Create;
  FConfigPath := AConfigPath;
  FDocument := nil;
  FLoadError := '';
  
  FComponents.Packages := TStringList.Create;
  FTargets.Cross := TStringList.Create;
  FBuild.CustomOptions := TStringList.Create;
  
  InitializeDefaults;
end;

destructor TProjectConfig.Destroy;
begin
  if Assigned(FDocument) then
    FDocument.Free;
  FComponents.Packages.Free;
  FTargets.Cross.Free;
  FBuild.CustomOptions.Free;
  inherited Destroy;
end;

procedure TProjectConfig.InitializeDefaults;
begin
  FToolchain.Version := '';
  FToolchain.Source := 'binary';
  FToolchain.Channel := 'stable';
  
  FComponents.RTL := True;
  FComponents.FCL := True;
  FComponents.Packages.Clear;
  
  FTargets.Cross.Clear;
  
  FBuild.Mode := 'debug';
  FBuild.Optimization := '0';
  FBuild.TargetCPU := '';
  FBuild.CustomOptions.Clear;
  
  FLazarus.Version := '';
  FLazarus.AutoConfigure := False;
  
  FProject.Name := '';
  FProject.ProjectType := 'console';
  FProject.Main := '';
end;

function TProjectConfig.Load: Boolean;
begin
  Result := False;
  FLoadError := '';
  
  if not FileExists(FConfigPath) then
  begin
    FLoadError := 'Config file not found: ' + FConfigPath;
    Exit;
  end;
  
  if Assigned(FDocument) then
    FDocument.Free;
  
  FDocument := TTOMLDocument.Create;
  if not FDocument.LoadFromFile(FConfigPath) then
  begin
    FLoadError := 'Failed to parse config: ' + FDocument.ParseError;
    Exit;
  end;
  
  LoadToolchainSection;
  LoadComponentsSection;
  LoadTargetsSection;
  LoadBuildSection;
  LoadLazarusSection;
  LoadProjectSection;
  
  Result := Validate;
end;

procedure TProjectConfig.LoadToolchainSection;
var
  Section: TTOMLSection;
begin
  Section := FDocument.GetSection('toolchain');
  if not Assigned(Section) then
    Exit;
  
  FToolchain.Version := Section.GetString('version', '');
  FToolchain.Source := Section.GetString('source', 'binary');
  FToolchain.Channel := Section.GetString('channel', 'stable');
end;

procedure TProjectConfig.LoadComponentsSection;
var
  Section: TTOMLSection;
  Packages: TStringList;
  I: Integer;
begin
  Section := FDocument.GetSection('components');
  if not Assigned(Section) then
    Exit;
  
  FComponents.RTL := Section.GetBoolean('rtl', True);
  FComponents.FCL := Section.GetBoolean('fcl', True);
  
  Packages := Section.GetArray('packages');
  if Assigned(Packages) then
  begin
    FComponents.Packages.Clear;
    for I := 0 to Packages.Count - 1 do
      FComponents.Packages.Add(Packages[I]);
  end;
end;

procedure TProjectConfig.LoadTargetsSection;
var
  Section: TTOMLSection;
  Cross: TStringList;
  I: Integer;
begin
  Section := FDocument.GetSection('targets');
  if not Assigned(Section) then
    Exit;
  
  Cross := Section.GetArray('cross');
  if Assigned(Cross) then
  begin
    FTargets.Cross.Clear;
    for I := 0 to Cross.Count - 1 do
      FTargets.Cross.Add(Cross[I]);
  end;
end;

procedure TProjectConfig.LoadBuildSection;
var
  Section: TTOMLSection;
  Options: TStringList;
  I: Integer;
begin
  Section := FDocument.GetSection('build');
  if not Assigned(Section) then
    Exit;
  
  FBuild.Mode := Section.GetString('mode', 'debug');
  FBuild.Optimization := Section.GetString('optimization', '0');
  FBuild.TargetCPU := Section.GetString('target-cpu', '');
  
  Options := Section.GetArray('custom-options');
  if Assigned(Options) then
  begin
    FBuild.CustomOptions.Clear;
    for I := 0 to Options.Count - 1 do
      FBuild.CustomOptions.Add(Options[I]);
  end;
end;

procedure TProjectConfig.LoadLazarusSection;
var
  Section: TTOMLSection;
begin
  Section := FDocument.GetSection('lazarus');
  if not Assigned(Section) then
    Exit;
  
  FLazarus.Version := Section.GetString('version', '');
  FLazarus.AutoConfigure := Section.GetBoolean('auto-configure', False);
end;

procedure TProjectConfig.LoadProjectSection;
var
  Section: TTOMLSection;
begin
  Section := FDocument.GetSection('project');
  if not Assigned(Section) then
    Exit;
  
  FProject.Name := Section.GetString('name', '');
  FProject.ProjectType := Section.GetString('type', 'console');
  FProject.Main := Section.GetString('main', '');
end;

function TProjectConfig.Validate: Boolean;
begin
  Result := False;
  FLoadError := '';
  
  if FToolchain.Version = '' then
  begin
    FLoadError := 'Missing required field: [toolchain].version';
    Exit;
  end;
  
  if not ((FToolchain.Source = 'binary') or (FToolchain.Source = 'source')) then
  begin
    FLoadError := 'Invalid [toolchain].source: must be "binary" or "source"';
    Exit;
  end;
  
  if not ((FToolchain.Channel = 'stable') or (FToolchain.Channel = 'fixes') or (FToolchain.Channel = 'main')) then
  begin
    FLoadError := 'Invalid [toolchain].channel: must be "stable", "fixes", or "main"';
    Exit;
  end;
  
  if not ((FBuild.Mode = 'debug') or (FBuild.Mode = 'release')) then
  begin
    FLoadError := 'Invalid [build].mode: must be "debug" or "release"';
    Exit;
  end;
  
  if not ((FBuild.Optimization = '0') or (FBuild.Optimization = '1') or 
          (FBuild.Optimization = '2') or (FBuild.Optimization = '3')) then
  begin
    FLoadError := 'Invalid [build].optimization: must be "0", "1", "2", or "3"';
    Exit;
  end;
  
  if not ((FProject.ProjectType = 'console') or (FProject.ProjectType = 'gui') or 
          (FProject.ProjectType = 'library')) then
  begin
    FLoadError := 'Invalid [project].type: must be "console", "gui", or "library"';
    Exit;
  end;
  
  Result := True;
end;

end.
