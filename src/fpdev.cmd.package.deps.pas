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

uses fpdev.cmd.utils, fpdev.i18n, fpdev.i18n.strings;

function TPackageDepsCommand.Name: string;
begin
  Result := 'deps';
end;

function TPackageDepsCommand.Aliases: TStringArray;
begin
  Result := nil;
  SetLength(Result, 1);
  Result[0] := 'dependencies';
end;

function TPackageDepsCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then; // Suppress unused parameter
end;

procedure ShowDepsHelp(const Ctx: IContext);
begin
  Ctx.Out.WriteLn('Usage: fpdev package deps [options] [package-name]');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Show dependency tree for a package or the current project.');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Options:');
  Ctx.Out.WriteLn('  --tree       Show as indented tree (default)');
  Ctx.Out.WriteLn('  --flat       Show as flat list');
  Ctx.Out.WriteLn('  --depth=N    Maximum depth to display (default: unlimited)');
  Ctx.Out.WriteLn('  -h, --help   Show this help');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Examples:');
  Ctx.Out.WriteLn('  fpdev package deps             # Show deps for current project');
  Ctx.Out.WriteLn('  fpdev package deps mylib       # Show deps for mylib');
  Ctx.Out.WriteLn('  fpdev package deps --flat      # Flat list format');
end;

procedure PrintDepTree(const Ctx: IContext; const ADeps: TStringArray;
  const APrefix: string; ADepth, AMaxDepth: Integer);
var
  i: Integer;
  Connector, NewPrefix: string;
begin
  if (AMaxDepth > 0) and (ADepth > AMaxDepth) then
    Exit;

  for i := 0 to High(ADeps) do
  begin
    if i = High(ADeps) then
    begin
      Connector := '└── ';
      NewPrefix := APrefix + '    ';
    end
    else
    begin
      Connector := '├── ';
      NewPrefix := APrefix + '│   ';
    end;

    Ctx.Out.WriteLn(APrefix + Connector + ADeps[i]);
    // In a real implementation, we would recursively show sub-dependencies
    // For now, we show a placeholder
  end;
end;

function TPackageDepsCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  PackageName: string;
  ShowTree, ShowFlat: Boolean;
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
  ShowTree := HasFlag(AParams, 'tree') or (not HasFlag(AParams, 'flat'));
  ShowFlat := HasFlag(AParams, 'flat');
  MaxDepth := 0;
  if GetFlagValue(AParams, 'depth', MaxDepthStr) then
    TryStrToInt(MaxDepthStr, MaxDepth);

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
    PackageName := '(current project)';

  Ctx.Out.WriteLn('Dependencies for: ' + PackageName);
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
  Ctx.Out.WriteLn('Total: ' + IntToStr(Length(SampleDeps)) + ' direct dependencies');
end;

function PackageDepsFactory: ICommand;
begin
  Result := TPackageDepsCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package', 'deps'], @PackageDepsFactory, ['dependencies']);

end.
