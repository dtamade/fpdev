unit fpdev.git.runtime;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.git.types;

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

    property Backend: TGitBackend read GetBackend;
    property LastError: string read GetLastError;
  end;

function NewGitRuntime(const ACliOnly: Boolean = False): IGitRuntime;

implementation

uses
  fpdev.git.runtime.impl;

function NewGitRuntime(const ACliOnly: Boolean): IGitRuntime;
begin
  Result := NewGitRuntimeImpl(ACliOnly);
end;

end.
