unit fpdev.cmd.lazarus.test;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.lazarus.manager,
  fpdev.lazarus.leafcommandflow;

type
  { TLazTestCommand }
  TLazTestCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TLazTestCommand.Name: string; begin Result := 'test'; end;
function TLazTestCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazTestCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazTestCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TLazarusManager;
  LPlan: TLazarusVersionLeafPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareLazarusTestCommandPlanCore(
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
    Result := ExecuteLazarusTestCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.TestInstallation
    );
  finally
    LMgr.Free;
  end;
end;

function LazTestFactory: ICommand;
begin
  Result := TLazTestCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','test'], @LazTestFactory, []);

end.
