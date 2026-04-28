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
  SysUtils,
  fpdev.command.intf, fpdev.command.registry;

type
  TPackageDepsCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.package.depscommandflow;

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

function TPackageDepsCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LPlan: TPackageDepsCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageDepsCommandPlanCore(
    AParams,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  Result := ExecutePackageDepsCommandPlanCore(
    LPlan,
    Ctx.Out,
    Ctx.Err
  );
end;

function PackageDepsFactory: ICommand;
begin
  Result := TPackageDepsCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package', 'deps'], @PackageDepsFactory, []);

end.
