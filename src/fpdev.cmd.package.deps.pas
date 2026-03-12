unit fpdev.cmd.package.deps;

{$mode objfpc}{$H+}

{
  B057: package deps command

  Shows dependency tree for a package or the current project.
  Usage:
    fpdev package deps [package-name]
    fpdev package deps --tree
    fpdev package deps --flat
}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.exitcodes;

type
  TPackageDepsCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils, fpdev.i18n, fpdev.i18n.strings;

function TPackageDepsCommand.Name: string;
begin
  Result := 'deps';
end;

function TPackageDepsCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TPackageDepsCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then; // Suppress unused parameter
end;

procedure ShowDepsHelp(const Ctx: IContext);
begin
  Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_USAGE));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_DESC));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_OPTIONS));
  Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_OPT_TREE));
  Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_OPT_FLAT));
  Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_OPT_DEPTH));
  Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_OPT_HELP));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_EXAMPLES));
  Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_EXAMPLE_CURRENT));
  Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_EXAMPLE_PACKAGE));
  Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_EXAMPLE_FLAT));
end;

function IsKnownDepsOption(const AParam: string): Boolean;
begin
  Result :=
    (AParam = '--tree') or
    (AParam = '--flat') or
    (AParam = '--help') or
    (AParam = '-h') or
    (Pos('--depth=', AParam) = 1);
end;

procedure PrintDepTree(const Ctx: IContext; const ADeps: TStringArray;
  const APrefix: string; ADepth, AMaxDepth: Integer);
var
  i: Integer;
  Connector: string;
begin
  if (AMaxDepth > 0) and (ADepth > AMaxDepth) then
    Exit;

  for i := 0 to High(ADeps) do
  begin
    if i = High(ADeps) then
      Connector := '+-- '
    else
      Connector := '+-- ';

    Ctx.Out.WriteLn(APrefix + Connector + ADeps[i]);
    // In a real implementation, we would recursively show sub-dependencies
    // using: PrintDepTree(Ctx, SubDeps, NewPrefix, ADepth + 1, AMaxDepth);
  end;
end;

function TPackageDepsCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  PackageName: string;
  PackageArgCount: Integer;
  ShowFlat: Boolean;
  MaxDepthStr: string;
  MaxDepth, i: Integer;
  SampleDeps: TStringArray;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    ShowDepsHelp(Ctx);
    Exit(EXIT_OK);
  end;

  // Parse options
  ShowFlat := HasFlag(AParams, 'flat');
  MaxDepth := 0;
  if GetFlagValue(AParams, 'depth', MaxDepthStr) then
  begin
    if (not TryStrToInt(MaxDepthStr, MaxDepth)) or (MaxDepth < 0) then
    begin
      Ctx.Err.WriteLn(_(HELP_PACKAGE_DEPS_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
  end;

  // Validate unknown flags/options
  for i := 0 to High(AParams) do
  begin
    if (Length(AParams[i]) > 0) and (AParams[i][1] = '-') then
    begin
      if not IsKnownDepsOption(AParams[i]) then
      begin
        Ctx.Err.WriteLn(_(HELP_PACKAGE_DEPS_USAGE));
        Exit(EXIT_USAGE_ERROR);
      end;
    end;
  end;

  // Get package name (first non-flag argument)
  PackageName := '';
  PackageArgCount := 0;
  for i := 0 to High(AParams) do
  begin
    if (Length(AParams[i]) > 0) and (AParams[i][1] <> '-') then
    begin
      Inc(PackageArgCount);
      if PackageArgCount > 1 then
      begin
        Ctx.Err.WriteLn(_(HELP_PACKAGE_DEPS_USAGE));
        Exit(EXIT_USAGE_ERROR);
      end;
      PackageName := AParams[i];
    end;
  end;

  if PackageName = '' then
    PackageName := _(CMD_PKG_DEPS_CURRENT_PROJECT);

  Ctx.Out.WriteLn(_Fmt(CMD_PKG_DEPS_HEADER, [PackageName]));
  Ctx.Out.WriteLn('');

  // Sample output - in real implementation, this would query the package registry
  SampleDeps := nil;
  SetLength(SampleDeps, 3);
  SampleDeps[0] := 'fpdev-core >= 1.0.0';
  SampleDeps[1] := 'libgit2 >= 0.28.0';
  SampleDeps[2] := 'zlib >= 1.2.0';

  if ShowFlat then
  begin
    for i := 0 to High(SampleDeps) do
      Ctx.Out.WriteLn('  ' + SampleDeps[i]);
  end
  else
  begin
    Ctx.Out.WriteLn(PackageName);
    PrintDepTree(Ctx, SampleDeps, '', 1, MaxDepth);
  end;

  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_Fmt(CMD_PKG_DEPS_TOTAL, [Length(SampleDeps)]));
end;

function PackageDepsFactory: ICommand;
begin
  Result := TPackageDepsCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package', 'deps'], @PackageDepsFactory, []);

end.
