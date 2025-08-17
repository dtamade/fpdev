unit fpdev.cmd.lazarus.use;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config, fpdev.cmd.lazarus;

type
  { TLazUseCommand }
  TLazUseCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

function TLazUseCommand.Name: string; begin Result := 'use'; end;
function TLazUseCommand.Aliases: TStringArray; begin SetLength(Result,1); Result[0] := 'default'; end;
function TLazUseCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

procedure TLazUseCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  LVer: string;
  LMgr: TLazarusManager;
begin
  if Length(AParams) < 1 then
  begin
    WriteLn('错误: 需要指定版本号，例如: fpdev lazarus use 3.0');
    Exit;
  end;
  LVer := AParams[0];

  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    if LMgr.SetDefaultVersion(LVer) then
      if Ctx.Config.Modified then Ctx.Config.SaveConfig;
  finally
    LMgr.Free;
  end;
end;

function LazUseFactory: IFpdevCommand;
begin
  Result := TLazUseCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','use'], @LazUseFactory, ['default']);

end.

