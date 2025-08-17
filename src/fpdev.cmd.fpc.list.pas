unit fpdev.cmd.fpc.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  fpdev.utils, fpdev.command.intf, fpdev.config, fpdev.cmd.fpc;

type
  { TFPCListCommand }
  TFPCListCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

uses fpdev.command.registry;

function HasFlag(const Params: array of string; const Flag: string): Boolean;
var i: Integer;
begin
  Result := False;
  for i := Low(Params) to High(Params) do
    if SameText(Params[i], '--' + Flag) or SameText(Params[i], '-' + Flag) then
      Exit(True);
end;

function TFPCListCommand.Name: string; begin Result := 'list'; end;
function TFPCListCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TFPCListCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

function FPCListFactory: IFpdevCommand;
begin
  Result := TFPCListCommand.Create;
end;


procedure TFPCListCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  LShowAll: Boolean;
  LMgr: TFPCManager;
begin
  LShowAll := HasFlag(AParams, 'all') or HasFlag(AParams, 'remote');
  LMgr := TFPCManager.Create(Ctx.Config);
  try
    LMgr.ListVersions(LShowAll);
  finally
    LMgr.Free;
  end;
end;


initialization
  GlobalCommandRegistry.RegisterPath(['fpc','list'], @FPCListFactory, []);

end.

