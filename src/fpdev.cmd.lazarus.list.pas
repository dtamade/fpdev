unit fpdev.cmd.lazarus.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config, fpdev.cmd.lazarus;

type
  { TLazListCommand }
  TLazListCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

function TLazListCommand.Name: string; begin Result := 'list'; end;
function TLazListCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TLazListCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

procedure TLazListCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  LAll: Boolean;
  LMgr: TLazarusManager;
begin
  LAll := (Length(AParams)>0) and ((AParams[0]='--all') or (AParams[0]='-all'));
  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    LMgr.ListVersions(LAll);
  finally
    LMgr.Free;
  end;
end;

function LazListFactory: IFpdevCommand;
begin
  Result := TLazListCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','list'], @LazListFactory, []);

end.

