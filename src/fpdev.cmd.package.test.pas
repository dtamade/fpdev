unit fpdev.cmd.package.test;

{$mode objfpc}{$H+}

(*
  Package Test Command Module

  Provides functionality for testing packages in isolated environments:
  - Extract package archives to temporary directories
  - Load and validate package metadata
  - Install package dependencies
  - Run test scripts from package.json
  - Cleanup temporary directories

  Usage:
    fpdev package test mylib-1.0.0.tar.gz
    fpdev package test ./mylib
*)

interface

uses
  SysUtils, Classes, Process, fpjson, jsonparser;

type
  { TPackageTestCommand }
  TPackageTestCommand = class
  private
    FTempDir: string;
    FLastError: string;

    function IsArchive(const APath: string): Boolean;
    function LoadPackageMetadata(const APackageDir: string; out AMetadata: TJSONObject): Boolean;
    function GetTestScript(const AMetadata: TJSONObject): string;

  public
    constructor Create;
    destructor Destroy; override;

    { Extract package archive to temporary directory }
    function ExtractToTempDir(const AArchive: string): string;

    { Install package dependencies (stub for now, will integrate with Week 8 resolver) }
    function InstallDependencies(const APackageDir: string): Boolean;

    { Run test script from package.json }
    function RunTests(const APackageDir: string): Boolean;

    { Cleanup temporary directory }
    function CleanupTempDir(const ATempDir: string): Boolean;

    { Get last error message }
    function GetLastError: string;

    property TempDir: string read FTempDir;
  end;

implementation

{ TPackageTestCommand }

constructor TPackageTestCommand.Create;
begin
  inherited Create;
  FTempDir := '';
  FLastError := '';
end;

destructor TPackageTestCommand.Destroy;
begin
  // Cleanup temp directory if it exists
  if (FTempDir <> '') and DirectoryExists(FTempDir) then
    CleanupTempDir(FTempDir);
  inherited Destroy;
end;

function TPackageTestCommand.IsArchive(const APath: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(APath));
  Result := (Ext = '.gz') or (Ext = '.tgz') or (Ext = '.tar');
end;

function TPackageTestCommand.LoadPackageMetadata(const APackageDir: string; out AMetadata: TJSONObject): Boolean;
var
  MetaPath: string;
  J: TJSONData;
  FS: TFileStream;
begin
  Result := False;
  AMetadata := nil;
  FLastError := '';

  MetaPath := APackageDir + PathDelim + 'package.json';
  if not FileExists(MetaPath) then
  begin
    FLastError := 'package.json not found in package directory';
    Exit;
  end;

  try
    FS := TFileStream.Create(MetaPath, fmOpenRead or fmShareDenyWrite);
    try
      J := GetJSON(FS);
      if J is TJSONObject then
      begin
        AMetadata := TJSONObject(J);
        Result := True;
      end
      else
      begin
        J.Free;
        FLastError := 'package.json is not a valid JSON object';
      end;
    finally
      FS.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to load package.json: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TPackageTestCommand.GetTestScript(const AMetadata: TJSONObject): string;
var
  Scripts: TJSONObject;
begin
  Result := '';

  if AMetadata.Find('scripts') <> nil then
  begin
    Scripts := AMetadata.Objects['scripts'];
    if Scripts.Find('test') <> nil then
      Result := Scripts.Get('test', '');
  end;
end;

function TPackageTestCommand.ExtractToTempDir(const AArchive: string): string;
var
  Process: TProcess;
  ExitCode: Integer;
  TempBase: string;
begin
  Result := '';
  FLastError := '';

  if not FileExists(AArchive) then
  begin
    FLastError := 'Archive file not found: ' + AArchive;
    Exit;
  end;

  // Create temporary directory
  TempBase := GetTempDir + 'fpdev-test-' + IntToStr(Random(99999));
  if not ForceDirectories(TempBase) then
  begin
    FLastError := 'Failed to create temporary directory: ' + TempBase;
    Exit;
  end;

  // Extract archive using tar
  Process := TProcess.Create(nil);
  try
    Process.Executable := 'tar';
    Process.Parameters.Add('-xzf');
    Process.Parameters.Add(ExpandFileName(AArchive));
    Process.Parameters.Add('-C');
    Process.Parameters.Add(TempBase);
    Process.Options := [poWaitOnExit, poUsePipes];

    try
      Process.Execute;
      ExitCode := Process.ExitStatus;

      if ExitCode = 0 then
      begin
        FTempDir := TempBase;
        Result := TempBase;
      end
      else
      begin
        FLastError := Format('tar extraction failed with exit code %d', [ExitCode]);
        // Cleanup failed extraction
        CleanupTempDir(TempBase);
      end;
    except
      on E: Exception do
      begin
        FLastError := 'Failed to execute tar command: ' + E.Message;
        CleanupTempDir(TempBase);
      end;
    end;
  finally
    Process.Free;
  end;

  // Additional validation: ensure error is set if result is empty
  if (Result = '') and (FLastError = '') then
    FLastError := 'Archive extraction failed';
end;

function TPackageTestCommand.InstallDependencies(const APackageDir: string): Boolean;
var
  Metadata: TJSONObject;
  Dependencies: TJSONObject;
begin
  Result := False;
  FLastError := '';

  // Load package metadata
  if not LoadPackageMetadata(APackageDir, Metadata) then
    Exit;

  try
    // Check if package has dependencies
    if Metadata.Find('dependencies') = nil then
    begin
      // No dependencies to install
      Result := True;
      Exit;
    end;

    Dependencies := Metadata.Objects['dependencies'];
    if Dependencies.Count = 0 then
    begin
      // Empty dependencies
      Result := True;
      Exit;
    end;

    // TODO: Integrate with Week 8 dependency resolver
    // For now, just return success if dependencies exist
    WriteLn('[INFO] Dependency installation not yet implemented');
    WriteLn('[INFO] Found ', Dependencies.Count, ' dependencies in package.json');
    Result := True;
  finally
    Metadata.Free;
  end;
end;

function TPackageTestCommand.RunTests(const APackageDir: string): Boolean;
var
  Metadata: TJSONObject;
  TestScript: string;
  Process: TProcess;
  ExitCode: Integer;
  OutputLines: TStringList;
  Line: string;
begin
  Result := False;
  FLastError := '';

  // Load package metadata
  if not LoadPackageMetadata(APackageDir, Metadata) then
    Exit;

  try
    // Get test script
    TestScript := GetTestScript(Metadata);
    if TestScript = '' then
    begin
      FLastError := 'No test script found in package.json';
      Exit;
    end;

    WriteLn('[INFO] Running test script: ', TestScript);

    // Execute test script using shell
    Process := TProcess.Create(nil);
    try
      Process.Executable := '/bin/sh';
      Process.Parameters.Add('-c');
      Process.Parameters.Add(TestScript);
      Process.CurrentDirectory := APackageDir;
      Process.Options := [poWaitOnExit, poUsePipes];

      try
        Process.Execute;

        // Read and display output
        OutputLines := TStringList.Create;
        try
          OutputLines.LoadFromStream(Process.Output);
          for Line in OutputLines do
            WriteLn(Line);
        finally
          OutputLines.Free;
        end;

        ExitCode := Process.ExitStatus;
        Result := (ExitCode = 0);

        if not Result then
          FLastError := Format('Test script failed with exit code %d', [ExitCode]);
      except
        on E: Exception do
        begin
          FLastError := 'Failed to execute test script: ' + E.Message;
          Result := False;
        end;
      end;
    finally
      Process.Free;
    end;
  finally
    Metadata.Free;
  end;
end;

function TPackageTestCommand.CleanupTempDir(const ATempDir: string): Boolean;

  procedure DeleteDirectory(const ADir: string);
  var
    SR: TSearchRec;
    FilePath: string;
  begin
    if FindFirst(ADir + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      try
        repeat
          if (SR.Name <> '.') and (SR.Name <> '..') then
          begin
            FilePath := ADir + PathDelim + SR.Name;
            if (SR.Attr and faDirectory) <> 0 then
              DeleteDirectory(FilePath)
            else
              DeleteFile(FilePath);
          end;
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;
    RemoveDir(ADir);
  end;

begin
  Result := False;
  FLastError := '';

  if not DirectoryExists(ATempDir) then
  begin
    FLastError := 'Directory does not exist: ' + ATempDir;
    Exit;
  end;

  try
    DeleteDirectory(ATempDir);
    Result := not DirectoryExists(ATempDir);

    if not Result then
      FLastError := 'Failed to delete directory: ' + ATempDir;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to cleanup directory: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TPackageTestCommand.GetLastError: string;
begin
  Result := FLastError;
end;

end.
