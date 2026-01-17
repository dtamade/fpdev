unit fpdev.types;

{$mode objfpc}{$H+}

{
  **FPDev Type System**: Strong typing for safer code

  This unit provides type-safe enumerations to replace string-based types.
  Inspired by Rust's enum system, these types provide compile-time safety
  and make impossible states unrepresentable.

  Philosophy (from Rust):
  - "Make invalid states unrepresentable"
  - "Use types to document intent"
  - "Compiler-enforced correctness"
}

interface

uses
  SysUtils;

type
  {** Installation Modes **}
  TInstallMode = (
    imBinary,     // Install from pre-built binary
    imSource,     // Install from source code
    imAuto        // Auto-detect (binary if available, else source)
  );

  {** Installation Scopes **}
  TInstallScope = (
    isProject,    // Project-local installation (.fpdev/)
    isUser,       // User-level installation (~/.fpdev/)
    isSystem      // System-wide installation (requires admin)
  );

  {** Operation Results **}
  TOperationResult = (
    orSuccess,    // Operation completed successfully
    orFailure,    // Operation failed
    orCancelled,  // Operation was cancelled by user
    orPartial     // Operation partially succeeded
  );

  {** Build Phases **}
  TBuildPhase = (
    bpPreflight,  // Pre-build checks
    bpCompiler,   // Compiler compilation
    bpRTL,        // RTL compilation
    bpPackages,   // Package compilation
    bpInstall,    // Installation
    bpVerify      // Post-build verification
  );

  {** Source Types **}
  TSourceType = (
    stRelease,    // Official release (tagged)
    stDevelopment,// Development branch
    stCustom      // Custom/forked repository
  );

  {** Component Status **}
  TComponentStatus = (
    csNotInstalled,  // Component not installed
    csInstalling,    // Installation in progress
    csInstalled,     // Component installed and verified
    csBroken,        // Component installed but broken
    csOutdated       // Component installed but outdated
  );

// Helper functions for type conversion and validation

{** Convert string to TInstallMode, raises exception if invalid **}
function StringToInstallMode(const S: string): TInstallMode;

{** Convert TInstallMode to string **}
function InstallModeToString(const Mode: TInstallMode): string;

{** Try to convert string to TInstallMode, returns False if invalid **}
function TryStringToInstallMode(const S: string; out Mode: TInstallMode): Boolean;

{** Convert string to TInstallScope **}
function StringToInstallScope(const S: string): TInstallScope;

{** Convert TInstallScope to string **}
function InstallScopeToString(const Scope: TInstallScope): string;

{** Try to convert string to TInstallScope **}
function TryStringToInstallScope(const S: string; out Scope: TInstallScope): Boolean;

{** Convert TOperationResult to boolean (True if Success) **}
function OperationResultToBool(const OpResult: TOperationResult): Boolean;

{** Convert boolean to TOperationResult **}
function BoolToOperationResult(const Success: Boolean): TOperationResult;

implementation

function StringToInstallMode(const S: string): TInstallMode;
begin
  if not TryStringToInstallMode(S, Result) then
    raise Exception.CreateFmt('Invalid install mode: %s (valid: binary, source, auto)', [S]);
end;

function InstallModeToString(const Mode: TInstallMode): string;
begin
  case Mode of
    imBinary: Result := 'binary';
    imSource: Result := 'source';
    imAuto:   Result := 'auto';
  end;
end;

function TryStringToInstallMode(const S: string; out Mode: TInstallMode): Boolean;
var
  Lower: string;
begin
  Lower := LowerCase(Trim(S));
  Result := True;

  if (Lower = 'binary') or (Lower = 'bin') then
    Mode := imBinary
  else if (Lower = 'source') or (Lower = 'src') then
    Mode := imSource
  else if (Lower = 'auto') or (Lower = 'default') then
    Mode := imAuto
  else
    Result := False;
end;

function StringToInstallScope(const S: string): TInstallScope;
begin
  if not TryStringToInstallScope(S, Result) then
    raise Exception.CreateFmt('Invalid install scope: %s (valid: project, user, system)', [S]);
end;

function InstallScopeToString(const Scope: TInstallScope): string;
begin
  case Scope of
    isProject: Result := 'project';
    isUser:    Result := 'user';
    isSystem:  Result := 'system';
  end;
end;

function TryStringToInstallScope(const S: string; out Scope: TInstallScope): Boolean;
var
  Lower: string;
begin
  Lower := LowerCase(Trim(S));
  Result := True;

  if (Lower = 'project') or (Lower = 'local') then
    Scope := isProject
  else if (Lower = 'user') or (Lower = 'global') then
    Scope := isUser
  else if (Lower = 'system') or (Lower = 'sys') then
    Scope := isSystem
  else
    Result := False;
end;

function OperationResultToBool(const OpResult: TOperationResult): Boolean;
begin
  Result := (OpResult = orSuccess);
end;

function BoolToOperationResult(const Success: Boolean): TOperationResult;
begin
  if Success then
    Result := orSuccess
  else
    Result := orFailure;
end;

end.
