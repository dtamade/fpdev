unit fpdev.fpc.defaults;

{$mode objfpc}{$H+}

{
  FPC Default Implementations
  
  This module provides default implementations of the dependency injection interfaces.
  These are the real implementations used in production.
}

interface

uses
  SysUtils, Classes, Process, fphttpclient, fpdev.fpc.interfaces;

type
  { TDefaultFileSystem - Default file system implementation.
    Production implementation of IFileSystem using standard SysUtils functions.
    For testing, use TMockFileSystem instead. }
  TDefaultFileSystem = class(TInterfacedObject, IFileSystem)
  public
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
  end;

  { TDefaultProcessRunner - Default process runner implementation.
    Production implementation of IProcessRunner using TProcess.
    For testing, use TMockProcessRunner instead. }
  TDefaultProcessRunner = class(TInterfacedObject, IProcessRunner)
  public
    function Execute(const AExecutable: string; const AParams: array of string;
      const AWorkDir: string = ''): TProcessResult;
    function ExecuteInDir(const AExecutable: string; const AParams: array of string;
      const AWorkDir: string): TProcessResult;
    function ExecuteWithTimeout(const AExecutable: string; const AParams: array of string;
      const ATimeoutMs: Integer; const AWorkDir: string = ''): TProcessResult;
  end;

  { TDefaultHttpClient - Default HTTP client implementation.
    Production implementation of IHttpClient using TFPHTTPClient.
    For testing, use TMockHttpClient instead. }
  TDefaultHttpClient = class(TInterfacedObject, IHttpClient)
  public
    { @inheritDoc }
    function Get(const AURL: string): THttpResponse;
    { @inheritDoc }
    function Download(const AURL, ADestPath: string): THttpResponse;
  end;

implementation

{ TDefaultFileSystem }

function TDefaultFileSystem.FileExists(const APath: string): Boolean;
begin
  Result := SysUtils.FileExists(APath);
end;

function TDefaultFileSystem.DirectoryExists(const APath: string): Boolean;
begin
  Result := SysUtils.DirectoryExists(APath);
end;

function TDefaultFileSystem.ForceDirectories(const APath: string): Boolean;
begin
  Result := SysUtils.ForceDirectories(APath);
end;

function TDefaultFileSystem.DeleteFile(const APath: string): Boolean;
begin
  Result := SysUtils.DeleteFile(APath);
end;


function TDefaultFileSystem.DeleteDirectory(const APath: string; const ARecursive: Boolean): Boolean;
var
  Proc: TProcess;
begin
  Result := False;
  if not SysUtils.DirectoryExists(APath) then
  begin
    Result := True;
    Exit;
  end;
  
  try
    Proc := TProcess.Create(nil);
    try
      {$IFDEF MSWINDOWS}
      Proc.Executable := 'cmd';
      Proc.Parameters.Add('/c');
      Proc.Parameters.Add('rmdir');
      if ARecursive then
      begin
        Proc.Parameters.Add('/s');
        Proc.Parameters.Add('/q');
      end;
      Proc.Parameters.Add(APath);
      {$ELSE}
      Proc.Executable := 'rm';
      if ARecursive then
        Proc.Parameters.Add('-rf')
      else
        Proc.Parameters.Add('-r');
      Proc.Parameters.Add(APath);
      {$ENDIF}
      Proc.Options := Proc.Options + [poWaitOnExit];
      Proc.Execute;
      Result := Proc.ExitStatus = 0;
    finally
      Proc.Free;
    end;
  except
    Result := False;
  end;
end;

function TDefaultFileSystem.ReadTextFile(const APath: string): string;
var
  SL: TStringList;
begin
  Result := '';
  if not SysUtils.FileExists(APath) then
    Exit;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(APath);
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure TDefaultFileSystem.WriteTextFile(const APath, AContent: string);
var
  SL: TStringList;
  Dir: string;
begin
  Dir := ExtractFileDir(APath);
  if (Dir <> '') and (not SysUtils.DirectoryExists(Dir)) then
    SysUtils.ForceDirectories(Dir);
  SL := TStringList.Create;
  try
    SL.Text := AContent;
    SL.SaveToFile(APath);
  finally
    SL.Free;
  end;
end;

function TDefaultFileSystem.GetTempDir: string;
begin
  Result := SysUtils.GetTempDir;
end;

function TDefaultFileSystem.RemoveDir(const APath: string): Boolean;
begin
  Result := SysUtils.RemoveDir(APath);
end;

procedure TDefaultFileSystem.WriteAllText(const APath, AContent: string);
begin
  WriteTextFile(APath, AContent);
end;

{ TDefaultProcessRunner }

function TDefaultProcessRunner.Execute(const AExecutable: string; const AParams: array of string;
  const AWorkDir: string): TProcessResult;
var
  Proc: TProcess;
  OutLines, ErrLines: TStringList;
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Success := False;
  
  Proc := TProcess.Create(nil);
  OutLines := TStringList.Create;
  ErrLines := TStringList.Create;
  try
    Proc.Executable := AExecutable;
    for i := 0 to High(AParams) do
      Proc.Parameters.Add(AParams[i]);
    if AWorkDir <> '' then
      Proc.CurrentDirectory := AWorkDir;
    Proc.Options := Proc.Options + [poWaitOnExit, poUsePipes];
    
    try
      Proc.Execute;
      OutLines.LoadFromStream(Proc.Output);
      ErrLines.LoadFromStream(Proc.Stderr);
      
      Result.ExitCode := Proc.ExitStatus;
      Result.StdOut := OutLines.Text;
      Result.StdErr := ErrLines.Text;
      Result.Success := Proc.ExitStatus = 0;
    except
      on E: Exception do
      begin
        Result.StdErr := E.Message;
        Result.ExitCode := -1;
      end;
    end;
  finally
    ErrLines.Free;
    OutLines.Free;
    Proc.Free;
  end;
end;

function TDefaultProcessRunner.ExecuteWithTimeout(const AExecutable: string;
  const AParams: array of string; const ATimeoutMs: Integer; const AWorkDir: string): TProcessResult;
begin
  // For simplicity, delegate to Execute (timeout not implemented yet)
  Result := Execute(AExecutable, AParams, AWorkDir);
end;

function TDefaultProcessRunner.ExecuteInDir(const AExecutable: string;
  const AParams: array of string; const AWorkDir: string): TProcessResult;
begin
  Result := Execute(AExecutable, AParams, AWorkDir);
end;

{ TDefaultHttpClient }

function TDefaultHttpClient.Get(const AURL: string): THttpResponse;
var
  Client: TFPHTTPClient;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Success := False;
  
  Client := TFPHTTPClient.Create(nil);
  try
    try
      Result.Content := Client.Get(AURL);
      Result.StatusCode := Client.ResponseStatusCode;
      Result.Success := (Result.StatusCode >= 200) and (Result.StatusCode < 300);
    except
      on E: Exception do
      begin
        Result.ErrorMessage := E.Message;
        Result.StatusCode := -1;
      end;
    end;
  finally
    Client.Free;
  end;
end;

function TDefaultHttpClient.Download(const AURL, ADestPath: string): THttpResponse;
var
  Client: TFPHTTPClient;
  Dir: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Success := False;
  
  Dir := ExtractFileDir(ADestPath);
  if (Dir <> '') and (not SysUtils.DirectoryExists(Dir)) then
    SysUtils.ForceDirectories(Dir);
  
  Client := TFPHTTPClient.Create(nil);
  try
    try
      Client.Get(AURL, ADestPath);
      Result.StatusCode := Client.ResponseStatusCode;
      Result.Success := (Result.StatusCode >= 200) and (Result.StatusCode < 300);
    except
      on E: Exception do
      begin
        Result.ErrorMessage := E.Message;
        Result.StatusCode := -1;
      end;
    end;
  finally
    Client.Free;
  end;
end;

end.
