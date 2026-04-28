unit fpdev.cmd.project.clean;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.project.manager,
  fpdev.output.intf, fpdev.project.commandflow;

type
  TProjectCleanCommand = class(TInterfacedObject, ICommand)
  private
    FManager: TProjectManager;
    function RunCleanProject(
      const Outp, Errp: IOutput;
      const AProjectDir: string
    ): Boolean;
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TProjectCleanCommand.Name: string; begin Result := 'clean'; end;
function TProjectCleanCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectCleanCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectCleanFactory: ICommand;
begin
  Result := TProjectCleanCommand.Create;
end;

function TProjectCleanCommand.RunCleanProject(
  const Outp, Errp: IOutput;
  const AProjectDir: string
): Boolean;
begin
  Result := Assigned(FManager) and FManager.CleanProject(Outp, Errp, AProjectDir);
end;

function TProjectCleanCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LPlan: TProjectDirectoryCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareProjectCleanCommandPlanCore(
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
    Result := ExecuteProjectCleanCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @RunCleanProject
    );
  finally
    FManager.Free;
    FManager := nil;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','clean'], @ProjectCleanFactory, []);

end.
