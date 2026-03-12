unit fpdev.fpc.verifier;

{$mode objfpc}{$H+}

{
  FPC Verifier
  
  This module handles FPC installation verification and smoke testing.
  It provides a clean interface for verifying FPC installations.
  Uses dependency injection for testability.
  
  NOTE: All shared types are in fpdev.fpc.types.pas
}

interface

uses
  SysUtils, Classes, fpdev.fpc.types, fpdev.fpc.version, fpdev.fpc.interfaces;

type
  { TFPCVerifier - Handles FPC installation verification }
  TFPCVerifier = class
  private
    FVersionManager: TFPCVersionManager;
    FFileSystem: IFileSystem;
    FProcessRunner: IProcessRunner;
    FOwnsInterfaces: Boolean;
    
    function RunSmokeTest(const AFPCExe: string; var VerifResult: TVerificationResult): Boolean;
    
  public
    { Creates a new verifier with default file system and process runner. }
    constructor Create(AVersionManager: TFPCVersionManager); overload;
    
    { Creates a new verifier with custom dependencies for testing. }
    constructor Create(AVersionManager: TFPCVersionManager;
      AFileSystem: IFileSystem; AProcessRunner: IProcessRunner); overload;
    destructor Destroy; override;
    
    { Performs comprehensive verification of an FPC installation. }
    function VerifyInstallation(const AVersion: string; out VerifResult: TVerificationResult): Boolean;
    
    { Simple verification check for an FPC installation. }
    function TestInstallation(const AVersion: string): Boolean;
    
    property VersionManager: TFPCVersionManager read FVersionManager;
    property FileSystem: IFileSystem read FFileSystem;
    property ProcessRunner: IProcessRunner read FProcessRunner;
  end;

implementation

uses fpdev.fpc.defaults;

{ TFPCVerifier }

constructor TFPCVerifier.Create(AVersionManager: TFPCVersionManager);
begin
  inherited Create;
  FVersionManager := AVersionManager;
  FFileSystem := TDefaultFileSystem.Create;
  FProcessRunner := TDefaultProcessRunner.Create;
  FOwnsInterfaces := True;
end;

constructor TFPCVerifier.Create(AVersionManager: TFPCVersionManager;
  AFileSystem: IFileSystem; AProcessRunner: IProcessRunner);
begin
  inherited Create;
  FVersionManager := AVersionManager;
  FFileSystem := AFileSystem;
  FProcessRunner := AProcessRunner;
  FOwnsInterfaces := False;
end;

destructor TFPCVerifier.Destroy;
begin
  FFileSystem := nil;
  FProcessRunner := nil;
  inherited Destroy;
end;

function TFPCVerifier.VerifyInstallation(const AVersion: string; out VerifResult: TVerificationResult): Boolean;
var
  FPCExe: string;
  ProcessResult: TProcessResult;
  DetectedVer: string;
begin
  FillChar(VerifResult, SizeOf(VerifResult), 0);
  VerifResult.Verified := False;
  VerifResult.ExecutableExists := False;
  VerifResult.DetectedVersion := '';
  VerifResult.SmokeTestPassed := False;
  VerifResult.ErrorMessage := '';

  FPCExe := FVersionManager.GetFPCExecutablePath(AVersion);

  // Use injected file system
  if not FFileSystem.FileExists(FPCExe) then
  begin
    VerifResult.ErrorMessage := 'FPC executable not found: ' + FPCExe;
    Exit(False);
  end;

  VerifResult.ExecutableExists := True;

  try
    // Use injected process runner
    ProcessResult := FProcessRunner.Execute(FPCExe, ['-iV']);
    
    if ProcessResult.ExitCode = 0 then
    begin
      DetectedVer := Trim(ProcessResult.StdOut);
      // Handle multi-line output - take first line
      if Pos(#10, DetectedVer) > 0 then
        DetectedVer := Copy(DetectedVer, 1, Pos(#10, DetectedVer) - 1);
      if Pos(#13, DetectedVer) > 0 then
        DetectedVer := Copy(DetectedVer, 1, Pos(#13, DetectedVer) - 1);
      
      VerifResult.DetectedVersion := DetectedVer;

      if not SameText(DetectedVer, AVersion) then
      begin
        VerifResult.ErrorMessage := 'Version mismatch: expected ' + AVersion + ', detected ' + DetectedVer;
        Exit(False);
      end;
    end
    else
    begin
      VerifResult.ErrorMessage := 'fpc -iV failed with exit code: ' + IntToStr(ProcessResult.ExitCode);
      Exit(False);
    end;

    if not RunSmokeTest(FPCExe, VerifResult) then
    begin
      VerifResult.Verified := False;
      Exit(False);
    end;

    VerifResult.Verified := True;
    Exit(True);

  except
    on E: Exception do
    begin
      VerifResult.ErrorMessage := 'Exception during verification: ' + E.Message;
      Exit(False);
    end;
  end;
end;

function TFPCVerifier.RunSmokeTest(const AFPCExe: string; var VerifResult: TVerificationResult): Boolean;
var
  TempDir, HelloPas, HelloExe: string;
  HelloContent: string;
  CompileResult, RunResult: TProcessResult;
  Output: string;
begin
  Result := False;
  VerifResult.SmokeTestPassed := False;

  try
    TempDir := FFileSystem.GetTempDir + 'fpdev_smoke_' + IntToStr(GetTickCount64);
    FFileSystem.ForceDirectories(TempDir);

    HelloPas := TempDir + PathDelim + 'hello.pas';
    {$IFDEF MSWINDOWS}
    HelloExe := TempDir + PathDelim + 'hello.exe';
    {$ELSE}
    HelloExe := TempDir + PathDelim + 'hello';
    {$ENDIF}

    // Create hello.pas using file system interface
    HelloContent := 'program hello;' + LineEnding +
                    'begin' + LineEnding +
                    '  WriteLn(''Hello, World!'');' + LineEnding +
                    'end.';
    FFileSystem.WriteAllText(HelloPas, HelloContent);

    // Compile using process runner
    CompileResult := FProcessRunner.Execute(AFPCExe, ['-o' + HelloExe, HelloPas]);
    
    if CompileResult.ExitCode <> 0 then
    begin
      VerifResult.ErrorMessage :=
        'Smoke test: Failed to compile hello.pas (exit code: ' +
        IntToStr(CompileResult.ExitCode) + ')';
      Exit(False);
    end;

    if not FFileSystem.FileExists(HelloExe) then
    begin
      VerifResult.ErrorMessage := 'Smoke test: Compiled executable not found: ' + HelloExe;
      Exit(False);
    end;

    // Run the compiled program
    RunResult := FProcessRunner.Execute(HelloExe, []);
    
    if RunResult.ExitCode <> 0 then
    begin
      VerifResult.ErrorMessage := 'Smoke test: hello program failed (exit code: ' + IntToStr(RunResult.ExitCode) + ')';
      Exit(False);
    end;

    Output := Trim(RunResult.StdOut);
    // Handle multi-line output
    if Pos(#10, Output) > 0 then
      Output := Copy(Output, 1, Pos(#10, Output) - 1);
    if Pos(#13, Output) > 0 then
      Output := Copy(Output, 1, Pos(#13, Output) - 1);

    if Output <> 'Hello, World!' then
    begin
      VerifResult.ErrorMessage := 'Smoke test: Unexpected output. Expected ''Hello, World!'', got: ''' + Output + '''';
      Exit(False);
    end;

    VerifResult.SmokeTestPassed := True;
    Result := True;

  except
    on E: Exception do
    begin
      VerifResult.ErrorMessage := 'Smoke test exception: ' + E.Message;
      Result := False;
    end;
  end;
  
  // Cleanup
  try
    if FFileSystem.FileExists(HelloPas) then FFileSystem.DeleteFile(HelloPas);
    if FFileSystem.FileExists(HelloExe) then FFileSystem.DeleteFile(HelloExe);
    if FFileSystem.DirectoryExists(TempDir) then FFileSystem.RemoveDir(TempDir);
  except
    // Ignore cleanup errors
  end;
end;

function TFPCVerifier.TestInstallation(const AVersion: string): Boolean;
var
  VerifResult: TVerificationResult;
begin
  Result := VerifyInstallation(AVersion, VerifResult);
end;

end.
