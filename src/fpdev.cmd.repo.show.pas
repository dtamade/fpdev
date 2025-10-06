unit fpdev.cmd.repo.show;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config;

type
  TRepoShowCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

function TRepoShowCommand.Name: string; begin Result := 'show'; end;
function TRepoShowCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TRepoShowCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

procedure TRepoShowCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  Name, URL: string;
begin
  if Length(AParams) < 1 then Exit;
  Name := AParams[0];
  URL := Ctx.Config.GetRepository(Name);
  if URL<>'' then
  begin
    WriteLn(Name, ' = ', URL);
    if SameText(Ctx.Config.GetSettings.DefaultRepo, Name) then
      WriteLn('(default)');
  end;
end;

function RepoShowFactory: IFpdevCommand;
begin
  Result := TRepoShowCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['repo','show'], @RepoShowFactory, []);

end.


