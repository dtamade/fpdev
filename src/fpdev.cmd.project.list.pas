unit fpdev.cmd.project.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.project.manager,
  fpdev.output.intf, fpdev.project.commandflow;

type
  TProjectListCommand = class(TInterfacedObject, ICommand)
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

function TProjectListCommand.Name: string; begin Result := 'list'; end;
function TProjectListCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectListCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectListFactory: ICommand;
begin
  Result := TProjectListCommand.Create;
end;

function TProjectListCommand.RunListTemplates(const Outp: IOutput): Boolean;
begin
  Result := Assigned(FManager) and FManager.ListTemplates(Outp);
end;

function TProjectListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LPlan: TProjectListCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareProjectListCommandPlanCore(
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
    Result := ExecuteProjectListCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @RunListTemplates,
      @FManager.GetTemplateList
    );
  finally
    FManager.Free;
    FManager := nil;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','list'], @ProjectListFactory, []);

end.
