unit fpdev.toolchain;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TStringDynArray = array of string;

  TToolStatus = record
    Name: string;
    Found: boolean;
    Version: string;
    Path: string;
    Notes: string;
  end;

  TToolStatusArray = array of TToolStatus;

  TToolchainReport = record
    HostOS: string;
    HostCPU: string;
    PathHead: TStringDynArray;
    Tools: TToolStatusArray;
    Issues: TStringDynArray;
    Level: string; // OK|WARN|FAIL
  end;

// Build a minimal health check report (HostReady scenario):
// fpc/make/lazbuild/lazarus_root/git/openssl
function BuildToolchainReportJSON: string;
// Get the current FPC version (fpc -iV); returns True on success and fills the version string
function GetFPCVersion(out AFPCVersion: string): boolean;
// Check whether the FPC version satisfies the policy for the given source version (e.g. main, 3.2.x)
// Return value: True means >= min (can proceed); AStatus = OK | WARN | FAIL;
//  - OK  : >= rec
//  - WARN: >= min and < rec
//  - FAIL: < min or FPC missing
function CheckFPCVersionPolicy(const ASourceVersion: string;
  out AStatus, AReason, AMin, ARec, AFPCVersion: string): boolean;

implementation

uses
  fpdev.toolchain.policyflow, fpdev.toolchain.reportflow;

function GetFPCVersion(out AFPCVersion: string): boolean;
begin
  Result := GetToolchainFPCVersionCore(
    @RunToolchainFirstLineCore,
    AFPCVersion
  );
end;

function CheckFPCVersionPolicy(const ASourceVersion: string;
  out AStatus, AReason, AMin, ARec, AFPCVersion: string): boolean;
begin
  if not GetFPCVersion(AFPCVersion) then
  begin
    AStatus := 'FAIL';
    AReason := 'fpc not found';
    Exit(False);
  end;
  Result := EvaluateToolchainFPCVersionPolicyCore(
    ASourceVersion,
    AFPCVersion,
    AStatus,
    AReason,
    AMin,
    ARec
  );
end;

function BuildToolchainReportJSON: string;
begin
  Result := BuildDefaultToolchainReportJSONCore;
end;

end.
