unit fpdev.cmd.project.template.install;

{$mode objfpc}{$H+}

{ B244: CLI command for installing a custom project template }

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.project.manager,
  fpdev.output.intf, fpdev.project.templatecommandflow;

type
  TProjectTemplateInstallCommand = class(TInterfacedObject, ICommand)
  private
    FManager: TProjectManager;
    function RunInstallTemplate(
      const Outp, Errp: IOutput;
      const ATemplatePath: string
    ): Boolean;
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TProjectTemplateInstallCommand.Name: string; begin Result := 'install'; end;
function TProjectTemplateInstallCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectTemplateInstallCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function ProjectTemplateInstallFactory: ICommand;
begin
  Result := TProjectTemplateInstallCommand.Create;
end;

function TProjectTemplateInstallCommand.RunInstallTemplate(
  const Outp, Errp: IOutput;
  const ATemplatePath: string
): Boolean;
begin
  Result := Assigned(FManager) and FManager.InstallTemplate(Outp, Errp, ATemplatePath);
end;

function TProjectTemplateInstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LPlan: TProjectTemplateInstallCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareProjectTemplateInstallCommandPlanCore(
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
    Result := ExecuteProjectTemplateInstallCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @RunInstallTemplate
    );
  finally
    FManager.Free;
    FManager := nil;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','template','install'], @ProjectTemplateInstallFactory, []);

end.
