unit fpdev.cmd.lazarus.update;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.lazarus.manager,
  fpdev.lazarus.leafcommandflow;

type
  { TLazUpdateCommand }
  TLazUpdateCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TLazUpdateCommand.Name: string; begin Result := 'update'; end;
function TLazUpdateCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazUpdateCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazUpdateCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TLazarusManager;
  LPlan: TLazarusUpdateCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareLazarusUpdateCommandPlanCore(
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
    Result := ExecuteLazarusUpdateCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.UpdateSources
    );
  finally
    LMgr.Free;
  end;
end;

function LazUpdateFactory: ICommand;
begin
  Result := TLazUpdateCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','update'], @LazUpdateFactory, []);

end.
