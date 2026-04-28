unit fpdev.cmd.project.info;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.project.manager,
  fpdev.output.intf, fpdev.project.commandflow;

type
  TProjectInfoCommand = class(TInterfacedObject, ICommand)
  private
    FManager: TProjectManager;
    function RunShowTemplateInfo(
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

function TProjectInfoCommand.Name: string; begin Result := 'info'; end;
function TProjectInfoCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectInfoCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectInfoFactory: ICommand;
begin
  Result := TProjectInfoCommand.Create;
end;

function TProjectInfoCommand.RunShowTemplateInfo(
  const Outp, Errp: IOutput;
  const ATemplateName: string
): Boolean;
begin
  Result := Assigned(FManager) and FManager.ShowTemplateInfo(Outp, Errp, ATemplateName);
end;

function TProjectInfoCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LPlan: TProjectInfoCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareProjectInfoCommandPlanCore(
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
    Result := ExecuteProjectInfoCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @RunShowTemplateInfo
    );
  finally
    FManager.Free;
    FManager := nil;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','info'], @ProjectInfoFactory, []);

end.
