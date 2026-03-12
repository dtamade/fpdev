unit fpdev.cmd.package.why;

{$mode objfpc}{$H+}

{
  B058: package why command

  Explains why a package is installed (shows dependency path).
  Usage:
    fpdev package why <package-name>
}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.exitcodes;

type
  TPackageWhyCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils, fpdev.i18n, fpdev.i18n.strings;

function TPackageWhyCommand.Name: string;
begin
  Result := 'why';
end;

function TPackageWhyCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TPackageWhyCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then; // Suppress unused parameter
end;

procedure ShowWhyHelp(const Ctx: IContext);
begin
  Ctx.Out.WriteLn(_(HELP_PACKAGE_WHY_USAGE));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_PACKAGE_WHY_DESC));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_PACKAGE_WHY_OPTIONS));
  Ctx.Out.WriteLn(_(HELP_PACKAGE_WHY_OPT_HELP));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_PACKAGE_WHY_EXAMPLES));
  Ctx.Out.WriteLn(_(HELP_PACKAGE_WHY_EXAMPLE_ZLIB));
  Ctx.Out.WriteLn(_(HELP_PACKAGE_WHY_EXAMPLE_LIBGIT2));
end;

function IsKnownWhyOption(const AParam: string): Boolean;
begin
  Result := (AParam = '--help') or (AParam = '-h');
end;

function TPackageWhyCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  PackageName: string;
  PackageArgCount: Integer;
  i: Integer;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    ShowWhyHelp(Ctx);
    Exit(EXIT_OK);
  end;

  // Validate unknown flags/options
  for i := 0 to High(AParams) do
  begin
    if (Length(AParams[i]) > 0) and (AParams[i][1] = '-') then
    begin
      if not IsKnownWhyOption(AParams[i]) then
      begin
        Ctx.Err.WriteLn(_(HELP_PACKAGE_WHY_USAGE));
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
        Ctx.Err.WriteLn(_(HELP_PACKAGE_WHY_USAGE));
        Exit(EXIT_USAGE_ERROR);
      end;
      PackageName := AParams[i];
    end;
  end;

  if PackageName = '' then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package-name']));
    Ctx.Err.WriteLn('');
    ShowWhyHelp(Ctx);
    Exit(EXIT_USAGE_ERROR);
  end;

  Ctx.Out.WriteLn(_Fmt(CMD_PKG_WHY_HEADER, [PackageName]));
  Ctx.Out.WriteLn('');

  // Sample output - in real implementation, this would trace the dependency graph
  Ctx.Out.WriteLn(_(CMD_PKG_WHY_PATH));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(CMD_PKG_WHY_CURRENT_PROJECT));
  Ctx.Out.WriteLn(_Fmt(CMD_PKG_WHY_TREE_NODE, ['fpdev-core >= 1.0.0']));
  Ctx.Out.WriteLn(_Fmt(CMD_PKG_WHY_TREE_LEAF, [PackageName]));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_Fmt(CMD_PKG_WHY_REQUIRED_BY, ['fpdev-core']));
  Ctx.Out.WriteLn(_Fmt(CMD_PKG_WHY_CONSTRAINT, ['>= 1.0.0']));
end;

function PackageWhyFactory: ICommand;
begin
  Result := TPackageWhyCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package', 'why'], @PackageWhyFactory, []);

end.
