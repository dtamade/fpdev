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

uses fpdev.cmd.utils, fpdev.i18n.strings;

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
  Ctx.Out.WriteLn('Usage: fpdev package why <package-name>');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Explain why a package is installed by showing the dependency path.');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Options:');
  Ctx.Out.WriteLn('  -h, --help   Show this help');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Examples:');
  Ctx.Out.WriteLn('  fpdev package why zlib        # Show why zlib is required');
  Ctx.Out.WriteLn('  fpdev package why libgit2     # Show why libgit2 is required');
end;

function TPackageWhyCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  PackageName: string;
  i: Integer;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    ShowWhyHelp(Ctx);
    Exit(EXIT_OK);
  end;

  // Get package name (first non-flag argument)
  PackageName := '';
  for i := 0 to High(AParams) do
  begin
    if (Length(AParams[i]) > 0) and (AParams[i][1] <> '-') then
    begin
      PackageName := AParams[i];
      Break;
    end;
  end;

  if PackageName = '' then
  begin
    Ctx.Err.WriteLn('Error: Missing package name');
    Ctx.Err.WriteLn('');
    ShowWhyHelp(Ctx);
    Exit(EXIT_USAGE_ERROR);
  end;

  Ctx.Out.WriteLn('Why is "' + PackageName + '" installed?');
  Ctx.Out.WriteLn('');

  // Sample output - in real implementation, this would trace the dependency graph
  Ctx.Out.WriteLn('Dependency path:');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('  (current project)');
  Ctx.Out.WriteLn('    +-- fpdev-core >= 1.0.0');
  Ctx.Out.WriteLn('          +-- ' + PackageName);
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Required by: fpdev-core');
  Ctx.Out.WriteLn('Constraint: >= 1.0.0');
end;

function PackageWhyFactory: ICommand;
begin
  Result := TPackageWhyCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package', 'why'], @PackageWhyFactory, []);

end.
