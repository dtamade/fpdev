unit fpdev.build.config;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

{
  TBuildConfig - Build Configuration Object
  ==========================================

  Consolidates all TBuildManager configuration into a single record type.
  Replaces 12 individual SetXxx methods with a single ApplyConfig call.

  Usage:
    var
      Config: TBuildConfig;
    begin
      Config := TBuildConfig.Default;
      Config.ParallelJobs := 4;
      Config.StrictResults := True;
      Config.AllowInstall := True;
      BuildManager.ApplyConfig(Config);
    end;

  Benefits:
    - Single point of configuration
    - Easier to pass around
    - Self-documenting defaults
    - Easier to serialize/deserialize
    - Reduces TBuildManager interface complexity
}

interface

uses
  SysUtils, Classes;

type
  { TStringArray - String array type }
  TBuildStringArray = array of string;

  { TBuildConfig - Build configuration record

    Fields:
      Execution Configuration:
        SourceRoot      - Root directory containing FPC source versions
        SandboxRoot     - Sandbox directory for build artifacts
        LogDir          - Directory for build logs
        ParallelJobs    - Number of parallel jobs for make (0 = auto-detect)
        Verbose         - Verbose output during build

      Control Flags:
        AllowInstall    - Allow installation after build (default: False for safety)
        DryRun          - Dry run mode: print commands without executing

      Validation Configuration:
        StrictResults     - Strict mode: more rigorous sandbox artifact validation
        StrictConfigPath  - Path to strict mode INI configuration file (optional)
        ToolchainStrict   - Toolchain strict validation: fail build if toolchain check fails
        LogVerbosity      - Log verbosity level: 0=normal, 1=verbose

      Make Configuration:
        MakeCmd       - Custom make command (empty = auto-detect)
        CpuTarget     - Target CPU for cross-compilation (empty = native)
        OsTarget      - Target OS for cross-compilation (empty = native)
        Prefix        - Installation prefix (empty = default)
        InstallPrefix - Alternative installation prefix (empty = use Prefix)

      Package Selection (Phase 4.3):
        SelectedPackages  - Specific packages to build (empty = all)
        SkippedPackages   - Packages to skip during build
  }
  TBuildConfig = record
    // Execution Configuration
    SourceRoot: string;
    SandboxRoot: string;
    LogDir: string;
    ParallelJobs: Integer;
    Verbose: Boolean;

    // Control Flags
    AllowInstall: Boolean;
    DryRun: Boolean;

    // Validation Configuration
    StrictResults: Boolean;
    StrictConfigPath: string;
    ToolchainStrict: Boolean;
    LogVerbosity: Integer;

    // Make Configuration
    MakeCmd: string;
    CpuTarget: string;
    OsTarget: string;
    Prefix: string;
    InstallPrefix: string;

    // Package Selection (Phase 4.3)
    SelectedPackages: TBuildStringArray;
    SkippedPackages: TBuildStringArray;

    { Returns a configuration with sensible defaults }
    class function Default: TBuildConfig; static;

    { Returns a configuration optimized for CI/CD builds }
    class function ForCI: TBuildConfig; static;

    { Returns a configuration for local development }
    class function ForDevelopment: TBuildConfig; static;

    { Returns a configuration for cross-compilation }
    class function ForCross(const ACpu, AOs: string): TBuildConfig; static;

    { Validates the configuration, returns empty string if valid }
    function Validate: string;

    { Returns a human-readable summary }
    function ToString: string;
  end;

implementation

class function TBuildConfig.Default: TBuildConfig;
begin
  // Initialize all fields to safe defaults
  Result := System.Default(TBuildConfig);

  // Execution configuration
  Result.SourceRoot := '';
  Result.SandboxRoot := 'sandbox';
  Result.LogDir := 'logs';
  Result.ParallelJobs := 0;  // Auto-detect
  Result.Verbose := False;

  // Control flags
  Result.AllowInstall := False;  // Safe default: don't install
  Result.DryRun := False;

  // Validation configuration
  Result.StrictResults := False;
  Result.StrictConfigPath := '';
  Result.ToolchainStrict := False;
  Result.LogVerbosity := 0;

  // Make configuration
  Result.MakeCmd := '';        // Auto-detect
  Result.CpuTarget := '';      // Native
  Result.OsTarget := '';       // Native
  Result.Prefix := '';
  Result.InstallPrefix := '';

  // Package selection
  Result.SelectedPackages := nil;
  Result.SkippedPackages := nil;
end;

class function TBuildConfig.ForCI: TBuildConfig;
begin
  Result := Default;

  // CI builds should be strict and verbose
  Result.StrictResults := True;
  Result.ToolchainStrict := True;
  Result.LogVerbosity := 1;  // Verbose for debugging
  Result.AllowInstall := True;  // CI builds typically install

  // Use all available cores
  Result.ParallelJobs := 0;  // Auto-detect (max cores)
end;

class function TBuildConfig.ForDevelopment: TBuildConfig;
begin
  Result := Default;

  // Development builds: fast iteration, less strict
  Result.StrictResults := False;
  Result.ToolchainStrict := False;
  Result.LogVerbosity := 0;
  Result.AllowInstall := False;  // Don't pollute system

  // Use fewer cores to leave room for IDE
  Result.ParallelJobs := 2;
end;

class function TBuildConfig.ForCross(const ACpu, AOs: string): TBuildConfig;
begin
  Result := Default;

  // Cross-compilation settings
  Result.CpuTarget := ACpu;
  Result.OsTarget := AOs;

  // Cross builds should be strict
  Result.StrictResults := True;
  Result.ToolchainStrict := True;
end;

function TBuildConfig.Validate: string;
begin
  Result := '';

  // Validate SourceRoot if specified
  if (SourceRoot <> '') and not DirectoryExists(SourceRoot) then
  begin
    Result := 'SourceRoot directory does not exist: ' + SourceRoot;
    Exit;
  end;

  // Validate ParallelJobs
  if ParallelJobs < 0 then
  begin
    Result := 'ParallelJobs must be >= 0';
    Exit;
  end;

  // Validate LogVerbosity
  if (LogVerbosity < 0) or (LogVerbosity > 1) then
  begin
    Result := 'LogVerbosity must be 0 or 1';
    Exit;
  end;

  // Validate StrictConfigPath if specified
  if (StrictConfigPath <> '') and not FileExists(StrictConfigPath) then
  begin
    Result := 'StrictConfigPath file does not exist: ' + StrictConfigPath;
    Exit;
  end;

  // Validate cross-compilation targets
  if (CpuTarget <> '') and (OsTarget = '') then
  begin
    Result := 'OsTarget required when CpuTarget is specified';
    Exit;
  end;

  if (OsTarget <> '') and (CpuTarget = '') then
  begin
    Result := 'CpuTarget required when OsTarget is specified';
    Exit;
  end;
end;

function TBuildConfig.ToString: string;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('TBuildConfig:');
    Lines.Add('  SourceRoot: ' + SourceRoot);
    Lines.Add('  SandboxRoot: ' + SandboxRoot);
    Lines.Add('  LogDir: ' + LogDir);
    Lines.Add('  ParallelJobs: ' + IntToStr(ParallelJobs));
    Lines.Add('  Verbose: ' + BoolToStr(Verbose, True));
    Lines.Add('  AllowInstall: ' + BoolToStr(AllowInstall, True));
    Lines.Add('  DryRun: ' + BoolToStr(DryRun, True));
    Lines.Add('  StrictResults: ' + BoolToStr(StrictResults, True));
    Lines.Add('  StrictConfigPath: ' + StrictConfigPath);
    Lines.Add('  ToolchainStrict: ' + BoolToStr(ToolchainStrict, True));
    Lines.Add('  LogVerbosity: ' + IntToStr(LogVerbosity));
    Lines.Add('  MakeCmd: ' + MakeCmd);
    if (CpuTarget <> '') or (OsTarget <> '') then
      Lines.Add('  Target: ' + CpuTarget + '-' + OsTarget);
    if Prefix <> '' then
      Lines.Add('  Prefix: ' + Prefix);
    if InstallPrefix <> '' then
      Lines.Add('  InstallPrefix: ' + InstallPrefix);
    if Length(SelectedPackages) > 0 then
      Lines.Add('  SelectedPackages: ' + IntToStr(Length(SelectedPackages)) + ' packages');
    if Length(SkippedPackages) > 0 then
      Lines.Add('  SkippedPackages: ' + IntToStr(Length(SkippedPackages)) + ' packages');

    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.
