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
  SysUtils, Classes, Generics.Collections, fpdev.fpc.interfaces;

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

end.
