unit fpdev.cmd.lazarus.run;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config, fpdev.cmd.lazarus;

type
  { TLazRunCommand }
  TLazRunCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

function TLazRunCommand.Name: string; begin Result := 'run'; end;
function TLazRunCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TLazRunCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

procedure TLazRunCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  LVer: string;
  LMgr: TLazarusManager;
begin
  if Length(AParams) >= 1 then LVer := AParams[0] else LVer := '';
  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    LMgr.LaunchIDE(LVer);
  finally
    LMgr.Free;
  end;
end;

function LazRunFactory: IFpdevCommand;
begin
  Result := TLazRunCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','run'], @LazRunFactory, []);

end.

