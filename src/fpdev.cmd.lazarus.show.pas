unit fpdev.cmd.lazarus.show;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.lazarus.manager,
  fpdev.lazarus.leafcommandflow;

type
  { TLazShowCommand }
  TLazShowCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.version.registry;

function TLazShowCommand.Name: string; begin Result := 'show'; end;
function TLazShowCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazShowCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazShowCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TLazarusManager;
  LPlan: TLazarusVersionLeafPlan;
  LShouldExit: Boolean;
  LRegistry: TVersionRegistry;
begin
  Result := PrepareLazarusShowCommandPlanCore(
    AParams,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  LMgr := TLazarusManager.Create(Ctx.Config);
  LRegistry := TVersionRegistry.Instance;
  try
    Result := ExecuteLazarusShowCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LRegistry.IsLazarusVersionValid,
      @LMgr.ShowVersionInfo
    );
  finally
    LMgr.Free;
  end;
end;

function LazShowFactory: ICommand;
begin
  Result := TLazShowCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','show'], @LazShowFactory, []);

end.
