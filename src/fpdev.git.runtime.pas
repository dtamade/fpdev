unit fpdev.git.runtime;

{$mode objfpc}{$H+}

interface

uses
  fpdev.utils.git;

type
  IGitRuntime = interface
    ['{0DFD2B3A-7A74-4635-A6B2-88EBE4356A3B}']
    function GetBackend: TGitBackend;
    function BackendAvailable: Boolean;
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Fetch(const ARepoPath: string; const ARemote: string = 'origin'): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean = False): Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const ARepoPath: string): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function PullFastForwardOnly(const ARepoPath: string): Boolean;
    function GetLastError: string;
    function GetShortHeadHash(const ARepoPath: string; const ALength: Integer = 7): string;

    property Backend: TGitBackend read GetBackend;
    property LastError: string read GetLastError;
  end;

  TGitRuntime = class(TInterfacedObject, IGitRuntime)
  private
    FGit: TGitOperations;
  public
    constructor Create; overload;
    constructor Create(const ACliRunner: IGitCliRunner; const ACliOnly: Boolean = False); overload;
    destructor Destroy; override;

    function GetBackend: TGitBackend;
    function BackendAvailable: Boolean;
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Fetch(const ARepoPath: string; const ARemote: string = 'origin'): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean = False): Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const ARepoPath: string): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function PullFastForwardOnly(const ARepoPath: string): Boolean;
    function GetLastError: string;
    function GetShortHeadHash(const ARepoPath: string; const ALength: Integer = 7): string;
  end;

implementation

constructor TGitRuntime.Create;
begin
  inherited Create;
  FGit := TGitOperations.Create;
end;

constructor TGitRuntime.Create(const ACliRunner: IGitCliRunner; const ACliOnly: Boolean);
begin
  inherited Create;
  FGit := TGitOperations.Create(ACliRunner, ACliOnly);
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

function TGitRuntime.PullFastForwardOnly(const ARepoPath: string): Boolean;
begin
  Result := FGit.PullFastForwardOnly(ARepoPath);
end;

function TGitRuntime.GetLastError: string;
begin
  Result := FGit.LastError;
end;

function TGitRuntime.GetShortHeadHash(const ARepoPath: string; const ALength: Integer): string;
begin
  Result := FGit.GetShortHeadHash(ARepoPath, ALength);
end;

end.
