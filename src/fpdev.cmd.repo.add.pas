unit fpdev.cmd.repo.add;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config;

type
  TRepoAddCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

function TRepoAddCommand.Name: string; begin Result := 'add'; end;
function TRepoAddCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TRepoAddCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

procedure TRepoAddCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  Name, URL: string;
begin
  if Length(AParams) < 2 then Exit;
  Name := AParams[0];
  URL := AParams[1];
  if (Trim(Name)='') or (Trim(URL)='') then Exit;
  if Ctx.Config.AddRepository(Name, URL) then
    Ctx.SaveIfModified;
end;

function RepoAddFactory: IFpdevCommand;
begin
  Result := TRepoAddCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['repo','add'], @RepoAddFactory, []);

end.




