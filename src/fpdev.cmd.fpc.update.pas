unit fpdev.cmd.fpc.update;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config, fpdev.cmd.fpc;

type
  { TFPCUpdateCommand }
  TFPCUpdateCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

uses fpdev.utils;

function TFPCUpdateCommand.Name: string; begin Result := 'update'; end;
function TFPCUpdateCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TFPCUpdateCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

procedure TFPCUpdateCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  LMgr: TFPCManager;
begin
  LMgr := TFPCManager.Create(Ctx.Config);
  try
    FPC_UpdateIndex;
  finally
    LMgr.Free;
  end;
end;

function FPCUpdateFactory: IFpdevCommand;
begin
  Result := TFPCUpdateCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','update'], @FPCUpdateFactory, []);

end.

