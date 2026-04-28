unit fpdev.git.runtime.impl;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.git.types,
  fpdev.git.runtime;

function NewGitRuntimeImpl(const ACliOnly: Boolean = False): IGitRuntime;

implementation

uses
  fpdev.git.operations;

type
  TGitRuntime = class(TInterfacedObject, IGitRuntime)
  private
    FGit: TGitOperations;
  public
    constructor Create(const ACliOnly: Boolean = False);
    destructor Destroy; override;

    function GetBackend: TGitBackend;
    function BackendAvailable: Boolean;
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Fetch(const ARepoPath: string; const ARemote: string = 'origin'): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean = False): Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const ARepoPath: string): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function PullWithMerge(const ARepoPath: string): Boolean;
    function PullFastForwardOnly(const ARepoPath: string): Boolean;
    function GetLastError: string;
    function GetRemoteURL(const ARepoPath: string; const ARemote: string = 'origin'): string;
    function GetCurrentBranch(const ARepoPath: string): string;
    function GetShortHeadHash(const ARepoPath: string; const ALength: Integer = 7): string;
    function ListBranches(const ARepoPath: string): TStringArray;
    function Add(const ARepoPath, APathSpec: string): Boolean;
    function Commit(const ARepoPath, AMessage: string): Boolean;
    function Push(const ARepoPath: string; const ARemote: string = 'origin'; const ABranch: string = ''): Boolean;
    function GetVersion: string;
  end;

function NewGitRuntimeImpl(const ACliOnly: Boolean): IGitRuntime;
begin
  Result := TGitRuntime.Create(ACliOnly);
end;

constructor TGitRuntime.Create(const ACliOnly: Boolean);
begin
  inherited Create;
  if ACliOnly then
    FGit := TGitOperations.Create(nil, True)
  else
    FGit := TGitOperations.Create;
end;

destructor TGitRuntime.Destroy;
begin
  FGit.Free;
  inherited Destroy;
end;

function TGitRuntime.GetBackend: TGitBackend;
begin
  Result := FGit.Backend;
end;

function TGitRuntime.BackendAvailable: Boolean;
begin
  Result := FGit.Backend <> gbNone;
end;

function TGitRuntime.Clone(const AURL, ALocalPath: string; const ABranch: string): Boolean;
begin
  Result := FGit.Clone(AURL, ALocalPath, ABranch);
end;

function TGitRuntime.Fetch(const ARepoPath: string; const ARemote: string): Boolean;
begin
  Result := FGit.Fetch(ARepoPath, ARemote);
end;

function TGitRuntime.Checkout(const ARepoPath, AName: string; const Force: Boolean): Boolean;
begin
  Result := FGit.Checkout(ARepoPath, AName, Force);
end;

function TGitRuntime.IsRepository(const APath: string): Boolean;
begin
  Result := FGit.IsRepository(APath);
end;

function TGitRuntime.HasRemote(const ARepoPath: string): Boolean;
begin
  Result := FGit.HasRemote(ARepoPath);
end;

function TGitRuntime.Pull(const ARepoPath: string): Boolean;
begin
  Result := FGit.PullFastForwardOnly(ARepoPath);
end;

function TGitRuntime.PullWithMerge(const ARepoPath: string): Boolean;
begin
  Result := FGit.Pull(ARepoPath);
end;

function TGitRuntime.PullFastForwardOnly(const ARepoPath: string): Boolean;
begin
  Result := FGit.PullFastForwardOnly(ARepoPath);
end;

function TGitRuntime.GetLastError: string;
begin
  Result := FGit.LastError;
end;

function TGitRuntime.GetRemoteURL(const ARepoPath: string; const ARemote: string): string;
begin
  Result := FGit.GetRemoteURL(ARepoPath, ARemote);
end;

function TGitRuntime.GetCurrentBranch(const ARepoPath: string): string;
begin
  Result := FGit.GetCurrentBranch(ARepoPath);
end;

function TGitRuntime.GetShortHeadHash(const ARepoPath: string; const ALength: Integer): string;
begin
  Result := FGit.GetShortHeadHash(ARepoPath, ALength);
end;

function TGitRuntime.ListBranches(const ARepoPath: string): TStringArray;
begin
  Result := FGit.ListBranches(ARepoPath);
end;

function TGitRuntime.Add(const ARepoPath, APathSpec: string): Boolean;
begin
  Result := FGit.Add(ARepoPath, APathSpec);
end;

function TGitRuntime.Commit(const ARepoPath, AMessage: string): Boolean;
begin
  Result := FGit.Commit(ARepoPath, AMessage);
end;

function TGitRuntime.Push(const ARepoPath: string; const ARemote: string; const ABranch: string): Boolean;
begin
  Result := FGit.Push(ARepoPath, ARemote, ABranch);
end;

function TGitRuntime.GetVersion: string;
begin
  Result := FGit.GetVersion;
end;

end.
