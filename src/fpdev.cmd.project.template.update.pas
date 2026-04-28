unit fpdev.cmd.project.template.update;

{$mode objfpc}{$H+}

{ B246: CLI command for updating project templates from remote repository }

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.project.manager,
  fpdev.output.intf, fpdev.project.templatecommandflow;

type
  TProjectTemplateUpdateCommand = class(TInterfacedObject, ICommand)
  private
    FManager: TProjectManager;
    function RunUpdateTemplates(const Outp, Errp: IOutput): Boolean;
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TProjectTemplateUpdateCommand.Name: string; begin Result := 'update'; end;
function TProjectTemplateUpdateCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectTemplateUpdateCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function ProjectTemplateUpdateFactory: ICommand;
begin
  Result := TProjectTemplateUpdateCommand.Create;
end;

function TProjectTemplateUpdateCommand.RunUpdateTemplates(
  const Outp, Errp: IOutput
): Boolean;
begin
  Result := Assigned(FManager) and FManager.UpdateTemplates(Outp, Errp);
end;

function TProjectTemplateUpdateCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LPlan: TProjectTemplateUpdateCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareProjectTemplateUpdateCommandPlanCore(
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
    Result := ExecuteProjectTemplateUpdateCommandPlanCore(
      Ctx.Out,
      Ctx.Err,
      @RunUpdateTemplates
    );
  finally
    FManager.Free;
    FManager := nil;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','template','update'], @ProjectTemplateUpdateFactory, []);

end.
