unit fpdev.cmd.lazarus.current;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.lazarus.manager,
  fpdev.lazarus.leafcommandflow;

type
  { TLazCurrentCommand }
  TLazCurrentCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TLazCurrentCommand.Name: string; begin Result := 'current'; end;
function TLazCurrentCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazCurrentCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazCurrentCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TLazarusManager;
  LPlan: TLazarusCurrentCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareLazarusCurrentCommandPlanCore(
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
    Result := ExecuteLazarusCurrentCommandPlanCore(
      LPlan,
      Ctx.Out,
      @LMgr.GetCurrentVersion
    );
  finally
    LMgr.Free;
  end;
end;

function LazCurrentFactory: ICommand;
begin
  Result := TLazCurrentCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','current'], @LazCurrentFactory, []);

end.
