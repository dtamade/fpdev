unit fpdev.build.preflightflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.preflight;

type
  TBuildPreflightPolicyCheckFunc = function(
    const ASourceVersion: string;
    out AStatus, AReason, AMin, ARecommended, ACurrentFpcVersion: string
  ): Boolean of object;
  TBuildPreflightToolchainJSONFunc = function: string of object;
  TBuildPreflightHasMakeFunc = function: Boolean of object;
  TBuildPreflightCanWriteDirFunc = function(const APath: string): Boolean of object;

function BuildBuildPreflightInputsCore(
  const AVersion, ASourcePath, ASandboxRoot, ALogDir: string;
  AToolchainStrict, AAllowInstall: Boolean;
  APolicyCheck: TBuildPreflightPolicyCheckFunc;
  ABuildToolchainJSON: TBuildPreflightToolchainJSONFunc;
  AHasMake: TBuildPreflightHasMakeFunc;
  ACanWriteDir: TBuildPreflightCanWriteDirFunc
): TBuildPreflightInputs;

implementation

uses
  SysUtils;

procedure EnsureBuildPreflightDirCore(const APath: string);
begin
  if (APath <> '') and (not DirectoryExists(APath)) then
    ForceDirectories(APath);
end;

function BuildBuildPreflightInputsCore(
  const AVersion, ASourcePath, ASandboxRoot, ALogDir: string;
  AToolchainStrict, AAllowInstall: Boolean;
  APolicyCheck: TBuildPreflightPolicyCheckFunc;
  ABuildToolchainJSON: TBuildPreflightToolchainJSONFunc;
  AHasMake: TBuildPreflightHasMakeFunc;
  ACanWriteDir: TBuildPreflightCanWriteDirFunc
): TBuildPreflightInputs;
var
  LDestRoot: string;
begin
  Initialize(Result);

  Result.Version := AVersion;
  Result.SourcePath := ASourcePath;
  Result.SandboxRoot := ASandboxRoot;
  Result.LogDir := ALogDir;
  Result.ToolchainStrict := AToolchainStrict;
  Result.AllowInstall := AAllowInstall;
  Result.HasMake := False;
  Result.PolicyCheckPassed := True;
  Result.PolicyStatus := '';
  Result.PolicyReason := '';
  Result.PolicyMin := '';
  Result.PolicyRecommended := '';
  Result.CurrentFpcVersion := '';
  Result.ToolchainReportJSON := '';

  Result.SourceExists := DirectoryExists(ASourcePath);

  if AToolchainStrict then
  begin
    if Assigned(APolicyCheck) then
      Result.PolicyCheckPassed := APolicyCheck(
        AVersion,
        Result.PolicyStatus,
        Result.PolicyReason,
        Result.PolicyMin,
        Result.PolicyRecommended,
        Result.CurrentFpcVersion
      )
    else
      Result.PolicyCheckPassed := False;

    if Assigned(ABuildToolchainJSON) then
      Result.ToolchainReportJSON := ABuildToolchainJSON();
  end
  else if Assigned(AHasMake) then
    Result.HasMake := AHasMake();

  EnsureBuildPreflightDirCore(ASandboxRoot);
  EnsureBuildPreflightDirCore(ALogDir);

  if Assigned(ACanWriteDir) then
  begin
    Result.SandboxWritable := ACanWriteDir(ASandboxRoot);
    Result.LogWritable := ACanWriteDir(ALogDir);
  end
  else
  begin
    Result.SandboxWritable := False;
    Result.LogWritable := False;
  end;

  LDestRoot := IncludeTrailingPathDelimiter(ASandboxRoot) + 'fpc-' + AVersion;
  Result.SandboxDestRoot := LDestRoot;

  if AAllowInstall and (not DirectoryExists(LDestRoot)) then
    EnsureBuildPreflightDirCore(LDestRoot);

  Result.SandboxDestExists := DirectoryExists(LDestRoot);
  Result.SandboxDestWritable := Result.SandboxDestExists and
    Assigned(ACanWriteDir) and ACanWriteDir(LDestRoot);
end;

end.
