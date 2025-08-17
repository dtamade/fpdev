unit fpdev.cmd.fpc.current;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config, fpdev.cmd.fpc;

type
  { TFPCCurrentCommand }
  TFPCCurrentCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

uses fpdev.utils;

function TFPCCurrentCommand.Name: string; begin Result := 'current'; end;
function TFPCCurrentCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TFPCCurrentCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

procedure TFPCCurrentCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  LVer: string;
  LMgr: TFPCManager;
begin
  LMgr := TFPCManager.Create(Ctx.Config);
  try
    LVer := LMgr.GetCurrentVersion;
    if LVer <> '' then
      WriteLn('当前FPC版本: ', LVer)
    else
      WriteLn('未设置默认FPC版本');
  finally
    LMgr.Free;
  end;
end;

function FPCCurrentFactory: IFpdevCommand;
begin
  Result := TFPCCurrentCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','current'], @FPCCurrentFactory, []);

end.

