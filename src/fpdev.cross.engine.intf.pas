unit fpdev.cross.engine.intf;

{
  ICrossBuildEngine - Cross-compilation build engine interface

  Orchestrates the FPC cross-compiler build process:
    1. compiler_cycle  (build cross-compiler using native compiler)
    2. compiler_install
    3. rtl_all          (build RTL using new cross-compiler)
    4. rtl_install
    5. packages_all     (build packages using cross-compiler)
    6. packages_install
    7. verify
}

{$mode objfpc}{$H+}

interface

uses
  fpdev.config.interfaces;

type
  { TCrossBuildStage - Cross-compilation build stages }
  TCrossBuildStage = (
    cbsIdle,
    cbsPreflight,
    cbsCompilerCycle,
    cbsCompilerInstall,
    cbsRTLBuild,
    cbsRTLInstall,
    cbsPackagesBuild,
    cbsPackagesInstall,
    cbsVerify,
    cbsComplete,
    cbsFailed
  );

  { ICrossBuildEngine - Cross-compilation build engine }
  ICrossBuildEngine = interface
    ['{1A2B3C4D-E5F6-7890-ABCD-EF1234567890}']
    // Full build orchestration
    function BuildCrossCompiler(const ATarget: TCrossTarget;
      const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;

    // Step-by-step control
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

    // Status
    function GetCurrentStage: TCrossBuildStage;
    function GetLastError: string;
  end;

function CrossBuildStageToString(AStage: TCrossBuildStage): string;

implementation

function CrossBuildStageToString(AStage: TCrossBuildStage): string;
begin
  case AStage of
    cbsIdle:             Result := 'idle';
    cbsPreflight:        Result := 'preflight';
    cbsCompilerCycle:    Result := 'compiler_cycle';
    cbsCompilerInstall:  Result := 'compiler_install';
    cbsRTLBuild:         Result := 'rtl_build';
    cbsRTLInstall:       Result := 'rtl_install';
    cbsPackagesBuild:    Result := 'packages_build';
    cbsPackagesInstall:  Result := 'packages_install';
    cbsVerify:           Result := 'verify';
    cbsComplete:         Result := 'complete';
    cbsFailed:           Result := 'failed';
  end;
end;

end.
