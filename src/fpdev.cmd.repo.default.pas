unit fpdev.cmd.repo.default;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config;

type
  TRepoDefaultCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

function TRepoDefaultCommand.Name: string; begin Result := 'default'; end;
function TRepoDefaultCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TRepoDefaultCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

procedure TRepoDefaultCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  Name: string;
  S: TFPDevSettings;
begin
  if Length(AParams) < 1 then Exit;
  Name := AParams[0];
  if Ctx.Config.GetRepository(Name) = '' then Exit;
  S := Ctx.Config.GetSettings;
  S.DefaultRepo := Name;
  if Ctx.Config.SetSettings(S) then
    Ctx.SaveIfModified;
end;

function RepoDefaultFactory: IFpdevCommand;
begin
  Result := TRepoDefaultCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['repo','default'], @RepoDefaultFactory, []);

end.




