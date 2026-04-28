unit fpdev.cmd.project.test;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.project.manager,
  fpdev.output.intf, fpdev.project.commandflow;

type
  TProjectTestCommand = class(TInterfacedObject, ICommand)
  private
    FManager: TProjectManager;
    function RunTestProject(
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

function TProjectTestCommand.Name: string; begin Result := 'test'; end;
function TProjectTestCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectTestCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectTestFactory: ICommand;
begin
  Result := TProjectTestCommand.Create;
end;

function TProjectTestCommand.RunTestProject(
  const Outp, Errp: IOutput;
  const AProjectDir: string
): Boolean;
begin
  Result := Assigned(FManager) and FManager.TestProject(Outp, Errp, AProjectDir);
end;

function TProjectTestCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LPlan: TProjectDirectoryCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareProjectTestCommandPlanCore(
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
    Result := ExecuteProjectTestCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @RunTestProject
    );
  finally
    FManager.Free;
    FManager := nil;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','test'], @ProjectTestFactory, []);

end.
