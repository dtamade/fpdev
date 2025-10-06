unit fpdev.cmd.repo.remove;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config;

type
  TRepoRemoveCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

function TRepoRemoveCommand.Name: string; begin Result := 'remove'; end;
function TRepoRemoveCommand.Aliases: TStringArray; begin SetLength(Result,2); Result[0]:='rm'; Result[1]:='del'; end;
function TRepoRemoveCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

procedure TRepoRemoveCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  Name: string;
begin
  if Length(AParams) < 1 then Exit;
  Name := AParams[0];
  if (Trim(Name)='') then Exit;
  if Ctx.Config.RemoveRepository(Name) then
    Ctx.SaveIfModified;
end;

function RepoRemoveFactory: IFpdevCommand;
begin
  Result := TRepoRemoveCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['repo','remove'], @RepoRemoveFactory, ['rm','del']);

end.




