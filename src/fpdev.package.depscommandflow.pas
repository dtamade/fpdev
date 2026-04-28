unit fpdev.package.depscommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TPackageDepsCommandPlan = record
    PackageName: string;
    ShowFlat: Boolean;
    MaxDepth: Integer;
  end;

function PreparePackageDepsCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageDepsCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageDepsCommandPlanCore(
  const APlan: TPackageDepsCommandPlan;
  const AOut, AErr: IOutput
): Integer;

implementation

uses
  SysUtils,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteDepsUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_PACKAGE_DEPS_USAGE));
end;

procedure WriteDepsHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_PACKAGE_DEPS_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_OPTIONS));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_OPT_TREE));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_OPT_FLAT));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_OPT_DEPTH));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_OPT_HELP));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_EXAMPLES));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_EXAMPLE_CURRENT));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_EXAMPLE_PACKAGE));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_EXAMPLE_FLAT));
end;

procedure PrintDepTree(const AOut: IOutput; const ADeps: TStringArray;
  const APrefix: string; ADepth, AMaxDepth: Integer);
var
  I: Integer;
begin
  if (AOut = nil) or ((AMaxDepth > 0) and (ADepth > AMaxDepth)) then
    Exit;

  for I := 0 to High(ADeps) do
    AOut.WriteLn(APrefix + '+-- ' + ADeps[I]);
end;

function BuildSampleDeps: TStringArray;
begin
  Result := nil;
  SetLength(Result, 3);
  Result[0] := 'fpdev-core >= 1.0.0';
  Result[1] := 'libgit2 >= 0.28.0';
  Result[2] := 'zlib >= 1.2.0';
end;

function PreparePackageDepsCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageDepsCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  MaxDepthStr: string;
begin
  Result := EXIT_OK;
  APlan := Default(TPackageDepsCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteDepsHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, ['--tree', '--flat', '--depth='], UnknownOption) then
  begin
    AShouldExit := True;
    WriteDepsUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.ShowFlat := HasFlag(AParams, 'flat');
  APlan.MaxDepth := 0;
  if GetFlagValue(AParams, 'depth', MaxDepthStr) then
  begin
    if (not TryStrToInt(MaxDepthStr, APlan.MaxDepth)) or (APlan.MaxDepth < 0) then
    begin
      AShouldExit := True;
      WriteDepsUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;
  end;

  if CountPositionalArgs(AParams) > 1 then
  begin
    AShouldExit := True;
    WriteDepsUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.PackageName := GetPositionalArg(AParams, 0);
end;

function ExecutePackageDepsCommandPlanCore(
  const APlan: TPackageDepsCommandPlan;
  const AOut, AErr: IOutput
): Integer;
var
  LPackageName: string;
  LSampleDeps: TStringArray;
  I: Integer;
begin
  if AErr <> nil then;
  Result := EXIT_OK;

  LPackageName := Trim(APlan.PackageName);
  if LPackageName = '' then
    LPackageName := _(CMD_PKG_DEPS_CURRENT_PROJECT);

  if AOut <> nil then
  begin
    AOut.WriteLn(_Fmt(CMD_PKG_DEPS_HEADER, [LPackageName]));
    AOut.WriteLn('');
  end;

  LSampleDeps := BuildSampleDeps;
  if APlan.ShowFlat then
  begin
    if AOut <> nil then
      for I := 0 to High(LSampleDeps) do
        AOut.WriteLn('  ' + LSampleDeps[I]);
  end
  else
  begin
    if AOut <> nil then
      AOut.WriteLn(LPackageName);
    PrintDepTree(AOut, LSampleDeps, '', 1, APlan.MaxDepth);
  end;

  if AOut <> nil then
  begin
    AOut.WriteLn('');
    AOut.WriteLn(_Fmt(CMD_PKG_DEPS_TOTAL, [Length(LSampleDeps)]));
  end;
end;

end.
