unit fpdev.cmd.project.template.list;

{$mode objfpc}{$H+}

{ B243: CLI command for listing available project templates }

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.project.manager,
  fpdev.output.intf, fpdev.project.templatecommandflow;

type
  TProjectTemplateListCommand = class(TInterfacedObject, ICommand)
  private
    FManager: TProjectManager;
    function RunListTemplates(const Outp: IOutput): Boolean;
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TProjectTemplateListCommand.Name: string; begin Result := 'list'; end;
function TProjectTemplateListCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectTemplateListCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function ProjectTemplateListFactory: ICommand;
begin
  Result := TProjectTemplateListCommand.Create;
end;

function TProjectTemplateListCommand.RunListTemplates(const Outp: IOutput): Boolean;
begin
  Result := Assigned(FManager) and FManager.ListTemplates(Outp);
end;

function TProjectTemplateListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LPlan: TProjectTemplateListCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareProjectTemplateListCommandPlanCore(
    AParams,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  FManager := TProjectManager.Create(Ctx.Config);
  try
    Result := ExecuteProjectTemplateListCommandPlanCore(
      Ctx.Out,
      Ctx.Err,
      @RunListTemplates
    );
  finally
    FManager.Free;
    FManager := nil;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','template','list'], @ProjectTemplateListFactory, []);

end.
