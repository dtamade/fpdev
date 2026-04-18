unit fpdev.cmd.cross.build;

{$mode objfpc}{$H+}

{
  fpdev cross build <target> [--dry-run] [--source=<path>] [--sandbox=<path>]

  Builds a cross-compiler for the specified target using the 7-step
  build process (compiler_cycle -> rtl -> packages -> verify).
}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry;

type
  TCrossBuildCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.config.interfaces,
  fpdev.cross.buildcommandflow,
  fpdev.cross.engine,
  fpdev.cross.engine.intf,
  fpdev.build.manager;

type
  TCrossBuildEngineBridge = class
  private
    FEngine: TCrossBuildEngine;
  public
    constructor Create(AEngine: TCrossBuildEngine);
    procedure SetDryRun(const AValue: Boolean);
    function BuildCrossCompiler(
      const ACPU, AOS, ASourceRoot, ASandboxRoot, AVersion: string
    ): Boolean;
    function GetLastError: string;
    function GetCurrentStage: string;
  end;

function TCrossBuildCommand.Name: string;
begin
  Result := 'build';
end;

function TCrossBuildCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TCrossBuildCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function CrossBuildFactory: ICommand;
begin
  Result := TCrossBuildCommand.Create;
end;

constructor TCrossBuildEngineBridge.Create(AEngine: TCrossBuildEngine);
begin
  inherited Create;
  FEngine := AEngine;
end;

procedure TCrossBuildEngineBridge.SetDryRun(const AValue: Boolean);
begin
  if FEngine <> nil then
    FEngine.SetDryRun(AValue);
end;

function TCrossBuildEngineBridge.BuildCrossCompiler(
  const ACPU, AOS, ASourceRoot, ASandboxRoot, AVersion: string
): Boolean;
var
  Target: TCrossTarget;
begin
  if FEngine = nil then
    Exit(False);

  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := ACPU;
  Target.OS := AOS;
  Result := FEngine.BuildCrossCompiler(Target, ASourceRoot, ASandboxRoot, AVersion);
end;

function TCrossBuildEngineBridge.GetLastError: string;
begin
  if FEngine <> nil then
    Result := FEngine.GetLastError
  else
    Result := '';
end;

function TCrossBuildEngineBridge.GetCurrentStage: string;
begin
  if FEngine <> nil then
    Result := CrossBuildStageToString(FEngine.GetCurrentStage)
  else
    Result := '';
end;

function TCrossBuildCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LPlan: TCrossBuildCommandPlan;
  LShouldExit: Boolean;
  LBuildManager: TBuildManager;
  LEngine: TCrossBuildEngine;
  LBridge: TCrossBuildEngineBridge;
begin
  Result := PrepareCrossBuildCommandPlanCore(
    AParams,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  LBuildManager := TBuildManager.Create(LPlan.SourceRoot, 4, True);
  LEngine := TCrossBuildEngine.Create(LBuildManager, True);
  LBridge := TCrossBuildEngineBridge.Create(LEngine);
  try
    Result := ExecuteCrossBuildCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LBridge.SetDryRun,
      @LBridge.BuildCrossCompiler,
      @LBridge.GetLastError,
      @LBridge.GetCurrentStage
    );
  finally
    LBridge.Free;
    LEngine.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross', 'build'], @CrossBuildFactory, []);

end.
