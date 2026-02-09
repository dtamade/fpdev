unit fpdev.cmd.project.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.project,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TProjectListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils, fpjson, fpdev.project.generator;

function TProjectListCommand.Name: string; begin Result := 'list'; end;
function TProjectListCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectListCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectListFactory: ICommand;
begin
  Result := TProjectListCommand.Create;
end;

function ProjectTypeToString(AType: TProjectType): string;
begin
  case AType of
    ptConsole: Result := 'console';
    ptGUI: Result := 'gui';
    ptLibrary: Result := 'library';
    ptPackage: Result := 'package';
    ptWebApp: Result := 'webapp';
    ptService: Result := 'service';
    ptGame: Result := 'game';
    ptCustom: Result := 'custom';
  end;
end;

function TemplateToJson(const ATemplate: TProjectTemplate): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('name', ATemplate.Name);
  Result.Add('display_name', ATemplate.DisplayName);
  Result.Add('description', ATemplate.Description);
  Result.Add('type', ProjectTypeToString(ATemplate.ProjectType));
  Result.Add('available', ATemplate.Available);
end;

function TProjectListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TProjectManager;
  LJsonOutput: Boolean;
  LTemplates: TProjectTemplateArray;
  LJson: TJSONObject;
  LArr: TJSONArray;
  I: Integer;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('  --json           Output in JSON format');
    Ctx.Out.WriteLn(_(HELP_PROJECT_LIST_OPT_HELP));
    Exit(EXIT_OK);
  end;

  LJsonOutput := HasFlag(AParams, 'json');

  LMgr := TProjectManager.Create(Ctx.Config);
  try
    if LJsonOutput then
    begin
      // JSON output mode
      LTemplates := LMgr.GetTemplateList;

      LJson := TJSONObject.Create;
      try
        LArr := TJSONArray.Create;
        for I := 0 to High(LTemplates) do
          LArr.Add(TemplateToJson(LTemplates[I]));
        LJson.Add('templates', LArr);
        Ctx.Out.WriteLn(LJson.FormatJSON);
      finally
        LJson.Free;
      end;
      Exit(EXIT_OK);
    end
    else
    begin
      // Normal text output
      if LMgr.ListTemplates(Ctx.Out) then
        Exit(EXIT_OK);
      Result := EXIT_ERROR;
    end;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','list'], @ProjectListFactory, []);

end.
