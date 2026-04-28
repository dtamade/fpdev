unit fpdev.package.whycommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TPackageWhyCommandPlan = record
    PackageName: string;
  end;

function PreparePackageWhyCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageWhyCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageWhyCommandPlanCore(
  const APlan: TPackageWhyCommandPlan;
  const AOut, AErr: IOutput
): Integer;

implementation

uses
  SysUtils,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteWhyUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_PACKAGE_WHY_USAGE));
end;

procedure WriteWhyHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_PACKAGE_WHY_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_WHY_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_WHY_OPTIONS));
  AOut.WriteLn(_(HELP_PACKAGE_WHY_OPT_HELP));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_WHY_EXAMPLES));
  AOut.WriteLn(_(HELP_PACKAGE_WHY_EXAMPLE_ZLIB));
  AOut.WriteLn(_(HELP_PACKAGE_WHY_EXAMPLE_LIBGIT2));
end;

function PreparePackageWhyCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageWhyCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
begin
  Result := EXIT_OK;
  APlan := Default(TPackageWhyCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteWhyHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteWhyUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) > 1 then
  begin
    AShouldExit := True;
    WriteWhyUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.PackageName := Trim(GetPositionalArg(AParams, 0));
  if APlan.PackageName = '' then
  begin
    AShouldExit := True;
    if AErr <> nil then
    begin
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package-name']));
      AErr.WriteLn('');
    end;
    WriteWhyHelp(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;
end;

function ExecutePackageWhyCommandPlanCore(
  const APlan: TPackageWhyCommandPlan;
  const AOut, AErr: IOutput
): Integer;
begin
  if AErr <> nil then;
  Result := EXIT_OK;

  if AOut <> nil then
  begin
    AOut.WriteLn(_Fmt(CMD_PKG_WHY_HEADER, [APlan.PackageName]));
    AOut.WriteLn('');
    AOut.WriteLn(_(CMD_PKG_WHY_PATH));
    AOut.WriteLn('');
    AOut.WriteLn(_(CMD_PKG_WHY_CURRENT_PROJECT));
    AOut.WriteLn(_Fmt(CMD_PKG_WHY_TREE_NODE, ['fpdev-core >= 1.0.0']));
    AOut.WriteLn(_Fmt(CMD_PKG_WHY_TREE_LEAF, [APlan.PackageName]));
    AOut.WriteLn('');
    AOut.WriteLn(_Fmt(CMD_PKG_WHY_REQUIRED_BY, ['fpdev-core']));
    AOut.WriteLn(_Fmt(CMD_PKG_WHY_CONSTRAINT, ['>= 1.0.0']));
  end;
end;

end.
