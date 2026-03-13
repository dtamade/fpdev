unit fpdev.cli.bootstrap;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.output.intf;

procedure ExecuteRootHelpCore(const AParams: TStringArray; const AOut: IOutput);
function CreateDefaultContextCore(const AOut, AErr: IOutput): IContext;
function DispatchArgsWithRegistryCore(const AArgs: TStringArray; const Ctx: IContext): Integer;

implementation

uses
  fpdev.command.context,
  fpdev.command.imports,
  fpdev.command.registry,
  fpdev.help.rootview;

procedure ExecuteRootHelpCore(const AParams: TStringArray; const AOut: IOutput);
begin
  if AParams <> nil then;
  WriteRootHelpCore(AOut);
end;

function CreateDefaultContextCore(const AOut, AErr: IOutput): IContext;
begin
  Result := TDefaultCommandContext.Create('', AOut, AErr);
end;

function DispatchArgsWithRegistryCore(const AArgs: TStringArray; const Ctx: IContext): Integer;
begin
  EnsureCommandImports;
  Result := GlobalCommandRegistry.DispatchPath(AArgs, Ctx);
end;

end.
