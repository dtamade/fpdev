unit fpdev.lazarus.sourceflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TLazarusLegacySourceArgs = array of string;

  TLazarusLegacySourceClonePlan = record
    Version: string;
    RefName: string;
    SourcePath: string;
    RepositoryURL: string;
  end;

  TLazarusLegacySourceUpdatePlan = record
    Version: string;
    SourcePath: string;
  end;

function ResolveLazarusLegacySourceVersionCore(
  const ARequestedVersion, ACurrentVersion, ADefaultVersion: string
): string;

function BuildLazarusLegacySourcePathCore(
  const ASourceRoot, AVersion: string
): string;

function IsValidLazarusLegacySourceTreeCore(const APath: string): Boolean;

function CreateLazarusLegacyClonePlanCore(
  const ARequestedVersion, ADefaultVersion, ASourceRoot, ARepositoryURL, ARefName: string
): TLazarusLegacySourceClonePlan;

function CreateLazarusLegacyUpdatePlanCore(
  const ARequestedVersion, ACurrentVersion, ADefaultVersion, ASourceRoot: string
): TLazarusLegacySourceUpdatePlan;

function BuildLazarusLegacyMakeParamsCore(
  const AParallelJobs: Integer;
  const AFPCPath: string
): TLazarusLegacySourceArgs;

implementation

procedure AppendSourceArg(
  var AArgs: TLazarusLegacySourceArgs;
  const AValue: string
);
begin
  SetLength(AArgs, Length(AArgs) + 1);
  AArgs[High(AArgs)] := AValue;
end;

function ResolveLazarusLegacySourceVersionCore(
  const ARequestedVersion, ACurrentVersion, ADefaultVersion: string
): string;
begin
  if ARequestedVersion <> '' then
    Exit(ARequestedVersion);
  if ACurrentVersion <> '' then
    Exit(ACurrentVersion);
  Result := ADefaultVersion;
end;

function BuildLazarusLegacySourcePathCore(
  const ASourceRoot, AVersion: string
): string;
begin
  Result := ASourceRoot + PathDelim + 'lazarus-' + AVersion;
end;

function IsValidLazarusLegacySourceTreeCore(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath) and
    DirectoryExists(APath + PathDelim + 'ide') and
    DirectoryExists(APath + PathDelim + 'lcl') and
    DirectoryExists(APath + PathDelim + 'packager');
end;

function CreateLazarusLegacyClonePlanCore(
  const ARequestedVersion, ADefaultVersion, ASourceRoot, ARepositoryURL, ARefName: string
): TLazarusLegacySourceClonePlan;
begin
  Result := Default(TLazarusLegacySourceClonePlan);
  Result.Version := ResolveLazarusLegacySourceVersionCore(
    ARequestedVersion,
    '',
    ADefaultVersion
  );
  Result.RefName := ARefName;
  Result.SourcePath := BuildLazarusLegacySourcePathCore(ASourceRoot, Result.Version);
  Result.RepositoryURL := ARepositoryURL;
end;

function CreateLazarusLegacyUpdatePlanCore(
  const ARequestedVersion, ACurrentVersion, ADefaultVersion, ASourceRoot: string
): TLazarusLegacySourceUpdatePlan;
begin
  Result := Default(TLazarusLegacySourceUpdatePlan);
  Result.Version := ResolveLazarusLegacySourceVersionCore(
    ARequestedVersion,
    ACurrentVersion,
    ADefaultVersion
  );
  Result.SourcePath := BuildLazarusLegacySourcePathCore(ASourceRoot, Result.Version);
end;

function BuildLazarusLegacyMakeParamsCore(
  const AParallelJobs: Integer;
  const AFPCPath: string
): TLazarusLegacySourceArgs;
begin
  Result := nil;
  AppendSourceArg(Result, 'clean');
  AppendSourceArg(Result, 'all');

  if AParallelJobs > 1 then
    AppendSourceArg(Result, '-j' + IntToStr(AParallelJobs));

  if AFPCPath <> '' then
    AppendSourceArg(Result, 'PP=' + AFPCPath);
end;

end.
