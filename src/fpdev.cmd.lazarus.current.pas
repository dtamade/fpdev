unit fpdev.cmd.lazarus.current;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config, fpdev.cmd.lazarus;

type
  { TLazCurrentCommand }
  TLazCurrentCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

function TLazCurrentCommand.Name: string; begin Result := 'current'; end;
function TLazCurrentCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TLazCurrentCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

procedure TLazCurrentCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  LVer: string;
  LMgr: TLazarusManager;
begin
  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    LVer := LMgr.GetCurrentVersion;
    if LVer <> '' then
    begin
      // WriteLn('当前Lazarus版本: ', LVer)  // 调试代码已注释
    end
    else
    begin
      // WriteLn('未设置默认Lazarus版本');  // 调试代码已注释
    end;
  finally
    LMgr.Free;
  end;
end;

function LazCurrentFactory: IFpdevCommand;
begin
  Result := TLazCurrentCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','current'], @LazCurrentFactory, []);

end.

