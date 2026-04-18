unit fpdev.cross.buildcommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TCrossBuildCommandPlan = record
    TargetLabel: string;
    CPU: string;
    OS: string;
    DryRun: Boolean;
    SourceRoot: string;
    SandboxRoot: string;
    Version: string;
  end;

  TCrossBuildCommandSetDryRunProc = procedure(const AValue: Boolean) of object;
  TCrossBuildCommandBuildFunc = function(
    const ACPU, AOS, ASourceRoot, ASandboxRoot, AVersion: string
  ): Boolean of object;
  TCrossBuildCommandStringFunc = function: string of object;

function PrepareCrossBuildCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TCrossBuildCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteCrossBuildCommandPlanCore(
  const APlan: TCrossBuildCommandPlan;
  const AOut, AErr: IOutput;
  ASetDryRun: TCrossBuildCommandSetDryRunProc;
  ABuildCrossCompiler: TCrossBuildCommandBuildFunc;
  AGetLastError: TCrossBuildCommandStringFunc;
  AGetCurrentStage: TCrossBuildCommandStringFunc
): Integer;

implementation

uses
  SysUtils,
  fpdev.command.utils,
  fpdev.exitcodes;

const
  CROSS_BUILD_USAGE = 'Usage: fpdev cross build <cpu-os> [options]';
  CROSS_BUILD_MISSING_TARGET_USAGE = 'Usage: fpdev cross build <cpu-os> [--dry-run]';

function ParseTargetString(const ATarget: string; out ACPU, AOS: string): Boolean;
var
  P: Integer;
begin
  Result := False;
  ACPU := '';
  AOS := '';
  P := Pos('-', ATarget);
  if P < 2 then
    Exit;

  ACPU := Copy(ATarget, 1, P - 1);
  AOS := Copy(ATarget, P + 1, Length(ATarget));
  Result := (ACPU <> '') and (AOS <> '');
end;

procedure WriteUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(CROSS_BUILD_USAGE);
end;

procedure WriteHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(CROSS_BUILD_USAGE);
  AOut.WriteLn('');
  AOut.WriteLn('Build a cross-compiler for the specified target.');
  AOut.WriteLn('');
  AOut.WriteLn('Options:');
  AOut.WriteLn('  --dry-run         Show commands without executing');
  AOut.WriteLn('  --source=<path>   FPC source root directory');
  AOut.WriteLn('  --sandbox=<path>  Installation sandbox directory');
  AOut.WriteLn('  --version=<ver>   FPC version (default: main)');
  AOut.WriteLn('  --help            Show this help');
  AOut.WriteLn('');
  AOut.WriteLn('Examples:');
  AOut.WriteLn('  fpdev cross build x86_64-win64 --dry-run');
  AOut.WriteLn('  fpdev cross build arm-linux --source=sources/fpc');
end;

procedure WriteDryRunPlan(const APlan: TCrossBuildCommandPlan; const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn('=== Cross-compile ' + APlan.TargetLabel + ' (dry-run) ===');
  AOut.WriteLn('');
  AOut.WriteLn('Build Plan:');
  AOut.WriteLn('  Step 1: compiler_cycle  - Build native compiler');
  AOut.WriteLn('  Step 2: compiler_install - Install native compiler');
  AOut.WriteLn('  Step 3: rtl_all         - Build RTL for ' + APlan.TargetLabel);
  AOut.WriteLn('  Step 4: rtl_install     - Install RTL');
  AOut.WriteLn('  Step 5: packages_all    - Build packages for ' + APlan.TargetLabel);
  AOut.WriteLn('  Step 6: packages_install - Install packages');
  AOut.WriteLn('  Step 7: verify          - Verify installation');
  AOut.WriteLn('');
  AOut.WriteLn('Source:  ' + APlan.SourceRoot);
  AOut.WriteLn('Sandbox: ' + APlan.SandboxRoot);
  AOut.WriteLn('Version: ' + APlan.Version);
  AOut.WriteLn('');
  AOut.WriteLn('Dry-run: build execution skipped.');
end;

function BuildVersionedSourceTreePath(
  const ASourceRoot, AVersion: string
): string;
begin
  Result := IncludeTrailingPathDelimiter(ASourceRoot) + 'fpc-' + AVersion;
end;

function CheckBuildSourceTree(
  const APlan: TCrossBuildCommandPlan;
  const AErr: IOutput
): Integer;
var
  VersionedSourceTree: string;
begin
  VersionedSourceTree := BuildVersionedSourceTreePath(
    APlan.SourceRoot,
    APlan.Version
  );

  if not DirectoryExists(VersionedSourceTree) then
  begin
    if AErr <> nil then
    begin
      AErr.WriteLn('Error: FPC source tree not found: ' + VersionedSourceTree);
      AErr.WriteLn(
        'Hint: Provide a checkout under that path, or pass --source=<root> and --version=<ver>.'
      );
    end;
    Exit(EXIT_NOT_FOUND);
  end;

  if not FileExists(VersionedSourceTree + PathDelim + 'Makefile') then
  begin
    if AErr <> nil then
    begin
      AErr.WriteLn(
        'Error: FPC source tree incomplete (missing Makefile): ' + VersionedSourceTree
      );
      AErr.WriteLn(
        'Hint: Ensure the directory contains a full FPC source checkout (must include Makefile).'
      );
    end;
    Exit(EXIT_NOT_FOUND);
  end;

  Result := EXIT_OK;
end;

function PrepareCrossBuildCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TCrossBuildCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  PositionalCount: Integer;
  TargetStr: string;
  HasSourceRoot: Boolean;
  HasSandboxRoot: Boolean;
  HasVersion: Boolean;
begin
  Result := EXIT_OK;
  APlan := Default(TCrossBuildCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') or
     ((Length(AParams) > 0) and (LowerCase(AParams[0]) = 'help')) then
  begin
    AShouldExit := True;
    if Length(AParams) > 1 then
    begin
      WriteUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;

    WriteHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(
    AParams,
    ['--dry-run', '--source=', '--sandbox=', '--version='],
    UnknownOption
  ) then
  begin
    AShouldExit := True;
    WriteUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  PositionalCount := CountPositionalArgs(AParams);
  if PositionalCount < 1 then
  begin
    AShouldExit := True;
    if AErr <> nil then
    begin
      AErr.WriteLn('Error: target not specified');
      AErr.WriteLn(CROSS_BUILD_MISSING_TARGET_USAGE);
    end;
    Exit(EXIT_USAGE_ERROR);
  end;

  if PositionalCount > 1 then
  begin
    AShouldExit := True;
    WriteUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  TargetStr := GetPositionalArg(AParams, 0);
  if not ParseTargetString(TargetStr, APlan.CPU, APlan.OS) then
  begin
    AShouldExit := True;
    if AErr <> nil then
    begin
      AErr.WriteLn('Error: invalid target format "' + TargetStr + '"');
      AErr.WriteLn('Expected format: <cpu>-<os> (e.g. x86_64-win64, arm-linux)');
    end;
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.TargetLabel := TargetStr;
  APlan.DryRun := HasFlag(AParams, 'dry-run');

  HasSourceRoot := GetFlagValue(AParams, 'source', APlan.SourceRoot);
  if HasSourceRoot and (APlan.SourceRoot = '') then
  begin
    AShouldExit := True;
    if AErr <> nil then
    begin
      AErr.WriteLn('Error: Missing --source value');
      WriteUsage(AErr);
    end;
    Exit(EXIT_USAGE_ERROR);
  end;
  if not HasSourceRoot then
    APlan.SourceRoot := 'sources' + PathDelim + 'fpc';

  HasSandboxRoot := GetFlagValue(AParams, 'sandbox', APlan.SandboxRoot);
  if HasSandboxRoot and (APlan.SandboxRoot = '') then
  begin
    AShouldExit := True;
    if AErr <> nil then
    begin
      AErr.WriteLn('Error: Missing --sandbox value');
      WriteUsage(AErr);
    end;
    Exit(EXIT_USAGE_ERROR);
  end;
  if not HasSandboxRoot then
    APlan.SandboxRoot := 'sandbox';

  HasVersion := GetFlagValue(AParams, 'version', APlan.Version);
  if HasVersion and (APlan.Version = '') then
  begin
    AShouldExit := True;
    if AErr <> nil then
    begin
      AErr.WriteLn('Error: Missing --version value');
      WriteUsage(AErr);
    end;
    Exit(EXIT_USAGE_ERROR);
  end;
  if not HasVersion then
    APlan.Version := 'main';
end;

function ExecuteCrossBuildCommandPlanCore(
  const APlan: TCrossBuildCommandPlan;
  const AOut, AErr: IOutput;
  ASetDryRun: TCrossBuildCommandSetDryRunProc;
  ABuildCrossCompiler: TCrossBuildCommandBuildFunc;
  AGetLastError: TCrossBuildCommandStringFunc;
  AGetCurrentStage: TCrossBuildCommandStringFunc
): Integer;
begin
  Result := EXIT_ERROR;

  if Assigned(ASetDryRun) then
    ASetDryRun(APlan.DryRun);

  if APlan.DryRun then
  begin
    WriteDryRunPlan(APlan, AOut);
    Exit(EXIT_OK);
  end;

  Result := CheckBuildSourceTree(APlan, AErr);
  if Result <> EXIT_OK then
    Exit(Result);

  if AOut <> nil then
    AOut.WriteLn('=== Cross-compile ' + APlan.TargetLabel + ' ===');

  if not Assigned(ABuildCrossCompiler) then
    Exit(EXIT_ERROR);

  if ABuildCrossCompiler(
    APlan.CPU,
    APlan.OS,
    APlan.SourceRoot,
    APlan.SandboxRoot,
    APlan.Version
  ) then
  begin
    if AOut <> nil then
    begin
      AOut.WriteLn('');
      AOut.WriteLn('Cross-compilation completed successfully.');
    end;
    Exit(EXIT_OK);
  end;

  if AErr <> nil then
  begin
    Result := EXIT_ERROR;
    if Assigned(AGetLastError) then
      AErr.WriteLn('Error: ' + AGetLastError())
    else
      AErr.WriteLn('Error: cross build failed');

    if Assigned(AGetCurrentStage) then
      AErr.WriteLn('Stage: ' + AGetCurrentStage());
  end;
end;

end.
