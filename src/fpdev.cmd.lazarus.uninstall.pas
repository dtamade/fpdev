unit fpdev.cmd.lazarus.uninstall;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.lazarus.manager,
  fpdev.lazarus.leafcommandflow;

type
  { TLazUninstallCommand }
  TLazUninstallCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TLazUninstallCommand.Name: string; begin Result := 'uninstall'; end;
function TLazUninstallCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazUninstallCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazUninstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TLazarusManager;
  LPlan: TLazarusVersionLeafPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareLazarusUninstallCommandPlanCore(
    AParams,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    Result := ExecuteLazarusUninstallCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.UninstallVersion
    );
  finally
    LMgr.Free;
  end;
end;

function LazUninstallFactory: ICommand;
begin
  Result := TLazUninstallCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','uninstall'], @LazUninstallFactory, []);

end.
