unit fpdev.cross.engine;

{
  TCrossBuildEngine - Cross-compilation build engine facade

  Delegates pipeline orchestration to TCrossBuildPipeline.
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.cross.engine.intf,
  fpdev.cross.opts,
  fpdev.cross.compiler,
  fpdev.build.manager,
  fpdev.cross.engine.pipelineflow;

type
  { TCrossBuildEngine - Implements ICrossBuildEngine using TBuildManager }
  TCrossBuildEngine = class(TInterfacedObject, ICrossBuildEngine)
  private
    FBuildManager: TBuildManager;
    FOwnsManager: Boolean;
    FPipeline: TCrossBuildPipeline;

  public
    constructor Create(ABuildManager: TBuildManager; AOwnsManager: Boolean = False);
    destructor Destroy; override;

    // ICrossBuildEngine implementation
    function BuildCrossCompiler(const ATarget: TCrossTarget;
      const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;

    function Preflight(const ATarget: TCrossTarget;
      const ASourceRoot, ASandboxRoot: string): Boolean;
    function CompilerCycle(const ATarget: TCrossTarget;
      const ASourceRoot, AVersion: string): Boolean;
    function InstallCompiler(const ATarget: TCrossTarget;
      const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
    function BuildRTL(const ATarget: TCrossTarget;
      const ASourceRoot, AVersion: string): Boolean;
    function InstallRTL(const ATarget: TCrossTarget;
      const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
    function BuildPackages(const ATarget: TCrossTarget;
      const ASourceRoot, AVersion: string): Boolean;
    function InstallPackages(const ATarget: TCrossTarget;
      const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
    function Verify(const ATarget: TCrossTarget;
      const ASandboxRoot, AVersion: string): Boolean;

    function GetCurrentStage: TCrossBuildStage;
    function GetLastError: string;

    // Extended API
    procedure SetDryRun(AEnable: Boolean);
    function GetCommandLog: TStringArray;
    function GetCommandLogCount: Integer;
  end;

implementation

{ TCrossBuildEngine }

constructor TCrossBuildEngine.Create(ABuildManager: TBuildManager; AOwnsManager: Boolean);
begin
  inherited Create;
  FBuildManager := ABuildManager;
  FOwnsManager := AOwnsManager;
  FPipeline := TCrossBuildPipeline.Create(ABuildManager);
end;

destructor TCrossBuildEngine.Destroy;
begin
  FPipeline.Free;
  if FOwnsManager and Assigned(FBuildManager) then
    FBuildManager.Free;
  inherited Destroy;
end;

function TCrossBuildEngine.Preflight(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot: string): Boolean;
begin
  Result := FPipeline.Preflight(ATarget, ASourceRoot, ASandboxRoot);
end;

function TCrossBuildEngine.CompilerCycle(const ATarget: TCrossTarget;
  const ASourceRoot, AVersion: string): Boolean;
begin
  Result := FPipeline.CompilerCycle(ATarget, ASourceRoot, AVersion);
end;

function TCrossBuildEngine.InstallCompiler(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
begin
  Result := FPipeline.InstallCompiler(ATarget, ASourceRoot, ASandboxRoot, AVersion);
end;

function TCrossBuildEngine.BuildRTL(const ATarget: TCrossTarget;
  const ASourceRoot, AVersion: string): Boolean;
begin
  Result := FPipeline.BuildRTL(ATarget, ASourceRoot, AVersion);
end;

function TCrossBuildEngine.InstallRTL(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
begin
  Result := FPipeline.InstallRTL(ATarget, ASourceRoot, ASandboxRoot, AVersion);
end;

function TCrossBuildEngine.BuildPackages(const ATarget: TCrossTarget;
  const ASourceRoot, AVersion: string): Boolean;
begin
  Result := FPipeline.BuildPackages(ATarget, ASourceRoot, AVersion);
end;

function TCrossBuildEngine.InstallPackages(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
begin
  Result := FPipeline.InstallPackages(ATarget, ASourceRoot, ASandboxRoot, AVersion);
end;

function TCrossBuildEngine.Verify(const ATarget: TCrossTarget;
  const ASandboxRoot, AVersion: string): Boolean;
begin
  Result := FPipeline.Verify(ATarget, ASandboxRoot, AVersion);
end;

function TCrossBuildEngine.BuildCrossCompiler(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
begin
  Result := FPipeline.BuildCrossCompiler(ATarget, ASourceRoot, ASandboxRoot, AVersion);
end;

function TCrossBuildEngine.GetCurrentStage: TCrossBuildStage;
begin
  Result := FPipeline.CurrentStage;
end;

function TCrossBuildEngine.GetLastError: string;
begin
  Result := FPipeline.LastError;
end;

procedure TCrossBuildEngine.SetDryRun(AEnable: Boolean);
begin
  FPipeline.SetDryRun(AEnable);
end;

function TCrossBuildEngine.GetCommandLog: TStringArray;
begin
  Result := FPipeline.GetCommandLog;
end;

function TCrossBuildEngine.GetCommandLogCount: Integer;
begin
  Result := FPipeline.GetCommandLogCount;
end;

end.
