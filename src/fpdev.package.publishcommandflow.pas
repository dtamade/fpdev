unit fpdev.package.publishcommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.package.types;

type
  TPackagePublishCommandPlan = record
    PackageName: string;
  end;

  TPackagePublishCommandGetInstalledPackagesFunc = function: TPackageArray of object;
  TPackagePublishCommandPublishFunc = function(
    const APackageName: string;
    Outp: IOutput;
    Errp: IOutput
  ): Boolean of object;
  TPackagePublishCommandGetLastExitCodeFunc = function: Integer of object;

function PreparePackagePublishCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackagePublishCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackagePublishCommandPlanCore(
  const APlan: TPackagePublishCommandPlan;
  const AOut, AErr: IOutput;
  AGetInstalledPackages: TPackagePublishCommandGetInstalledPackagesFunc;
  APublishPackage: TPackagePublishCommandPublishFunc;
  AGetLastExitCode: TPackagePublishCommandGetLastExitCodeFunc
): Integer;

implementation

uses
  SysUtils,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WritePublishUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_PACKAGE_PUBLISH_USAGE));
end;

procedure WritePublishHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_PACKAGE_PUBLISH_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_PUBLISH_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_PUBLISH_OPT_HELP));
end;

function PreparePackagePublishCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackagePublishCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  I: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TPackagePublishCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WritePublishHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WritePublishUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  if Length(AParams) < 1 then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    WritePublishUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.PackageName := AParams[0];
  if Trim(APlan.PackageName) = '' then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    WritePublishUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  for I := 1 to High(AParams) do
    if (AParams[I] <> '') and (AParams[I][1] <> '-') then
    begin
      AShouldExit := True;
      WritePublishUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;
end;

function ExecutePackagePublishCommandPlanCore(
  const APlan: TPackagePublishCommandPlan;
  const AOut, AErr: IOutput;
  AGetInstalledPackages: TPackagePublishCommandGetInstalledPackagesFunc;
  APublishPackage: TPackagePublishCommandPublishFunc;
  AGetLastExitCode: TPackagePublishCommandGetLastExitCodeFunc
): Integer;
var
  InstalledPackages: TPackageArray;
  I: Integer;
  IsInstalled: Boolean;
  PackageInstallPath: string;
  MetadataPath: string;
begin
  Result := EXIT_ERROR;

  if (not Assigned(AGetInstalledPackages)) or
     (not Assigned(APublishPackage)) or
     (not Assigned(AGetLastExitCode)) then
    Exit(EXIT_ERROR);

  InstalledPackages := AGetInstalledPackages();
  IsInstalled := False;
  PackageInstallPath := '';
  for I := 0 to High(InstalledPackages) do
    if SameText(InstalledPackages[I].Name, APlan.PackageName) then
    begin
      IsInstalled := True;
      PackageInstallPath := InstalledPackages[I].InstallPath;
      Break;
    end;

  if not IsInstalled then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_FOUND, [APlan.PackageName]));
    Exit(EXIT_NOT_FOUND);
  end;

  if PackageInstallPath <> '' then
  begin
    MetadataPath := IncludeTrailingPathDelimiter(PackageInstallPath) + 'package.json';
    if not FileExists(MetadataPath) then
    begin
      if AErr <> nil then
        AErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_META_NOT_FOUND,
          [_(MSG_PKG_META_HINT)]));
      Exit(EXIT_NOT_FOUND);
    end;
  end;

  if APublishPackage(APlan.PackageName, AOut, AErr) then
    Exit(EXIT_OK);

  Result := AGetLastExitCode();
  if Result = EXIT_OK then
    Result := EXIT_ERROR;
end;

end.
