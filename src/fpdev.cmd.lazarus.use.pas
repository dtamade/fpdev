unit fpdev.cmd.lazarus.use;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.lazarus.manager,
  fpdev.lazarus.leafcommandflow;

type
  { TLazUseCommand }
  TLazUseCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TLazUseCommand.Name: string; begin Result := 'use'; end;
function TLazUseCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazUseCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazUseCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TLazarusManager;
  LPlan: TLazarusVersionLeafPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareLazarusUseCommandPlanCore(
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
    Result := ExecuteLazarusUseCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.SetDefaultVersion
    );
  finally
    LMgr.Free;
  end;
end;

function LazUseFactory: ICommand;
begin
  Result := TLazUseCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','use'], @LazUseFactory, []);

end.
