unit fpdev.doctor.checks;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf;

type
  TDoctorMessageProc = procedure(const AMessage: string) of object;
  TDoctorHintProc = procedure(const AMessage: string; const AHint: string) of object;
  TDoctorExecCommandFunc = function(const ACmd: string; out AOutput: string): Integer;

procedure ExecuteDoctorFPCChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  AExecuteCommand: TDoctorExecCommandFunc;
  APass: TDoctorMessageProc;
  AWarn: TDoctorHintProc;
  AInfo: TDoctorMessageProc
);
procedure ExecuteDoctorLazarusChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  AExecuteCommand: TDoctorExecCommandFunc;
  APass: TDoctorMessageProc;
  AInfo: TDoctorMessageProc
);
procedure ExecuteDoctorConfigChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  APass: TDoctorMessageProc;
  AInfo: TDoctorMessageProc
);
procedure ExecuteDoctorEnvironmentChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  APass: TDoctorMessageProc;
  AWarn: TDoctorHintProc;
  AFail: TDoctorHintProc;
  AInfo: TDoctorMessageProc
);
procedure ExecuteDoctorBuildToolChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  AExecuteCommand: TDoctorExecCommandFunc;
  APass: TDoctorMessageProc;
  AWarn: TDoctorHintProc
);
procedure ExecuteDoctorGitChecksCore(
  const ACtx: IContext;
  AExecuteCommand: TDoctorExecCommandFunc;
  APass: TDoctorMessageProc;
  AWarn: TDoctorHintProc
);
procedure ExecuteDoctorDebuggerChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  AExecuteCommand: TDoctorExecCommandFunc;
  APass: TDoctorMessageProc;
  AWarn: TDoctorHintProc;
  AInfo: TDoctorMessageProc
);
procedure ExecuteDoctorDiskSpaceChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  APass: TDoctorMessageProc;
  AInfo: TDoctorMessageProc
);

implementation

uses
  fpdev.config.project,
  fpdev.doctor.view,
  fpdev.paths,
  fpdev.utils;

procedure ExecuteDoctorFPCChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  AExecuteCommand: TDoctorExecCommandFunc;
  APass: TDoctorMessageProc;
  AWarn: TDoctorHintProc;
  AInfo: TDoctorMessageProc
);
var
  Toolchains: TStringArray;
  DefaultToolchain: string;
  OutputText: string;
  VersionText: string;
  Index: Integer;
begin
  WriteDoctorSectionCore(ACtx.Out, 'FPC Installation', not AJsonMode);

  Toolchains := ACtx.Config.GetToolchainManager.ListToolchains;
  if Length(Toolchains) = 0 then
    AWarn('No FPC versions installed via fpdev', 'Run: fpdev fpc install <version>')
  else
  begin
    APass('Found ' + IntToStr(Length(Toolchains)) + ' FPC version(s) installed');
    for Index := 0 to High(Toolchains) do
      ACtx.Out.WriteLn('    - ' + Toolchains[Index]);
  end;

  DefaultToolchain := ACtx.Config.GetToolchainManager.GetDefaultToolchain;
  if DefaultToolchain = '' then
    AWarn('No default FPC version set', 'Run: fpdev fpc use <version>')
  else
    APass('Default FPC: ' + DefaultToolchain);

  if Assigned(AExecuteCommand) and (AExecuteCommand('fpc -iV', OutputText) = 0) then
  begin
    VersionText := Trim(OutputText);
    APass('FPC in PATH: ' + VersionText);
  end
  else
    AInfo('FPC not found in PATH (this is OK if using fpdev activation)');
end;

procedure ExecuteDoctorLazarusChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  AExecuteCommand: TDoctorExecCommandFunc;
  APass: TDoctorMessageProc;
  AInfo: TDoctorMessageProc
);
var
  Versions: TStringArray;
  DefaultVersion: string;
  OutputText: string;
  Index: Integer;
begin
  WriteDoctorSectionCore(ACtx.Out, 'Lazarus Installation', not AJsonMode);

  Versions := ACtx.Config.GetLazarusManager.ListLazarusVersions;
  if Length(Versions) = 0 then
    AInfo('No Lazarus versions installed via fpdev')
  else
  begin
    APass('Found ' + IntToStr(Length(Versions)) + ' Lazarus version(s) installed');
    for Index := 0 to High(Versions) do
      ACtx.Out.WriteLn('    - ' + Versions[Index]);
  end;

  DefaultVersion := ACtx.Config.GetLazarusManager.GetDefaultLazarusVersion;
  if DefaultVersion <> '' then
    APass('Default Lazarus: ' + DefaultVersion);

  if Assigned(AExecuteCommand) and (AExecuteCommand('lazbuild --version', OutputText) = 0) then
    APass('lazbuild in PATH')
  else
    AInfo('lazbuild not found in PATH');
end;

procedure ExecuteDoctorConfigChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  APass: TDoctorMessageProc;
  AInfo: TDoctorMessageProc
);
var
  ConfigPath: string;
  Resolver: TProjectConfigResolver;
  ProjectConfig: string;
begin
  WriteDoctorSectionCore(ACtx.Out, 'Configuration', not AJsonMode);

  ConfigPath := GetConfigPath;

  if FileExists(ConfigPath) then
    APass('Global config: ' + ConfigPath)
  else
    AInfo('No global config file (will be created on first use)');

  Resolver := TProjectConfigResolver.Create;
  try
    ProjectConfig := Resolver.FindProjectConfig(GetCurrentDir);
    if ProjectConfig <> '' then
      APass('Project config: ' + ProjectConfig)
    else
      AInfo('No project config (.fpdevrc) in current directory tree');
  finally
    Resolver.Free;
  end;
end;

procedure ExecuteDoctorEnvironmentChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  APass: TDoctorMessageProc;
  AWarn: TDoctorHintProc;
  AFail: TDoctorHintProc;
  AInfo: TDoctorMessageProc
);
var
  PathValue: string;
  FPCDir: string;
begin
  WriteDoctorSectionCore(ACtx.Out, 'Environment Variables', not AJsonMode);

  PathValue := get_env('PATH');
  if PathValue <> '' then
    APass('PATH is set (' + IntToStr(Length(PathValue)) + ' chars)')
  else
    AFail('PATH is empty', 'Check your shell configuration');

  FPCDir := get_env('FPCDIR');
  if FPCDir <> '' then
  begin
    if DirectoryExists(FPCDir) then
      APass('FPCDIR: ' + FPCDir)
    else
      AWarn('FPCDIR points to non-existent directory: ' + FPCDir, 'Update or unset FPCDIR');
  end
  else
    AInfo('FPCDIR not set (this is OK)');

  if get_env('PP') <> '' then
    AWarn('PP environment variable is set', 'This may conflict with fpdev. Consider unsetting it.');
end;

procedure ExecuteDoctorBuildToolChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  AExecuteCommand: TDoctorExecCommandFunc;
  APass: TDoctorMessageProc;
  AWarn: TDoctorHintProc
);
var
  OutputText: string;
begin
  WriteDoctorSectionCore(ACtx.Out, 'Build Tools', not AJsonMode);

  if Assigned(AExecuteCommand) and (AExecuteCommand('make --version', OutputText) = 0) then
    APass('make is available')
  else
  begin
    {$IFDEF MSWINDOWS}
    AWarn('make not found', 'Install MSYS2 or MinGW and add to PATH');
    {$ELSE}
    AWarn('make not found', 'Install build-essential (Debian/Ubuntu) or base-devel (Arch)');
    {$ENDIF}
  end;
end;

procedure ExecuteDoctorGitChecksCore(
  const ACtx: IContext;
  AExecuteCommand: TDoctorExecCommandFunc;
  APass: TDoctorMessageProc;
  AWarn: TDoctorHintProc
);
var
  OutputText: string;
begin
  if ACtx = nil then;
  if Assigned(AExecuteCommand) and (AExecuteCommand('git --version', OutputText) = 0) then
    APass('git is available: ' + OutputText)
  else
    AWarn('git not found', 'Install git for source repository management');
end;

procedure ExecuteDoctorDebuggerChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  AExecuteCommand: TDoctorExecCommandFunc;
  APass: TDoctorMessageProc;
  AWarn: TDoctorHintProc;
  AInfo: TDoctorMessageProc
);
var
  OutputText: string;
  FoundDebugger: Boolean;
begin
  WriteDoctorSectionCore(ACtx.Out, 'Debugger', not AJsonMode);
  FoundDebugger := False;
  if Assigned(AWarn) then;

  if Assigned(AExecuteCommand) and (AExecuteCommand('gdb --version', OutputText) = 0) then
  begin
    APass('gdb is available');
    FoundDebugger := True;
  end;

  if Assigned(AExecuteCommand) and (AExecuteCommand('lldb --version', OutputText) = 0) then
  begin
    APass('lldb is available');
    FoundDebugger := True;
  end;

  if not FoundDebugger then
  begin
    {$IFDEF DARWIN}
    AWarn('No debugger found', 'Install Xcode Command Line Tools: xcode-select --install');
    {$ELSE}
    AInfo('No debugger found (optional, needed for debugging)');
    {$ENDIF}
  end;
end;

procedure ExecuteDoctorDiskSpaceChecksCore(
  const ACtx: IContext;
  AJsonMode: Boolean;
  APass: TDoctorMessageProc;
  AInfo: TDoctorMessageProc
);
var
  InstallRoot: string;
begin
  WriteDoctorSectionCore(ACtx.Out, 'Disk Space', not AJsonMode);

  InstallRoot := ACtx.Config.GetSettingsManager.GetSettings.InstallRoot;
  if InstallRoot = '' then
    InstallRoot := GetDataRoot;

  if DirectoryExists(InstallRoot) then
    APass('Install directory exists: ' + InstallRoot)
  else
    AInfo('Install directory will be created: ' + InstallRoot);
end;

end.
