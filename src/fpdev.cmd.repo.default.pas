unit fpdev.cmd.repo.default;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config.interfaces,
  fpdev.i18n, fpdev.i18n.strings;

type
  TRepoDefaultCommand = class(TInterfacedObject, ICommand, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer; overload;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext); overload;
  end;

implementation

uses fpdev.cmd.utils;

function TRepoDefaultCommand.Name: string; begin Result := 'default'; end;
function TRepoDefaultCommand.Aliases: TStringArray; begin Result := nil; end;
function TRepoDefaultCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TRepoDefaultCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  RepoName: string;
  S: TFPDevSettings;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_DEFAULT_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_DEFAULT_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_DEFAULT_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_(HELP_REPO_DEFAULT_USAGE));
    Exit(2);
  end;
  RepoName := AParams[0];
  if Ctx.Config.GetRepositoryManager.GetRepository(RepoName) = '' then
  begin
    Ctx.Err.WriteLn(_Fmt(CMD_REPO_NOT_FOUND, [RepoName]));
    Exit(2);
  end;
  S := Ctx.Config.GetSettingsManager.GetSettings;
  S.DefaultRepo := RepoName;
  if Ctx.Config.GetSettingsManager.SetSettings(S) then
    Exit(0);
  Ctx.Err.WriteLn(_Fmt(CMD_REPO_DEFAULT_FAILED, [RepoName]));
  Result := 3;
end;

procedure TRepoDefaultCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  RepoName: string;
  Settings: TFPDevSettings;
begin
  if Length(AParams) < 1 then
    Exit;

  RepoName := AParams[0];

  if Ctx.Config.GetRepository(RepoName) = '' then
    Exit;

  Settings := Ctx.Config.GetSettings;
  Settings.DefaultRepo := RepoName;
  Ctx.Config.SetSettings(Settings);
  Ctx.SaveIfModified;
end;

function RepoDefaultFactory: ICommand;
begin
  Result := TRepoDefaultCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['repo','default'], @RepoDefaultFactory, []);

end.




