unit fpdev.fpc.activation;

{
================================================================================
  fpdev.fpc.activation - FPC Environment Activation Service
================================================================================

  Manages FPC version activation, including:
  - Project-scoped activation (.fpdev/env/activate.sh|cmd)
  - User-scoped activation (~/.fpdev/env/activate-<version>.sh|cmd)
  - VS Code integration (settings.json PATH configuration)

  This service is extracted from TFPCManager as part of the Facade pattern
  refactoring to reduce god class complexity.

  Usage:
    Activator := TFPCActivationManager.Create(ConfigManager);
    try
      Result := Activator.ActivateVersion('3.2.2');
      if Result.Success then
        WriteLn('Run: ', Result.ShellCommand);
    finally
      Activator.Free;
    end;

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.config.interfaces, fpdev.types, fpdev.utils.fs, fpdev.constants;

type
  { TActivationResult - Result of version activation operation }
  TActivationResult = record
    Success: Boolean;
    Scope: TInstallScope;
    ActivationScript: string;  // Main activation script path (.cmd or .sh)
    VSCodeSettings: string;     // VS Code settings.json path (if created)
    ShellCommand: string;       // Shell command to print to user
    ErrorMessage: string;
  end;

  { TFPCActivationManager - FPC environment activation service }
  TFPCActivationManager = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;

    { Searches upward from AStartDir for .fpdev directory.
      Returns the project root path or empty string if not found. }
    function FindProjectRoot(const AStartDir: string): string;

    { Creates Windows .cmd activation script at AScriptPath.
      Script sets PATH to include ABinPath. }
    function CreateWindowsActivationScript(const AScriptPath, ABinPath: string): Boolean;

    { Creates Unix .sh activation script at AScriptPath.
      Script exports PATH to include ABinPath. }
    function CreateUnixActivationScript(const AScriptPath, ABinPath: string): Boolean;

    { Updates VS Code settings.json with terminal PATH configuration.
      Non-fatal: activation succeeds even if this fails. }
    function UpdateVSCodeSettings(const AProjectRoot, ABinPath: string): Boolean;

    { Creates project-scoped activation at .fpdev/env/activate.sh|cmd }
    function ActivateProjectScope(
      const AVersion, ABinPath: string;
      var AResult: TActivationResult
    ): Boolean;

    { Creates user-scoped activation at ~/.fpdev/env/activate-<version>.sh|cmd }
    function ActivateUserScope(
      const AVersion, ABinPath: string;
      var AResult: TActivationResult
    ): Boolean;

  public
    constructor Create(AConfigManager: IConfigManager);

    { Main activation method - detects scope and creates activation scripts.
      AVersion: FPC version to activate
      ABinPath: Path to FPC bin directory
      Returns: TActivationResult with success status and paths }
    function ActivateVersion(const AVersion, ABinPath: string): TActivationResult;

    { Detects whether we're in a project context or user context.
      Returns isProject if .fpdev directory is found above current dir. }
    function DetectInstallScope(const ACurrentDir: string): TInstallScope;
  end;

implementation

{ Local helper procedures }

procedure SafeWriteAllText(const APath, AText: string);
var
  Dir: string;
  L: TStringList;
begin
  Dir := ExtractFileDir(APath);
  if (Dir <> '') and (not DirectoryExists(Dir)) then
    EnsureDir(Dir);
  L := TStringList.Create;
  try
    L.Text := AText;
    L.SaveToFile(APath);
  finally
    L.Free;
  end;
end;

function SafeReadAllText(const APath: string): string;
var
  L: TStringList;
begin
  Result := '';
  if not FileExists(APath) then Exit;
  L := TStringList.Create;
  try
    L.LoadFromFile(APath);
    Result := L.Text;
  finally
    L.Free;
  end;
end;

{ TFPCActivationManager }

constructor TFPCActivationManager.Create(AConfigManager: IConfigManager);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
  begin
    {$IFDEF MSWINDOWS}
    FInstallRoot := GetEnvironmentVariable('USERPROFILE') + PathDelim + FPDEV_CONFIG_DIR;
    {$ELSE}
    FInstallRoot := GetEnvironmentVariable('HOME') + PathDelim + FPDEV_CONFIG_DIR;
    {$ENDIF}
  end;
end;

function TFPCActivationManager.FindProjectRoot(const AStartDir: string): string;
var
  Dir: string;
  UserConfigDir: string;
  Candidate: string;
begin
  Result := '';
  Dir := ExpandFileName(AStartDir);

  // Avoid mistaking user-level ~/.fpdev as a project marker when scanning upward.
  {$IFDEF MSWINDOWS}
  UserConfigDir := GetEnvironmentVariable('APPDATA');
  if UserConfigDir <> '' then
    UserConfigDir := ExcludeTrailingPathDelimiter(ExpandFileName(UserConfigDir + PathDelim + FPDEV_CONFIG_DIR))
  else
    UserConfigDir := ExcludeTrailingPathDelimiter(
      ExpandFileName(GetEnvironmentVariable('USERPROFILE') + PathDelim + FPDEV_CONFIG_DIR)
    );
  {$ELSE}
  UserConfigDir := ExcludeTrailingPathDelimiter(
    ExpandFileName(GetEnvironmentVariable('HOME') + PathDelim + FPDEV_CONFIG_DIR)
  );
  {$ENDIF}

  while Dir <> '' do
  begin
    Candidate := ExcludeTrailingPathDelimiter(ExpandFileName(Dir + PathDelim + FPDEV_CONFIG_DIR));
    if DirectoryExists(Candidate) then
    begin
      if (UserConfigDir = '') or (not SameText(Candidate, UserConfigDir)) then
      begin
        Result := Dir;
        Exit;
      end;
    end;

    // Move up to parent directory
    Dir := ExtractFileDir(Dir);

    // Stop at root (when parent == current)
    if Dir = ExtractFileDir(Dir) then
      Break;
  end;
end;

function TFPCActivationManager.DetectInstallScope(const ACurrentDir: string): TInstallScope;
begin
  if FindProjectRoot(ACurrentDir) <> '' then
    Result := isProject
  else
    Result := isUser;
end;

function TFPCActivationManager.CreateWindowsActivationScript(const AScriptPath, ABinPath: string): Boolean;
var
  Script: TStringList;
begin
  Result := False;

  try
    Script := TStringList.Create;
    try
      Script.Add('@echo off');
      Script.Add('REM FPC Environment Activation Script');
      Script.Add('REM Generated by fpdev');
      Script.Add('');
      Script.Add('SET "PATH=' + ABinPath + ';%PATH%"');
      Script.Add('');
      Script.Add('echo FPC environment activated');
      Script.Add('echo FPC bin directory: ' + ABinPath);

      SafeWriteAllText(AScriptPath, Script.Text);
      Result := True;
    finally
      Script.Free;
    end;
  except
    Result := False;
  end;
end;

function TFPCActivationManager.CreateUnixActivationScript(const AScriptPath, ABinPath: string): Boolean;
var
  Script: TStringList;
begin
  Result := False;

  try
    Script := TStringList.Create;
    try
      Script.Add('#!/bin/sh');
      Script.Add('# FPC Environment Activation Script');
      Script.Add('# Generated by fpdev');
      Script.Add('');
      Script.Add('export PATH="' + ABinPath + ':$PATH"');
      Script.Add('');
      Script.Add('echo "FPC environment activated"');
      Script.Add('echo "FPC bin directory: ' + ABinPath + '"');

      SafeWriteAllText(AScriptPath, Script.Text);
      Result := True;
    finally
      Script.Free;
    end;
  except
    Result := False;
  end;
end;

function TFPCActivationManager.UpdateVSCodeSettings(const AProjectRoot, ABinPath: string): Boolean;
var
  VSCodeDir, SettingsPath, JSONText: string;
  JSON: TJSONObject;
  Parser: TJSONParser;
  EnvObj: TJSONObject;
  PathValue: string;
begin
  Result := False;

  try
    VSCodeDir := AProjectRoot + PathDelim + '.vscode';
    if not DirectoryExists(VSCodeDir) then
      EnsureDir(VSCodeDir);

    SettingsPath := VSCodeDir + PathDelim + 'settings.json';

    // Load existing settings or create new
    if FileExists(SettingsPath) then
    begin
      JSONText := SafeReadAllText(SettingsPath);
      Parser := TJSONParser.Create(JSONText, []);
      try
        JSON := Parser.Parse as TJSONObject;
      finally
        Parser.Free;
      end;
    end
    else
      JSON := TJSONObject.Create;

    try
      // Add platform-specific terminal PATH
      {$IFDEF MSWINDOWS}
      if JSON.Find('terminal.integrated.env.windows') = nil then
        JSON.Add('terminal.integrated.env.windows', TJSONObject.Create);
      EnvObj := JSON.Objects['terminal.integrated.env.windows'];
      PathValue := ABinPath + ';${env:PATH}';
      {$ELSE}
        {$IFDEF DARWIN}
        if JSON.Find('terminal.integrated.env.osx') = nil then
          JSON.Add('terminal.integrated.env.osx', TJSONObject.Create);
        EnvObj := JSON.Objects['terminal.integrated.env.osx'];
        {$ELSE}
        if JSON.Find('terminal.integrated.env.linux') = nil then
          JSON.Add('terminal.integrated.env.linux', TJSONObject.Create);
        EnvObj := JSON.Objects['terminal.integrated.env.linux'];
        {$ENDIF}
      PathValue := ABinPath + ':${env:PATH}';
      {$ENDIF}

      if EnvObj.Find('PATH') <> nil then
        EnvObj.Delete('PATH');
      EnvObj.Add('PATH', PathValue);

      SafeWriteAllText(SettingsPath, JSON.FormatJSON);
      Result := True;
    finally
      JSON.Free;
    end;
  except
    // Non-fatal: activation succeeds even if VS Code settings fail
    Result := False;
  end;
end;

function TFPCActivationManager.ActivateProjectScope(
  const AVersion, ABinPath: string;
  var AResult: TActivationResult
): Boolean;
var
  ProjectRoot, EnvDir, ScriptPath: string;
begin
  Result := False;
  AResult.Scope := isProject;
  if AVersion = '' then; // Suppress unused parameter hint - version not needed for project scope

  ProjectRoot := FindProjectRoot(GetCurrentDir);
  if ProjectRoot = '' then
  begin
    AResult.ErrorMessage := 'No project root found (missing .fpdev directory)';
    Exit;
  end;

  // Create .fpdev/env directory
  EnvDir := ProjectRoot + PathDelim + FPDEV_CONFIG_DIR + PathDelim + 'env';
  EnsureDir(EnvDir);

  // Create activation script
  {$IFDEF MSWINDOWS}
  ScriptPath := EnvDir + PathDelim + 'activate.cmd';
  if not CreateWindowsActivationScript(ScriptPath, ABinPath) then
  begin
    AResult.ErrorMessage := 'Failed to create Windows activation script';
    Exit;
  end;
  AResult.ShellCommand := ScriptPath;
  {$ELSE}
  ScriptPath := EnvDir + PathDelim + 'activate.sh';
  if not CreateUnixActivationScript(ScriptPath, ABinPath) then
  begin
    AResult.ErrorMessage := 'Failed to create Unix activation script';
    Exit;
  end;
  AResult.ShellCommand := 'source ' + ScriptPath;
  {$ENDIF}

  AResult.ActivationScript := ScriptPath;

  // Optionally update VS Code settings (non-fatal)
  if UpdateVSCodeSettings(ProjectRoot, ABinPath) then
    AResult.VSCodeSettings := ProjectRoot + PathDelim + '.vscode' + PathDelim + 'settings.json';

  AResult.Success := True;
  Result := True;
end;

function TFPCActivationManager.ActivateUserScope(
  const AVersion, ABinPath: string;
  var AResult: TActivationResult
): Boolean;
var
  EnvDir, ScriptPath: string;
begin
  Result := False;
  AResult.Scope := isUser;

  // Create ~/.fpdev/env directory
  EnvDir := FInstallRoot + PathDelim + 'env';
  EnsureDir(EnvDir);

  // Create version-specific activation script
  {$IFDEF MSWINDOWS}
  ScriptPath := EnvDir + PathDelim + 'activate-' + AVersion + '.cmd';
  if not CreateWindowsActivationScript(ScriptPath, ABinPath) then
  begin
    AResult.ErrorMessage := 'Failed to create Windows activation script';
    Exit;
  end;
  AResult.ShellCommand := ScriptPath;
  {$ELSE}
  ScriptPath := EnvDir + PathDelim + 'activate-' + AVersion + '.sh';
  if not CreateUnixActivationScript(ScriptPath, ABinPath) then
  begin
    AResult.ErrorMessage := 'Failed to create Unix activation script';
    Exit;
  end;
  AResult.ShellCommand := 'source ' + ScriptPath;
  {$ENDIF}

  AResult.ActivationScript := ScriptPath;
  AResult.Success := True;
  Result := True;
end;

function TFPCActivationManager.ActivateVersion(const AVersion, ABinPath: string): TActivationResult;
var
  Scope: TInstallScope;
begin
  // Initialize result
  Result.Success := False;
  Result.ActivationScript := '';
  Result.VSCodeSettings := '';
  Result.ShellCommand := '';
  Result.ErrorMessage := '';

  // Detect scope
  Scope := DetectInstallScope(GetCurrentDir);

  // Create activation based on scope
  if Scope = isProject then
    ActivateProjectScope(AVersion, ABinPath, Result)
  else
    ActivateUserScope(AVersion, ABinPath, Result);
end;

end.
