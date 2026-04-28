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
  SysUtils,
  fpdev.command.intf, fpdev.command.registry;

type
  TPackageWhyCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.package.whycommandflow;

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

function TPackageWhyCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LPlan: TPackageWhyCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageWhyCommandPlanCore(
    AParams,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  Result := ExecutePackageWhyCommandPlanCore(
    LPlan,
    Ctx.Out,
    Ctx.Err
  );
end;

function PackageWhyFactory: ICommand;
begin
  Result := TPackageWhyCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package', 'why'], @PackageWhyFactory, []);

end.
