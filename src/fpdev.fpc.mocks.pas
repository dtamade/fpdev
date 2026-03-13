unit fpdev.fpc.mocks;

{$mode objfpc}{$H+}
// acq:allow-hardcoded-constants-file

{
  FPC Mock Implementations
  
  This module provides mock implementations of the dependency injection interfaces
  for unit testing purposes.
}

interface

uses
  SysUtils, Classes, Generics.Collections,
  git2.api, git2.types,
  fpdev.fpc.interfaces;

type
  { TMockFileSystem - Mock file system for testing }
  TMockFileSystem = class(TInterfacedObject, IFileSystem)
  private
    FFiles: specialize TDictionary<string, string>;
    FDirectories: specialize TList<string>;
    FTempDir: string;
  public
    constructor Create;
    destructor Destroy; override;
    
    { IFileSystem implementation }
    function FileExists(const APath: string): Boolean;
    function DirectoryExists(const APath: string): Boolean;
    function ForceDirectories(const APath: string): Boolean;
    function DeleteFile(const APath: string): Boolean;
    function DeleteDirectory(const APath: string; const ARecursive: Boolean): Boolean;
    function RemoveDir(const APath: string): Boolean;
    function ReadTextFile(const APath: string): string;
    procedure WriteTextFile(const APath, AContent: string);
    procedure WriteAllText(const APath, AContent: string);
    function GetTempDir: string;
    
    { Test helpers }
    procedure AddFile(const APath, AContent: string);
    procedure AddDirectory(const APath: string);
    procedure SetTempDir(const APath: string);
    procedure Clear;
  end;

  { TMockProcessResult - Configurable process result }
  TMockProcessResult = record
    ExitCode: Integer;
    StdOut: string;
    StdErr: string;
  end;

  { TMockProcessRunner - Mock process runner for testing }
  TMockProcessRunner = class(TInterfacedObject, IProcessRunner)
  private
    FResults: specialize TDictionary<string, TMockProcessResult>;
    FDefaultResult: TMockProcessResult;
    FExecutedCommands: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    
    { IProcessRunner implementation }
    function Execute(const AExecutable: string; const AParams: array of string;
      const AWorkDir: string = ''): TProcessResult;
    function ExecuteInDir(const AExecutable: string; const AParams: array of string;
      const AWorkDir: string): TProcessResult;
    function ExecuteWithTimeout(const AExecutable: string; const AParams: array of string;
      const ATimeoutMs: Integer; const AWorkDir: string = ''): TProcessResult;
    
    { Test helpers }
    procedure SetResult(const AExecutable: string; AExitCode: Integer;
      const AStdOut: string = ''; const AStdErr: string = '');
    procedure SetDefaultResult(AExitCode: Integer; const AStdOut: string = '';
      const AStdErr: string = '');
    function GetExecutedCommands: TStringList;
    procedure Clear;
  end;

  { TMockHttpClient - Mock HTTP client for testing }
  TMockHttpClient = class(TInterfacedObject, IHttpClient)
  private
    FResponses: specialize TDictionary<string, THttpResponse>;
    FDefaultResponse: THttpResponse;
    FRequestedURLs: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    
    { IHttpClient implementation }
    function Get(const AURL: string): THttpResponse;
    function Download(const AURL, ADestPath: string): THttpResponse;
    
    { Test helpers }
    procedure SetResponse(const AURL: string; AStatusCode: Integer;
      const AContent: string = ''; const AErrorMessage: string = '');
    procedure SetDefaultResponse(AStatusCode: Integer; const AContent: string = '';
      const AErrorMessage: string = '');
    function GetRequestedURLs: TStringList;
    procedure Clear;
  end;

  { TMockGitRepository - Mock git repository for DI tests }
  TMockGitRepository = class(TInterfacedObject, IGitRepository, IGitRepositoryExt)
  private
    FPath: string;
    FWorkDir: string;
    FFetchOk: Boolean;
    FCheckoutOk: Boolean;
    FPullResult: TGitPullFastForwardResult;
    FPullError: string;
  public
    constructor Create(const APath: string);

    procedure SetFetchOk(AOk: Boolean);
    procedure SetCheckoutOk(AOk: Boolean);
    procedure SetPullResult(AResult: TGitPullFastForwardResult; const AError: string = '');

    // IGitRepository
    function Path: string;
    function WorkDir: string;
    function IsBare: Boolean;
    function IsEmpty: Boolean;
    function Head: IGitReference;
    function CurrentBranch: string;
    function ListBranches(Kind: TGitBranchKind = gbLocal): TStringArray;
    function CommitByHash(const Hash: string): IGitCommit;
    function HeadCommit: IGitCommit;
    function Remote(const Name: string = 'origin'): IGitRemote;
    function Fetch(const RemoteName: string = 'origin'): Boolean;
    function CheckoutBranch(const Branch: string): Boolean;
    function CheckoutBranchEx(const Branch: string; Force: Boolean): Boolean;
    function Status: TStringArray;
    function StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
    function IsClean: Boolean;
    function HasUncommittedChanges: Boolean;

    // IGitRepositoryExt
    function ListRemotes: TStringArray;
    function PullFastForward(const RemoteName: string; out Error: string): TGitPullFastForwardResult;
  end;

  { TMockGitManager - Mock git manager for DI tests (libgit2-first callers) }
  TMockGitManager = class(TInterfacedObject, IGitManager)
  private
    FInitializeOk: Boolean;
    FInitialized: Boolean;
    FVerifySSL: Boolean;
    FCloneRepo: IGitRepository;
    FOpenRepo: IGitRepository;
    FIsRepoOk: Boolean;
  public
    constructor Create;

    procedure SetInitializeOk(AOk: Boolean);
    procedure SetCloneRepositoryResult(ARepo: IGitRepository);
    procedure SetOpenRepositoryResult(ARepo: IGitRepository);
    procedure SetIsRepositoryResult(AOk: Boolean);

    // IGitManager
    function Initialize: Boolean;
    procedure Finalize;
    function OpenRepository(const APath: string): IGitRepository;
    function CloneRepository(const AURL, ALocalPath: string): IGitRepository;
    function InitRepository(const APath: string; ABare: Boolean = False): IGitRepository;
    function IsRepository(const APath: string): Boolean;
    function DiscoverRepository(const AStartPath: string): string;
    function GetGlobalConfig(const AKey: string): string;
    function SetGlobalConfig(const AKey, AValue: string): Boolean;
    function Version: string;
    procedure SetVerifySSL(AEnabled: Boolean);
    procedure SetCredentialAcquireHandler(AHandler: TCredentialAcquireEvent);
    procedure SetCertificateCheckHandler(AHandler: TCertificateCheckEvent);
    function Initialized: Boolean;
    function VerifySSL: Boolean;
  end;

implementation

{ TMockFileSystem }

constructor TMockFileSystem.Create;
begin
  inherited Create;
  FFiles := specialize TDictionary<string, string>.Create;
  FDirectories := specialize TList<string>.Create;
  {$IFDEF MSWINDOWS}
  FTempDir := 'C:\Temp\mock';
  {$ELSE}
  FTempDir := '/tmp/mock';
  {$ENDIF}
end;

destructor TMockFileSystem.Destroy;
begin
  FDirectories.Free;
  FFiles.Free;
  inherited Destroy;
end;

function TMockFileSystem.FileExists(const APath: string): Boolean;
begin
  Result := FFiles.ContainsKey(APath);
end;

function TMockFileSystem.DirectoryExists(const APath: string): Boolean;
begin
  Result := FDirectories.Contains(APath);
end;

function TMockFileSystem.ForceDirectories(const APath: string): Boolean;
begin
  if not FDirectories.Contains(APath) then
    FDirectories.Add(APath);
  Result := True;
end;

function TMockFileSystem.DeleteFile(const APath: string): Boolean;
begin
  Result := FFiles.ContainsKey(APath);
  if Result then
    FFiles.Remove(APath);
end;

function TMockFileSystem.DeleteDirectory(const APath: string; const ARecursive: Boolean): Boolean;
begin
  Result := FDirectories.Contains(APath);
  if Result then
    FDirectories.Remove(APath);
end;

function TMockFileSystem.RemoveDir(const APath: string): Boolean;
begin
  Result := DeleteDirectory(APath, False);
end;

function TMockFileSystem.ReadTextFile(const APath: string): string;
begin
  if FFiles.ContainsKey(APath) then
    Result := FFiles[APath]
  else
    Result := '';
end;

procedure TMockFileSystem.WriteTextFile(const APath, AContent: string);
begin
  FFiles.AddOrSetValue(APath, AContent);
end;

procedure TMockFileSystem.WriteAllText(const APath, AContent: string);
begin
  WriteTextFile(APath, AContent);
end;

function TMockFileSystem.GetTempDir: string;
begin
  Result := FTempDir;
end;

procedure TMockFileSystem.AddFile(const APath, AContent: string);
begin
  FFiles.AddOrSetValue(APath, AContent);
end;

procedure TMockFileSystem.AddDirectory(const APath: string);
begin
  if not FDirectories.Contains(APath) then
    FDirectories.Add(APath);
end;

procedure TMockFileSystem.SetTempDir(const APath: string);
begin
  FTempDir := APath;
end;

procedure TMockFileSystem.Clear;
begin
  FFiles.Clear;
  FDirectories.Clear;
end;

{ TMockProcessRunner }

constructor TMockProcessRunner.Create;
begin
  inherited Create;
  FResults := specialize TDictionary<string, TMockProcessResult>.Create;
  FExecutedCommands := TStringList.Create;
  FDefaultResult.ExitCode := 0;
  FDefaultResult.StdOut := '';
  FDefaultResult.StdErr := '';
end;

destructor TMockProcessRunner.Destroy;
begin
  FExecutedCommands.Free;
  FResults.Free;
  inherited Destroy;
end;

function TMockProcessRunner.Execute(const AExecutable: string; const AParams: array of string;
  const AWorkDir: string): TProcessResult;
var
  MockResult: TMockProcessResult;
  CmdLine: string;
  i: Integer;
begin
  CmdLine := AExecutable;
  for i := 0 to High(AParams) do
    CmdLine := CmdLine + ' ' + AParams[i];
  FExecutedCommands.Add(CmdLine);
  
  if FResults.TryGetValue(AExecutable, MockResult) then
  begin
    Result.ExitCode := MockResult.ExitCode;
    Result.StdOut := MockResult.StdOut;
    Result.StdErr := MockResult.StdErr;
  end
  else
  begin
    Result.ExitCode := FDefaultResult.ExitCode;
    Result.StdOut := FDefaultResult.StdOut;
    Result.StdErr := FDefaultResult.StdErr;
  end;
  Result.Success := Result.ExitCode = 0;
end;

function TMockProcessRunner.ExecuteInDir(const AExecutable: string;
  const AParams: array of string; const AWorkDir: string): TProcessResult;
begin
  Result := Execute(AExecutable, AParams, AWorkDir);
end;

function TMockProcessRunner.ExecuteWithTimeout(const AExecutable: string;
  const AParams: array of string; const ATimeoutMs: Integer; const AWorkDir: string): TProcessResult;
begin
  Result := Execute(AExecutable, AParams, AWorkDir);
end;

procedure TMockProcessRunner.SetResult(const AExecutable: string; AExitCode: Integer;
  const AStdOut: string; const AStdErr: string);
var
  MockResult: TMockProcessResult;
begin
  MockResult.ExitCode := AExitCode;
  MockResult.StdOut := AStdOut;
  MockResult.StdErr := AStdErr;
  FResults.AddOrSetValue(AExecutable, MockResult);
end;

procedure TMockProcessRunner.SetDefaultResult(AExitCode: Integer; const AStdOut: string;
  const AStdErr: string);
begin
  FDefaultResult.ExitCode := AExitCode;
  FDefaultResult.StdOut := AStdOut;
  FDefaultResult.StdErr := AStdErr;
end;

function TMockProcessRunner.GetExecutedCommands: TStringList;
begin
  Result := FExecutedCommands;
end;

procedure TMockProcessRunner.Clear;
begin
  FResults.Clear;
  FExecutedCommands.Clear;
end;

{ TMockHttpClient }

constructor TMockHttpClient.Create;
begin
  inherited Create;
  FResponses := specialize TDictionary<string, THttpResponse>.Create;
  FRequestedURLs := TStringList.Create;
  FDefaultResponse.StatusCode := 200;
  FDefaultResponse.Content := '';
  FDefaultResponse.Success := True;
end;

destructor TMockHttpClient.Destroy;
begin
  FRequestedURLs.Free;
  FResponses.Free;
  inherited Destroy;
end;

function TMockHttpClient.Get(const AURL: string): THttpResponse;
begin
  FRequestedURLs.Add(AURL);
  if FResponses.TryGetValue(AURL, Result) then
    Exit;
  Result := FDefaultResponse;
end;

function TMockHttpClient.Download(const AURL, ADestPath: string): THttpResponse;
begin
  FRequestedURLs.Add(AURL + ' -> ' + ADestPath);
  if FResponses.TryGetValue(AURL, Result) then
    Exit;
  Result := FDefaultResponse;
end;

procedure TMockHttpClient.SetResponse(const AURL: string; AStatusCode: Integer;
  const AContent: string; const AErrorMessage: string);
var
  Response: THttpResponse;
begin
  FillChar(Response, SizeOf(Response), 0);
  Response.StatusCode := AStatusCode;
  Response.Content := AContent;
  Response.ErrorMessage := AErrorMessage;
  Response.Success := (AStatusCode >= 200) and (AStatusCode < 300);
  FResponses.AddOrSetValue(AURL, Response);
end;

procedure TMockHttpClient.SetDefaultResponse(AStatusCode: Integer; const AContent: string;
  const AErrorMessage: string);
begin
  FDefaultResponse.StatusCode := AStatusCode;
  FDefaultResponse.Content := AContent;
  FDefaultResponse.ErrorMessage := AErrorMessage;
  FDefaultResponse.Success := (AStatusCode >= 200) and (AStatusCode < 300);
end;

function TMockHttpClient.GetRequestedURLs: TStringList;
begin
  Result := FRequestedURLs;
end;

procedure TMockHttpClient.Clear;
begin
  FResponses.Clear;
  FRequestedURLs.Clear;
end;

{ TMockGitRepository }

constructor TMockGitRepository.Create(const APath: string);
begin
  inherited Create;
  FPath := APath;
  FWorkDir := APath;
  FFetchOk := True;
  FCheckoutOk := True;
  FPullResult := gpffUpToDate;
  FPullError := '';
end;

procedure TMockGitRepository.SetFetchOk(AOk: Boolean);
begin
  FFetchOk := AOk;
end;

procedure TMockGitRepository.SetCheckoutOk(AOk: Boolean);
begin
  FCheckoutOk := AOk;
end;

procedure TMockGitRepository.SetPullResult(AResult: TGitPullFastForwardResult; const AError: string);
begin
  FPullResult := AResult;
  FPullError := AError;
end;

function TMockGitRepository.Path: string;
begin
  Result := FPath;
end;

function TMockGitRepository.WorkDir: string;
begin
  Result := FWorkDir;
end;

function TMockGitRepository.IsBare: Boolean;
begin
  Result := False;
end;

function TMockGitRepository.IsEmpty: Boolean;
begin
  Result := False;
end;

function TMockGitRepository.Head: IGitReference;
begin
  Result := nil;
end;

function TMockGitRepository.CurrentBranch: string;
begin
  Result := 'main';
end;

function TMockGitRepository.ListBranches(Kind: TGitBranchKind): TStringArray;
begin
  if Kind = gbAll then;
  Result := nil;
end;

function TMockGitRepository.CommitByHash(const Hash: string): IGitCommit;
begin
  if Hash <> '' then;
  Result := nil;
end;

function TMockGitRepository.HeadCommit: IGitCommit;
begin
  Result := nil;
end;

function TMockGitRepository.Remote(const Name: string): IGitRemote;
begin
  if Name <> '' then;
  Result := nil;
end;

function TMockGitRepository.Fetch(const RemoteName: string): Boolean;
begin
  if RemoteName <> '' then;
  Result := FFetchOk;
end;

function TMockGitRepository.CheckoutBranch(const Branch: string): Boolean;
begin
  if Branch <> '' then;
  Result := FCheckoutOk;
end;

function TMockGitRepository.CheckoutBranchEx(const Branch: string; Force: Boolean): Boolean;
begin
  if Force then;
  if Branch <> '' then;
  Result := FCheckoutOk;
end;

function TMockGitRepository.Status: TStringArray;
begin
  Result := nil;
end;

function TMockGitRepository.StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
begin
  if Filter.IncludeUntracked then;
  Result := nil;
end;

function TMockGitRepository.IsClean: Boolean;
begin
  Result := True;
end;

function TMockGitRepository.HasUncommittedChanges: Boolean;
begin
  Result := False;
end;

function TMockGitRepository.ListRemotes: TStringArray;
begin
  SetLength(Result, 1);
  Result[0] := 'origin';
end;

function TMockGitRepository.PullFastForward(const RemoteName: string; out Error: string): TGitPullFastForwardResult;
begin
  if RemoteName <> '' then;
  Error := FPullError;
  Result := FPullResult;
end;

{ TMockGitManager }

constructor TMockGitManager.Create;
begin
  inherited Create;
  FInitializeOk := False;
  FInitialized := False;
  FVerifySSL := True;
  FCloneRepo := nil;
  FOpenRepo := nil;
  FIsRepoOk := False;
end;

procedure TMockGitManager.SetInitializeOk(AOk: Boolean);
begin
  FInitializeOk := AOk;
end;

procedure TMockGitManager.SetCloneRepositoryResult(ARepo: IGitRepository);
begin
  FCloneRepo := ARepo;
end;

procedure TMockGitManager.SetOpenRepositoryResult(ARepo: IGitRepository);
begin
  FOpenRepo := ARepo;
end;

procedure TMockGitManager.SetIsRepositoryResult(AOk: Boolean);
begin
  FIsRepoOk := AOk;
end;

function TMockGitManager.Initialize: Boolean;
begin
  FInitialized := FInitializeOk;
  Result := FInitialized;
end;

procedure TMockGitManager.Finalize;
begin
  FInitialized := False;
end;

function TMockGitManager.OpenRepository(const APath: string): IGitRepository;
begin
  if APath <> '' then;
  Result := FOpenRepo;
end;

function TMockGitManager.CloneRepository(const AURL, ALocalPath: string): IGitRepository;
begin
  if AURL <> '' then;
  if ALocalPath <> '' then;
  Result := FCloneRepo;
end;

function TMockGitManager.InitRepository(const APath: string; ABare: Boolean): IGitRepository;
begin
  if ABare then;
  Result := TMockGitRepository.Create(APath) as IGitRepository;
end;

function TMockGitManager.IsRepository(const APath: string): Boolean;
begin
  if APath <> '' then;
  Result := FIsRepoOk;
end;

function TMockGitManager.DiscoverRepository(const AStartPath: string): string;
begin
  if AStartPath <> '' then;
  Result := '';
end;

function TMockGitManager.GetGlobalConfig(const AKey: string): string;
begin
  if AKey <> '' then;
  Result := '';
end;

function TMockGitManager.SetGlobalConfig(const AKey, AValue: string): Boolean;
begin
  if AKey <> '' then;
  if AValue <> '' then;
  Result := True;
end;

function TMockGitManager.Version: string;
begin
  Result := 'mock';
end;

procedure TMockGitManager.SetVerifySSL(AEnabled: Boolean);
begin
  FVerifySSL := AEnabled;
end;

procedure TMockGitManager.SetCredentialAcquireHandler(AHandler: TCredentialAcquireEvent);
begin
  if Assigned(AHandler) then;
end;

procedure TMockGitManager.SetCertificateCheckHandler(AHandler: TCertificateCheckEvent);
begin
  if Assigned(AHandler) then;
end;

function TMockGitManager.Initialized: Boolean;
begin
  Result := FInitialized;
end;

function TMockGitManager.VerifySSL: Boolean;
begin
  Result := FVerifySSL;
end;

end.
