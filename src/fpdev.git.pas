unit fpdev.git;

{$codepage utf8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process;

type
  { TGitManager }
  TGitManager = class
  private
    function ExecuteGitCommand(const ACommand: string; const AWorkingDir: string = ''): Boolean;
    function GetGitOutput(const ACommand: string; const AWorkingDir: string = ''): string;
    function IsGitInstalled: Boolean;
    function IsGitRepository(const APath: string): Boolean;
    function ExecuteGitParams(const Params: array of string; const AWorkingDir: string = ''): Boolean;

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
end;

destructor TGitManager.Destroy;
begin
  inherited Destroy;
end;

function TGitManager.IsGitInstalled: Boolean;
var
  Process: TProcess;
begin
  Result := False;
  Process := TProcess.Create(nil);
  try
    Process.Executable := 'git';
    Process.Parameters.Add('--version');
    Process.Options := Process.Options + [poWaitOnExit, poUsePipes, poNoConsole];

    try
      Process.Execute;
      Result := Process.ExitStatus = 0;
    except
      Result := False;
    end;
  finally
    Process.Free;
  end;
end;

function TGitManager.GetGitVersion: string;
begin
  Result := GetGitOutput('--version');
  if Result <> '' then
    Result := Trim(Result)
  else
    Result := 'Git not found';
end;

function TGitManager.ValidateGitEnvironment: Boolean;
begin
  Result := IsGitInstalled;
  if Result then
  // WriteLn('[OK] Git found: ', GetGitVersion)  // debug code commented out
  else
  // WriteLn('[FAIL] Git not found. Please install Git first.');  // debug code commented out
end;

function TGitManager.ExecuteGitCommand(const ACommand: string; const AWorkingDir: string): Boolean;
var
  Process: TProcess;
  CommandParts: TStringArray;
  i: Integer;
begin
  Result := False;

  if not IsGitInstalled then
  begin
  // WriteLn('Error: Git is not installed');  // debug code commented out
    Exit;
  end;

  Process := TProcess.Create(nil);
  try
    Process.Executable := 'git';

    // Parse command arguments
    CommandParts := ACommand.Split(' ');
    for i := 0 to High(CommandParts) do
      if Trim(CommandParts[i]) <> '' then
        Process.Parameters.Add(Trim(CommandParts[i]));

    if AWorkingDir <> '' then
      Process.CurrentDirectory := AWorkingDir;

    Process.Options := Process.Options + [poWaitOnExit, poUsePipes];

  // WriteLn('Running: git ', ACommand);  // debug code commented out
    if AWorkingDir <> '' then
  // WriteLn('Working directory: ', AWorkingDir);  // debug code commented out

    try
      Process.Execute;
      Result := Process.ExitStatus = 0;

      if not Result then
  // WriteLn('Git command failed, exit code: ', Process.ExitStatus);  // debug code commented out

    except
      on E: Exception do
      begin
  // WriteLn('Exception while executing Git command: ', E.Message);  // debug code commented out
        Result := False;
      end;
    end;
  finally
    Process.Free;
  end;
end;

function TGitManager.ExecuteGitParams(const Params: array of string; const AWorkingDir: string): Boolean;
var
  Process: TProcess;
  i: Integer;
begin
  Result := False;
  if not IsGitInstalled then Exit;
  Process := TProcess.Create(nil);
  try
    Process.Executable := 'git';
    for i := Low(Params) to High(Params) do
      if Trim(Params[i]) <> '' then
        Process.Parameters.Add(Params[i]);
    if AWorkingDir <> '' then
      Process.CurrentDirectory := AWorkingDir;
    Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
    try
      Process.Execute;
      Result := Process.ExitStatus = 0;
    except
      Result := False;
    end;
  finally
    Process.Free;
  end;
end;

function TGitManager.GetGitOutput(const ACommand: string; const AWorkingDir: string): string;
var
  Process: TProcess;
  CommandParts: TStringArray;
  i: Integer;
  OutputStream: TStringList;
begin
  Result := '';

  if not IsGitInstalled then
    Exit;

  Process := TProcess.Create(nil);
  OutputStream := TStringList.Create;
  try
    Process.Executable := 'git';

    // Parse command arguments
    CommandParts := ACommand.Split(' ');
    for i := 0 to High(CommandParts) do
      if Trim(CommandParts[i]) <> '' then
        Process.Parameters.Add(Trim(CommandParts[i]));

    if AWorkingDir <> '' then
      Process.CurrentDirectory := AWorkingDir;

    Process.Options := Process.Options + [poWaitOnExit, poUsePipes, poNoConsole];

    try
      Process.Execute;

      if Process.ExitStatus = 0 then
      begin
        OutputStream.LoadFromStream(Process.Output);
        Result := OutputStream.Text;
      end;

    except
      on E: Exception do
        Result := '';
    end;
  finally
    OutputStream.Free;
    Process.Free;
  end;
end;

function TGitManager.IsGitRepository(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath + PathDelim + '.git');
end;

function TGitManager.CloneRepository(const AURL, ATargetDir: string; const ABranch: string): Boolean;
var
  Command: string;
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
  if IsGitRepository(ATargetDir) then
  begin
  // WriteLn('Target directory already contains a Git repository, trying to update...');  // debug code commented out
    Result := UpdateRepository(ATargetDir);
    Exit;
  end;

  // Build clone command
  Command := 'clone';
  if ABranch <> '' then
    Command := Command + ' --branch ' + ABranch;
  Command := Command + ' ' + AURL + ' ' + ATargetDir;

  Result := ExecuteGitCommand(Command);

  if Result then
  // WriteLn('[OK] Clone succeeded')  // debug code commented out
  else
  // WriteLn('[FAIL] Clone failed');  // debug code commented out
end;

function TGitManager.UpdateRepository(const ARepoDir: string): Boolean;
begin
  Result := False;

  if not IsGitRepository(ARepoDir) then
  begin
  // WriteLn('Error: ', ARepoDir, ' is not a Git repository');  // debug code commented out
    Exit;
  end;

  // WriteLn('Updating repository: ', ARepoDir);  // debug code commented out

  // Run git pull
  Result := ExecuteGitCommand('pull', ARepoDir);

  if Result then
  // WriteLn('[OK] Update succeeded')  // debug code commented out
  else
  // WriteLn('[FAIL] Update failed');  // debug code commented out
end;

function TGitManager.CheckoutBranch(const ARepoDir, ABranch: string): Boolean;
begin
  Result := False;

  if not IsGitRepository(ARepoDir) then
  begin
  // WriteLn('Error: ', ARepoDir, ' is not a Git repository');  // debug code commented out
    Exit;
  end;

  // WriteLn('Switch to branch: ', ABranch);  // debug code commented out
  Result := ExecuteGitCommand('checkout ' + ABranch, ARepoDir);

  if Result then
  // WriteLn('[OK] Branch switch succeeded')  // debug code commented out
  else
  // WriteLn('[FAIL] Branch switch failed');  // debug code commented out
end;

function TGitManager.GetCurrentBranch(const ARepoDir: string): string;
begin
  Result := Trim(GetGitOutput('rev-parse --abbrev-ref HEAD', ARepoDir));
end;

function TGitManager.ListBranches(const ARepoDir: string): TStringArray;
var
  Output: string;
  Lines: TStringArray;
  i: Integer;
  Branch: string;
begin
  SetLength(Result, 0);

  Output := GetGitOutput('branch -r', ARepoDir);
  if Output = '' then
    Exit;

  Lines := Output.Split([#10, #13]);
  for i := 0 to High(Lines) do
  begin
    Branch := Trim(Lines[i]);
    if (Branch <> '') and (Pos('origin/', Branch) > 0) then
    begin
      Branch := StringReplace(Branch, 'origin/', '', []);
      if Branch <> 'HEAD' then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Branch;
      end;
    end;
  end;
end;

function TGitManager.GetLastCommitHash(const ARepoDir: string): string;
begin
  Result := Trim(GetGitOutput('rev-parse HEAD', ARepoDir));
end;

function TGitManager.Add(const ARepoDir, APathSpec: string): Boolean;
begin
  Result := ExecuteGitParams(['add', APathSpec], ARepoDir);
end;

function TGitManager.Commit(const ARepoDir, AMessage: string): Boolean;
var
  CommitMessage: string;
begin
  CommitMessage := AMessage;
  if CommitMessage = '' then
    CommitMessage := 'update index.json';
  Result := ExecuteGitParams(['commit', '-m', CommitMessage], ARepoDir);
end;

function TGitManager.Push(const ARepoDir: string; const ARemote: string; const ABranch: string): Boolean;
var
  BranchParam: string;
begin
  BranchParam := ABranch;
  if BranchParam = '' then
    BranchParam := GetCurrentBranch(ARepoDir);
  if BranchParam = '' then
    BranchParam := 'HEAD';
  Result := ExecuteGitParams(['push', ARemote, BranchParam], ARepoDir);
end;

end.
