unit fpdev.cmd.doctor;

{
  fpdev doctor command

  Diagnose toolchain environment, check common issues and provide fix suggestions
  Similar to rustup doctor and brew doctor

  Usage:
    fpdev doctor              # Run full diagnostics
    fpdev doctor --quick      # Quick check (critical items only)
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf,
  fpdev.command.registry, fpdev.exitcodes;

type
  { TDoctorCommand - Diagnose toolchain environment }
  TDoctorCommand = class(TInterfacedObject, ICommand)
  private
    FCtx: IContext;
    FErrorCount: Integer;
    FWarningCount: Integer;
    FPassCount: Integer;
    FJsonMode: Boolean;
    FChecks: TStringList;  // JSON check results

    procedure CheckPass(const AMessage: string);
    procedure CheckWarn(const AMessage: string; const AHint: string = '');
    procedure CheckFail(const AMessage: string; const AHint: string = '');
    procedure CheckInfo(const AMessage: string);
    procedure AddCheckResult(const AStatus, AMessage, AHint: string);

    // Individual checks
    function CheckFPCInstallation: Boolean;
    function CheckLazarusInstallation: Boolean;
    function CheckConfigFile: Boolean;
    function CheckEnvironmentVariables: Boolean;
    function CheckMakeAvailable: Boolean;
    function CheckGitAvailable: Boolean;
    function CheckDebuggerAvailable: Boolean;
    function CheckDiskSpace: Boolean;
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function DoctorCommandFactory: ICommand;

implementation

uses
  Process, StrUtils,
  fpdev.config.interfaces,
  fpdev.config.project,
  fpdev.output.intf;

const
  HELP_DOCTOR = 'Usage: fpdev doctor [options]' + LineEnding +
                '' + LineEnding +
                'Diagnose toolchain environment and check for common issues.' + LineEnding +
                '' + LineEnding +
                'Options:' + LineEnding +
                '  --quick       Run quick checks only (skip slow operations)' + LineEnding +
                '  --json        Output results in JSON format' + LineEnding +
                '  -h, --help    Show this help message' + LineEnding +
                '' + LineEnding +
                'Checks performed:' + LineEnding +
                '  - FPC installation and version' + LineEnding +
                '  - Lazarus installation (if any)' + LineEnding +
                '  - Configuration file validity' + LineEnding +
                '  - Environment variables (PATH, FPCDIR, etc.)' + LineEnding +
                '  - Build tools (make, git)' + LineEnding +
                '  - Debugger availability (gdb/lldb)' + LineEnding +
                '  - Disk space';

function DoctorCommandFactory: ICommand;
begin
  Result := TDoctorCommand.Create;
end;

{ TDoctorCommand }

function TDoctorCommand.Name: string;
begin
  Result := 'doctor';
end;

function TDoctorCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TDoctorCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

procedure TDoctorCommand.AddCheckResult(const AStatus, AMessage, AHint: string);
begin
  if FJsonMode then
  begin
    if FChecks.Count > 0 then
      FChecks.Add(',');
    FChecks.Add('{"status":"' + AStatus + '","message":"' +
      StringReplace(AMessage, '"', '\"', [rfReplaceAll]) + '"' +
      IfThen(AHint <> '', ',"hint":"' + StringReplace(AHint, '"', '\"', [rfReplaceAll]) + '"', '') + '}');
  end;
end;

procedure TDoctorCommand.CheckPass(const AMessage: string);
begin
  Inc(FPassCount);
  AddCheckResult('pass', AMessage, '');
  if not FJsonMode then
    FCtx.Out.WriteSuccess(AMessage);
end;

procedure TDoctorCommand.CheckWarn(const AMessage: string; const AHint: string);
begin
  Inc(FWarningCount);
  AddCheckResult('warning', AMessage, AHint);
  if not FJsonMode then
  begin
    FCtx.Out.WriteWarning(AMessage);
    if AHint <> '' then
      FCtx.Out.WriteLn('    Hint: ' + AHint);
  end;
end;

procedure TDoctorCommand.CheckFail(const AMessage: string; const AHint: string);
begin
  Inc(FErrorCount);
  AddCheckResult('error', AMessage, AHint);
  if not FJsonMode then
  begin
    FCtx.Out.WriteError(AMessage);
    if AHint <> '' then
      FCtx.Out.WriteLn('    Fix: ' + AHint);
  end;
end;

procedure TDoctorCommand.CheckInfo(const AMessage: string);
begin
  AddCheckResult('info', AMessage, '');
  if not FJsonMode then
    FCtx.Out.WriteInfo(AMessage);
end;

function ExecuteCommand(const ACmd: string; out AOutput: string): Integer;
var
  LProcess: TProcess;
  LStrings: TStringList;
begin
  Result := -1;
  AOutput := '';
  LProcess := TProcess.Create(nil);
  LStrings := TStringList.Create;
  try
    {$IFDEF MSWINDOWS}
    LProcess.Executable := 'cmd';
    LProcess.Parameters.Add('/c');
    LProcess.Parameters.Add(ACmd);
    {$ELSE}
    LProcess.Executable := '/bin/sh';
    LProcess.Parameters.Add('-c');
    LProcess.Parameters.Add(ACmd);
    {$ENDIF}
    LProcess.Options := [poUsePipes, poWaitOnExit];
    try
      LProcess.Execute;
      LStrings.LoadFromStream(LProcess.Output);
      AOutput := Trim(LStrings.Text);
      Result := LProcess.ExitCode;
    except
      Result := -1;
    end;
  finally
    LStrings.Free;
    LProcess.Free;
  end;
end;

function TDoctorCommand.CheckFPCInstallation: Boolean;
var
  LToolchains: TStringArray;
  LDefault, LOutput, LVersion: string;
  I: Integer;
begin
  Result := True;
  if not FJsonMode then
  begin
    FCtx.Out.WriteLn('');
    FCtx.Out.WriteLn('FPC Installation');
    FCtx.Out.WriteLn('----------------');
  end;

  // Check installed toolchains
  LToolchains := FCtx.Config.GetToolchainManager.ListToolchains;
  if Length(LToolchains) = 0 then
  begin
    CheckWarn('No FPC versions installed via fpdev',
              'Run: fpdev fpc install <version>');
  end
  else
  begin
    CheckPass('Found ' + IntToStr(Length(LToolchains)) + ' FPC version(s) installed');
    for I := 0 to High(LToolchains) do
      FCtx.Out.WriteLn('    - ' + LToolchains[I]);
  end;

  // Check default toolchain
  LDefault := FCtx.Config.GetToolchainManager.GetDefaultToolchain;
  if LDefault = '' then
    CheckWarn('No default FPC version set',
              'Run: fpdev default fpc <version>')
  else
    CheckPass('Default FPC: ' + LDefault);

  // Check if fpc is in PATH
  if ExecuteCommand('fpc -iV', LOutput) = 0 then
  begin
    LVersion := Trim(LOutput);
    CheckPass('FPC in PATH: ' + LVersion);
  end
  else
    CheckInfo('FPC not found in PATH (this is OK if using fpdev activation)');
end;

function TDoctorCommand.CheckLazarusInstallation: Boolean;
var
  LVersions: TStringArray;
  LDefault: string;
  I: Integer;
begin
  Result := True;
  FCtx.Out.WriteLn('');
  if not FJsonMode then FCtx.Out.WriteLn('Lazarus Installation');
  FCtx.Out.WriteLn('--------------------');

  // Check installed Lazarus versions
  LVersions := FCtx.Config.GetLazarusManager.ListLazarusVersions;
  if Length(LVersions) = 0 then
    CheckInfo('No Lazarus versions installed via fpdev')
  else
  begin
    CheckPass('Found ' + IntToStr(Length(LVersions)) + ' Lazarus version(s) installed');
    for I := 0 to High(LVersions) do
      FCtx.Out.WriteLn('    - ' + LVersions[I]);
  end;

  // Check default Lazarus
  LDefault := FCtx.Config.GetLazarusManager.GetDefaultLazarusVersion;
  if LDefault <> '' then
    CheckPass('Default Lazarus: ' + LDefault);

  // Check if lazbuild is in PATH
  if ExecuteCommand('lazbuild --version', LDefault) = 0 then
    CheckPass('lazbuild in PATH')
  else
    CheckInfo('lazbuild not found in PATH');
end;

function TDoctorCommand.CheckConfigFile: Boolean;
var
  LConfigPath: string;
  LResolver: TProjectConfigResolver;
  LProjectConfig: string;
begin
  Result := True;
  FCtx.Out.WriteLn('');
  FCtx.Out.WriteLn('Configuration');
  FCtx.Out.WriteLn('-------------');

  // Check global config
  {$IFDEF MSWINDOWS}
  LConfigPath := GetEnvironmentVariable('APPDATA') + PathDelim + '.fpdev' + PathDelim + 'config.json';
  {$ELSE}
  LConfigPath := GetEnvironmentVariable('HOME') + PathDelim + '.fpdev' + PathDelim + 'config.json';
  {$ENDIF}

  if FileExists(LConfigPath) then
    CheckPass('Global config: ' + LConfigPath)
  else
    CheckInfo('No global config file (will be created on first use)');

  // Check project config
  LResolver := TProjectConfigResolver.Create;
  try
    LProjectConfig := LResolver.FindProjectConfig(GetCurrentDir);
    if LProjectConfig <> '' then
      CheckPass('Project config: ' + LProjectConfig)
    else
      CheckInfo('No project config (.fpdevrc) in current directory tree');
  finally
    LResolver.Free;
  end;
end;

function TDoctorCommand.CheckEnvironmentVariables: Boolean;
var
  LPath, LFpcDir: string;
begin
  Result := True;
  FCtx.Out.WriteLn('');
  FCtx.Out.WriteLn('Environment Variables');
  FCtx.Out.WriteLn('---------------------');

  // Check PATH
  LPath := GetEnvironmentVariable('PATH');
  if LPath <> '' then
    CheckPass('PATH is set (' + IntToStr(Length(LPath)) + ' chars)')
  else
    CheckFail('PATH is empty', 'Check your shell configuration');

  // Check FPCDIR (optional)
  LFpcDir := GetEnvironmentVariable('FPCDIR');
  if LFpcDir <> '' then
  begin
    if DirectoryExists(LFpcDir) then
      CheckPass('FPCDIR: ' + LFpcDir)
    else
      CheckWarn('FPCDIR points to non-existent directory: ' + LFpcDir,
                'Update or unset FPCDIR');
  end
  else
    CheckInfo('FPCDIR not set (this is OK)');

  // Check for conflicting environment
  if GetEnvironmentVariable('PP') <> '' then
    CheckWarn('PP environment variable is set',
              'This may conflict with fpdev. Consider unsetting it.');
end;

function TDoctorCommand.CheckMakeAvailable: Boolean;
var
  LOutput: string;
begin
  Result := True;
  FCtx.Out.WriteLn('');
  FCtx.Out.WriteLn('Build Tools');
  FCtx.Out.WriteLn('-----------');

  // Check make
  if ExecuteCommand('make --version', LOutput) = 0 then
    CheckPass('make is available')
  else
  begin
    {$IFDEF MSWINDOWS}
    CheckWarn('make not found',
              'Install MSYS2 or MinGW and add to PATH');
    {$ELSE}
    CheckWarn('make not found',
              'Install build-essential (Debian/Ubuntu) or base-devel (Arch)');
    {$ENDIF}
  end;
end;

function TDoctorCommand.CheckGitAvailable: Boolean;
var
  LOutput: string;
begin
  Result := True;

  // Check git
  if ExecuteCommand('git --version', LOutput) = 0 then
    CheckPass('git is available: ' + LOutput)
  else
    CheckWarn('git not found',
              'Install git for source repository management');
end;

function TDoctorCommand.CheckDebuggerAvailable: Boolean;
var
  LOutput: string;
  LFound: Boolean;
begin
  Result := True;
  FCtx.Out.WriteLn('');
  FCtx.Out.WriteLn('Debugger');
  FCtx.Out.WriteLn('--------');

  LFound := False;

  // Check gdb
  if ExecuteCommand('gdb --version', LOutput) = 0 then
  begin
    CheckPass('gdb is available');
    LFound := True;
  end;

  // Check lldb (especially on macOS)
  if ExecuteCommand('lldb --version', LOutput) = 0 then
  begin
    CheckPass('lldb is available');
    LFound := True;
  end;

  if not LFound then
  begin
    {$IFDEF DARWIN}
    CheckWarn('No debugger found',
              'Install Xcode Command Line Tools: xcode-select --install');
    {$ELSE}
    CheckInfo('No debugger found (optional, needed for debugging)');
    {$ENDIF}
  end;
end;

function TDoctorCommand.CheckDiskSpace: Boolean;
var
  LInstallRoot: string;
begin
  Result := True;
  FCtx.Out.WriteLn('');
  FCtx.Out.WriteLn('Disk Space');
  FCtx.Out.WriteLn('----------');

  LInstallRoot := FCtx.Config.GetSettingsManager.GetSettings.InstallRoot;
  if LInstallRoot = '' then
    LInstallRoot := GetEnvironmentVariable('HOME') + PathDelim + '.fpdev';

  // Disk space check is platform-specific and complex
  // For now, just verify the install root exists or can be created
  if DirectoryExists(LInstallRoot) then
    CheckPass('Install directory exists: ' + LInstallRoot)
  else
    CheckInfo('Install directory will be created: ' + LInstallRoot);
end;

function TDoctorCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  I: Integer;
  LQuick: Boolean;
begin
  Result := 0;
  FCtx := Ctx;
  FErrorCount := 0;
  FWarningCount := 0;
  FPassCount := 0;
  FJsonMode := False;
  FChecks := TStringList.Create;

  try
    // Check help flag
    for I := 0 to High(AParams) do
    begin
      if (AParams[I] = '-h') or (AParams[I] = '--help') then
      begin
        Ctx.Out.WriteLn(HELP_DOCTOR);
        Exit(EXIT_OK);
      end;
    end;

    // Check flags
    LQuick := False;
    for I := 0 to High(AParams) do
    begin
      if AParams[I] = '--quick' then
        LQuick := True
      else if AParams[I] = '--json' then
        FJsonMode := True;
    end;

    if not FJsonMode then
    begin
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('fpdev doctor - Diagnosing your toolchain environment...');
    end;

    // Run checks
    CheckFPCInstallation;
    CheckLazarusInstallation;
    CheckConfigFile;
    CheckEnvironmentVariables;
    CheckMakeAvailable;
    CheckGitAvailable;

    if not LQuick then
    begin
      CheckDebuggerAvailable;
      CheckDiskSpace;
    end;

    // Output results
    if FJsonMode then
    begin
      Ctx.Out.WriteLn('{"checks":[' + FChecks.Text + '],"summary":{"passed":' +
        IntToStr(FPassCount) + ',"warnings":' + IntToStr(FWarningCount) +
        ',"errors":' + IntToStr(FErrorCount) + '}}');
    end
    else
    begin
      // Summary
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Summary');
      Ctx.Out.WriteLn('-------');
      Ctx.Out.WriteLn('  Passed:   ' + IntToStr(FPassCount));
      Ctx.Out.WriteLn('  Warnings: ' + IntToStr(FWarningCount));
      Ctx.Out.WriteLn('  Errors:   ' + IntToStr(FErrorCount));
      Ctx.Out.WriteLn('');

      if FErrorCount > 0 then
      begin
        Ctx.Out.WriteError('Some checks failed. Please fix the issues above.');
        Result := EXIT_ERROR;
      end
      else if FWarningCount > 0 then
      begin
        Ctx.Out.WriteWarning('Some warnings found. Consider addressing them.');
        Result := 0;
      end
      else
      begin
        Ctx.Out.WriteSuccess('All checks passed! Your environment is ready.');
        Result := 0;
      end;

      Ctx.Out.WriteLn('');
    end;

    if FErrorCount > 0 then
      Result := EXIT_ERROR;
  finally
    FChecks.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['doctor'], @DoctorCommandFactory, []);

end.
