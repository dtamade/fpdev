unit fpdev.cmd.lazarus.configure;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.lazarus.manager,
  fpdev.lazarus.leafcommandflow;

type
  { TLazConfigureCommand }
  TLazConfigureCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TLazConfigureCommand.Name: string; begin Result := 'configure'; end;
function TLazConfigureCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazConfigureCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazConfigureCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TLazarusManager;
  LPlan: TLazarusVersionLeafPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareLazarusConfigureCommandPlanCore(
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
    Result := ExecuteLazarusConfigureCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.ConfigureIDE
    );
  finally
    LMgr.Free;
  end;
end;

function LazConfigureFactory: ICommand;
begin
  Result := TLazConfigureCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','configure'], @LazConfigureFactory, []);

end.
