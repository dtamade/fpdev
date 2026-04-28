unit fpdev.cmd.project.template.remove;

{$mode objfpc}{$H+}

{ B245: CLI command for removing a custom project template }

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.project.manager,
  fpdev.output.intf, fpdev.project.templatecommandflow;

type
  TProjectTemplateRemoveCommand = class(TInterfacedObject, ICommand)
  private
    FManager: TProjectManager;
    function RunRemoveTemplate(
      const Outp, Errp: IOutput;
      const ATemplateName: string
    ): Boolean;
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TProjectTemplateRemoveCommand.Name: string; begin Result := 'remove'; end;
function TProjectTemplateRemoveCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectTemplateRemoveCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function ProjectTemplateRemoveFactory: ICommand;
begin
  Result := TProjectTemplateRemoveCommand.Create;
end;

function TProjectTemplateRemoveCommand.RunRemoveTemplate(
  const Outp, Errp: IOutput;
  const ATemplateName: string
): Boolean;
begin
  Result := Assigned(FManager) and FManager.RemoveTemplate(Outp, Errp, ATemplateName);
end;

function TProjectTemplateRemoveCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LPlan: TProjectTemplateRemoveCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareProjectTemplateRemoveCommandPlanCore(
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
    Result := ExecuteProjectTemplateRemoveCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @RunRemoveTemplate
    );
  finally
    FManager.Free;
    FManager := nil;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','template','remove'], @ProjectTemplateRemoveFactory, []);

end.
