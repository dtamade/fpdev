unit fpdev.git;

{$codepage utf8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.utils.git;

type
  { TGitManager }
  TGitManager = class
  private
    FGitOps: TGitOperations;

  public
    constructor Create;
    destructor Destroy; override;

    // Basic Git operations
    function CloneRepository(const AURL, ATargetDir: string; const ABranch: string = ''): Boolean;
    function UpdateRepository(const ARepoDir: string): Boolean;
    function CheckoutBranch(const ARepoDir, ABranch: string): Boolean;
    function GetCurrentBranch(const ARepoDir: string): string;
    function ListBranches(const ARepoDir: string): TStringArray;
    function GetLastCommitHash(const ARepoDir: string): string;
    function Add(const ARepoDir, APathSpec: string): Boolean;
    function Commit(const ARepoDir, AMessage: string): Boolean;
    function Push(const ARepoDir: string; const ARemote: string = 'origin'; const ABranch: string = ''): Boolean;

    // Validation and checks
    function ValidateGitEnvironment: Boolean;
    function GetGitVersion: string;
  end;

implementation

{ TGitManager }

constructor TGitManager.Create;
begin
  inherited Create;
  FGitOps := TGitOperations.Create;
end;

destructor TGitManager.Destroy;
begin
  if Assigned(FGitOps) then
    FGitOps.Free;
  inherited Destroy;
end;

function TGitManager.GetGitVersion: string;
begin
  if Assigned(FGitOps) then
  begin
    Result := Trim(FGitOps.GetVersion);
    if (Result <> '') and (FGitOps.Backend = gbLibgit2) then
      Result := 'libgit2 ' + Result;
    if Result <> '' then
      Exit;
  end;
  Result := 'Git not found';
end;

function TGitManager.ValidateGitEnvironment: Boolean;
begin
  Result := Assigned(FGitOps) and (FGitOps.Backend <> gbNone);
end;

function TGitManager.CloneRepository(const AURL, ATargetDir: string; const ABranch: string): Boolean;
var
  ParentDir: string;
begin
  Result := False;

  // WriteLn('Cloning repository...');  // debug code commented out
  // WriteLn('URL: ', AURL);  // debug code commented out
  // WriteLn('Target directory: ', ATargetDir);  // debug code commented out
  if ABranch <> '' then
  // WriteLn('Branch: ', ABranch);  // debug code commented out

  // Ensure parent directory exists
  ParentDir := ExtractFileDir(ATargetDir);
  if not DirectoryExists(ParentDir) then
  begin
  // WriteLn('Creating directory: ', ParentDir);  // debug code commented out
    if not ForceDirectories(ParentDir) then
    begin
  // WriteLn('Error: unable to create directory ', ParentDir);  // debug code commented out
      Exit;
    end;
  end;

  // If the target directory already exists and is a Git repository, update instead of cloning
  if Assigned(FGitOps) and FGitOps.IsRepository(ATargetDir) then
  begin
  // WriteLn('Target directory already contains a Git repository, trying to update...');  // debug code commented out
    Result := UpdateRepository(ATargetDir);
    Exit;
  end;

  if not Assigned(FGitOps) then
    Exit(False);

  // libgit2-first clone with CLI fallback inside TGitOperations
  Result := FGitOps.Clone(AURL, ATargetDir, ABranch);

  if Result then
  // WriteLn('[OK] Clone succeeded')  // debug code commented out
  else
  // WriteLn('[FAIL] Clone failed');  // debug code commented out
end;

function TGitManager.UpdateRepository(const ARepoDir: string): Boolean;
begin
  Result := False;

  if (not Assigned(FGitOps)) or (not FGitOps.IsRepository(ARepoDir)) then
  begin
  // WriteLn('Error: ', ARepoDir, ' is not a Git repository');  // debug code commented out
    Exit;
  end;

  // WriteLn('Updating repository: ', ARepoDir);  // debug code commented out

  // Run the repository update helper
  Result := FGitOps.Pull(ARepoDir);

  if Result then
  // WriteLn('[OK] Update succeeded')  // debug code commented out
  else
  // WriteLn('[FAIL] Update failed');  // debug code commented out
end;

function TGitManager.CheckoutBranch(const ARepoDir, ABranch: string): Boolean;
begin
  Result := False;

  if (not Assigned(FGitOps)) or (not FGitOps.IsRepository(ARepoDir)) then
  begin
  // WriteLn('Error: ', ARepoDir, ' is not a Git repository');  // debug code commented out
    Exit;
  end;

  // WriteLn('Switch to branch: ', ABranch);  // debug code commented out
  Result := FGitOps.Checkout(ARepoDir, ABranch, False);

  if Result then
  // WriteLn('[OK] Branch switch succeeded')  // debug code commented out
  else
  // WriteLn('[FAIL] Branch switch failed');  // debug code commented out
end;

function TGitManager.GetCurrentBranch(const ARepoDir: string): string;
begin
  if Assigned(FGitOps) then
    Result := FGitOps.GetCurrentBranch(ARepoDir)
  else
    Result := '';
end;

function TGitManager.ListBranches(const ARepoDir: string): TStringArray;
begin
  if Assigned(FGitOps) then
    Result := FGitOps.ListRemoteBranches(ARepoDir, 'origin')
  else
    Result := nil;
end;

function TGitManager.GetLastCommitHash(const ARepoDir: string): string;
begin
  if Assigned(FGitOps) then
    Result := FGitOps.GetShortHeadHash(ARepoDir, 40)
  else
    Result := '';
end;

function TGitManager.Add(const ARepoDir, APathSpec: string): Boolean;
begin
  if Assigned(FGitOps) then
    Result := FGitOps.Add(ARepoDir, APathSpec)
  else
    Result := False;
end;

function TGitManager.Commit(const ARepoDir, AMessage: string): Boolean;
var
  CommitMessage: string;
begin
  CommitMessage := AMessage;
  if CommitMessage = '' then
    CommitMessage := 'update index.json';
  if Assigned(FGitOps) then
    Result := FGitOps.Commit(ARepoDir, CommitMessage)
  else
    Result := False;
end;

function TGitManager.Push(const ARepoDir: string; const ARemote: string; const ABranch: string): Boolean;
begin
  if Assigned(FGitOps) then
    Result := FGitOps.Push(ARepoDir, ARemote, ABranch)
  else
    Result := False;
end;

end.
