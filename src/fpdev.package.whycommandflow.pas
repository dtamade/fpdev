unit fpdev.package.whycommandflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf;

type
  TPackageWhyCommandPlan = record
    PackageName: string;
  end;

  TPackageWhyTracer = function(const APackageName: string): TStringArray of object;

function PreparePackageWhyCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageWhyCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageWhyCommandPlanCore(
  const APlan: TPackageWhyCommandPlan;
  const AOut, AErr: IOutput;
  ATrace: TPackageWhyTracer
): Integer;

implementation

uses
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
  const AOut, AErr: IOutput;
  ATrace: TPackageWhyTracer
): Integer;
var
  LPath: TStringArray;
  I: Integer;
begin
  if AErr <> nil then;
  Result := EXIT_OK;

  if AOut <> nil then
  begin
    AOut.WriteLn(_Fmt(CMD_PKG_WHY_HEADER, [APlan.PackageName]));
    AOut.WriteLn('');
  end;

  LPath := nil;
  if Assigned(ATrace) then
    LPath := ATrace(APlan.PackageName);

  if Length(LPath) < 2 then
  begin
    if AOut <> nil then
      AOut.WriteLn(_Fmt(CMD_PKG_WHY_NOT_FOUND, [APlan.PackageName]));
    Exit(EXIT_OK);
  end;

  if AOut <> nil then
  begin
    AOut.WriteLn(_(CMD_PKG_WHY_PATH));
    AOut.WriteLn('');
    AOut.WriteLn('  ' + LPath[0]);
    for I := 1 to High(LPath) do
      AOut.WriteLn('  ' + StringOfChar(' ', (I - 1) * 2) + '+-- ' + LPath[I]);
    AOut.WriteLn('');
    AOut.WriteLn(_Fmt(CMD_PKG_WHY_REQUIRED_BY, [LPath[High(LPath) - 1]]));
  end;
end;

end.
