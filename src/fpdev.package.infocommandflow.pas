unit fpdev.package.infocommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.package.types;

type
  TPackageInfoCommandPlan = record
    PackageName: string;
  end;

  TPackageInfoCommandGetInstalledPackagesFunc = function: TPackageArray of object;
  TPackageInfoCommandShowInfoFunc = function(
    const APackageName: string;
    Outp: IOutput
  ): Boolean of object;

function PreparePackageInfoCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageInfoCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageInfoCommandPlanCore(
  const APlan: TPackageInfoCommandPlan;
  const AOut, AErr: IOutput;
  AGetInstalledPackages: TPackageInfoCommandGetInstalledPackagesFunc;
  AShowPackageInfo: TPackageInfoCommandShowInfoFunc
): Integer;

implementation

uses
  SysUtils,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteInfoUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_PACKAGE_INFO_USAGE));
end;

procedure WriteInfoHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_PACKAGE_INFO_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_INFO_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_INFO_OPT_HELP));
end;

function PreparePackageInfoCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageInfoCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
begin
  Result := EXIT_OK;
  APlan := Default(TPackageInfoCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteInfoHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteInfoUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) > 1 then
  begin
    AShouldExit := True;
    WriteInfoUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.PackageName := Trim(GetPositionalArg(AParams, 0));
  if APlan.PackageName = '' then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    WriteInfoUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;
end;

function ExecutePackageInfoCommandPlanCore(
  const APlan: TPackageInfoCommandPlan;
  const AOut, AErr: IOutput;
  AGetInstalledPackages: TPackageInfoCommandGetInstalledPackagesFunc;
  AShowPackageInfo: TPackageInfoCommandShowInfoFunc
): Integer;
var
  InstalledPackages: TPackageArray;
  I: Integer;
  IsInstalled: Boolean;
begin
  Result := EXIT_ERROR;

  if (not Assigned(AGetInstalledPackages)) or
     (not Assigned(AShowPackageInfo)) then
    Exit(EXIT_ERROR);

  InstalledPackages := AGetInstalledPackages();
  IsInstalled := False;
  for I := 0 to High(InstalledPackages) do
    if SameText(InstalledPackages[I].Name, APlan.PackageName) then
    begin
      IsInstalled := True;
      Break;
    end;

  if not IsInstalled then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_FOUND, [APlan.PackageName]));
    Exit(EXIT_NOT_FOUND);
  end;

  if AShowPackageInfo(APlan.PackageName, AOut) then
    Exit(EXIT_OK);
end;

end.
