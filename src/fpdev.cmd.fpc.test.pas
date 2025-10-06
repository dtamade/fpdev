unit fpdev.cmd.fpc.test;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config, fpdev.cmd.fpc;

type
  { TFPCCTestCommand }
  TFPCCTestCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

uses fpdev.utils;

function TFPCCTestCommand.Name: string; begin Result := 'test'; end;
function TFPCCTestCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TFPCCTestCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

procedure TFPCCTestCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  LVer: string;
  LMgr: TFPCManager;
begin
  if Length(AParams) < 1 then
  begin
  // WriteLn('错误: 需要指定版本号，例如: fpdev fpc test 3.2.2');  // 调试代码已注释
    Exit;
  end;
  LVer := AParams[0];
  LMgr := TFPCManager.Create(Ctx.Config);
  try
    LMgr.TestInstallation(LVer);
  finally
    LMgr.Free;
  end;
end;

function FPCTestFactory: IFpdevCommand;
begin
  Result := TFPCCTestCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','test'], @FPCTestFactory, []);

end.

