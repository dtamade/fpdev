unit fpdev.lazarus.manager.adaptrflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.git.runtime, fpdev.git.types, fpdev.lazarus.installcallbacks;

type
  { TLazarusGitClient - Bridges IGitRuntime to ILazarusInstallGitClient }
  TLazarusGitClient = class(TInterfacedObject, ILazarusInstallGitClient)
  private
    FGit: IGitRuntime;
  public
    constructor Create(const ACliOnly: Boolean);
    destructor Destroy; override;
    function GetBackend: TGitBackend;
    function BackendAvailable: Boolean;
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Fetch(const ARepoPath: string; const ARemote: string = 'origin'): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean = False): Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const ARepoPath: string): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function GetLastError: string;
  end;

implementation

{ TLazarusGitClient }

constructor TLazarusGitClient.Create(const ACliOnly: Boolean);
begin
  inherited Create;
  FGit := NewGitRuntime(ACliOnly);
end;

destructor TLazarusGitClient.Destroy;
begin
  FGit := nil;
  inherited Destroy;
end;

function TLazarusGitClient.GetBackend: TGitBackend;
begin
  Result := FGit.Backend;
end;

function TLazarusGitClient.BackendAvailable: Boolean;
begin
  Result := FGit.Backend <> gbNone;
end;

function TLazarusGitClient.Clone(const AURL, ALocalPath: string;
  const ABranch: string): Boolean;
begin
  Result := FGit.Clone(AURL, ALocalPath, ABranch);
end;

function TLazarusGitClient.Fetch(const ARepoPath: string;
  const ARemote: string): Boolean;
begin
  Result := FGit.Fetch(ARepoPath, ARemote);
end;

function TLazarusGitClient.Checkout(const ARepoPath, AName: string;
  const Force: Boolean): Boolean;
begin
  Result := FGit.Checkout(ARepoPath, AName, Force);
end;

function TLazarusGitClient.IsRepository(const APath: string): Boolean;
begin
  Result := FGit.IsRepository(APath);
end;

function TLazarusGitClient.HasRemote(const ARepoPath: string): Boolean;
begin
  Result := FGit.HasRemote(ARepoPath);
end;

function TLazarusGitClient.Pull(const ARepoPath: string): Boolean;
begin
  Result := FGit.PullFastForwardOnly(ARepoPath);
end;

function TLazarusGitClient.GetLastError: string;
begin
  Result := FGit.LastError;
end;

end.
