unit fpdev.fpc.manager.adaptrflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.git.runtime, fpdev.fpc.runtimeflow;

type
  { TFPCGitRuntimeAdapter - Bridges IGitRuntime to IFPCGitRuntime }
  TFPCGitRuntimeAdapter = class(TInterfacedObject, IFPCGitRuntime)
  private
    FGit: IGitRuntime;
  public
    constructor Create(const AGit: IGitRuntime = nil);
    function BackendAvailable: Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const APath: string): Boolean;
    function Pull(const APath: string): Boolean;
    function GetLastError: string;
  end;

implementation

{ TFPCGitRuntimeAdapter }

constructor TFPCGitRuntimeAdapter.Create(const AGit: IGitRuntime);
begin
  inherited Create;
  if AGit <> nil then
    FGit := AGit
  else
    FGit := NewGitRuntime;
end;

function TFPCGitRuntimeAdapter.BackendAvailable: Boolean;
begin
  Result := (FGit <> nil) and FGit.BackendAvailable;
end;

function TFPCGitRuntimeAdapter.IsRepository(const APath: string): Boolean;
begin
  Result := FGit.IsRepository(APath);
end;

function TFPCGitRuntimeAdapter.HasRemote(const APath: string): Boolean;
begin
  Result := FGit.HasRemote(APath);
end;

function TFPCGitRuntimeAdapter.Pull(const APath: string): Boolean;
begin
  Result := FGit.PullFastForwardOnly(APath);
end;

function TFPCGitRuntimeAdapter.GetLastError: string;
begin
  Result := FGit.LastError;
end;

end.
