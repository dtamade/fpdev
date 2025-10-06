unit fpdev.cmd.fpc.show;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config, fpdev.cmd.fpc;

type
  { TFPCShowCommand }
  TFPCShowCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

uses fpdev.utils;

function TFPCShowCommand.Name: string; begin Result := 'show'; end;
function TFPCShowCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TFPCShowCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

procedure TFPCShowCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  LVer: string;
  LMgr: TFPCManager;
begin
  if Length(AParams) < 1 then
  begin
  // WriteLn('错误: 需要指定版本号，例如: fpdev fpc show 3.2.2');  // 调试代码已注释
    Exit;
  end;
  LVer := AParams[0];
  LMgr := TFPCManager.Create(Ctx.Config);
  try
    LMgr.ShowVersionInfo(LVer);
  finally
    LMgr.Free;
  end;
end;

function FPCShowFactory: IFpdevCommand;
begin
  Result := TFPCShowCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','show'], @FPCShowFactory, []);

end.

