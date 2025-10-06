unit fpdev.cmd.repo.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config;

type
  TRepoListCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

function TRepoListCommand.Name: string; begin Result := 'list'; end;
function TRepoListCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TRepoListCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

procedure TRepoListCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  Names: TStringArray;
  i: Integer;
begin
  Names := Ctx.Config.ListRepositories;
  for i := 0 to High(Names) do
    WriteLn(Names[i], ' = ', Ctx.Config.GetRepository(Names[i]));
end;

function RepoListFactory: IFpdevCommand;
begin
  Result := TRepoListCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['repo','list'], @RepoListFactory, ['ls']);

end.




