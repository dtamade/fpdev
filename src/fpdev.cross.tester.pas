unit fpdev.cross.tester;

{$mode objfpc}{$H+}

{
  TCrossBuildTester - Cross-compilation testing service

  Extracted from fpdev.cmd.cross to handle:
  - Cross-compilation test execution
  - Test source file generation
  - FPC cross-compile parameter building
}

interface

uses
  SysUtils, Classes,
  fpdev.config.interfaces, fpdev.utils.process;

type
  { TCrossBuildTestResult - Result of cross-build test }
  TCrossBuildTestResult = record
    Success: Boolean;
    OutputFile: string;
    ErrorMessage: string;
    ExitCode: Integer;
  end;

  { TCrossBuildTester }
  TCrossBuildTester = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;

    function CreateTestSource(const ATargetPath: string): string;
    function FindFPCPath(const AToolchainPath, AVersion, ACPU: string): string;
    function BuildCrossParams(const ACPU, AOS, ABinutilsPath, ALibrariesPath,
      AOutputFile, ASourceFile: string): SysUtils.TStringArray;

  public
    constructor Create(AConfigManager: IConfigManager; const AInstallRoot: string);

    { Execute cross-compilation test }
    function ExecuteTest(const ATarget, ACPU, AOS: string;
      const ABinutilsPath, ALibrariesPath: string;
      const ASourceFile: string = ''): TCrossBuildTestResult;

    { Get target install path }
    function GetTargetInstallPath(const ATarget: string): string;
  end;

implementation

uses
  fpdev.i18n.strings;

{ TCrossBuildTester }

constructor TCrossBuildTester.Create(AConfigManager: IConfigManager; const AInstallRoot: string);
begin
  inherited Create;
  FConfigManager := AConfigManager;
  FInstallRoot := AInstallRoot;
end;

function TCrossBuildTester.GetTargetInstallPath(const ATarget: string): string;
begin
  Result := FInstallRoot + PathDelim + 'cross' + PathDelim + ATarget;
end;

function TCrossBuildTester.CreateTestSource(const ATargetPath: string): string;
var
  F: TextFile;
begin
  Result := ATargetPath + PathDelim + 'cross_test.pas';
  try
    AssignFile(F, Result);
    Rewrite(F);
    WriteLn(F, 'program cross_test;');
    WriteLn(F, 'begin');
    WriteLn(F, '  WriteLn(''Hello from cross-compiled program!'');');
    WriteLn(F, 'end.');
    CloseFile(F);
  except
    on E: Exception do
    begin
      Result := '';
    end;
  end;
end;

function TCrossBuildTester.FindFPCPath(const AToolchainPath, AVersion, ACPU: string): string;
begin
  // Try standard path first
  Result := AToolchainPath + PathDelim + 'bin' + PathDelim + 'fpc';
  {$IFDEF MSWINDOWS}
  Result := Result + '.exe';
  {$ENDIF}

  if FileExists(Result) then Exit;

  // Try alternative path
  Result := AToolchainPath + PathDelim + 'lib' + PathDelim + 'fpc' +
            PathDelim + AVersion + PathDelim + 'ppc' + LowerCase(ACPU);
  {$IFDEF MSWINDOWS}
  Result := Result + '.exe';
  {$ENDIF}

  if not FileExists(Result) then
    Result := '';
end;

function TCrossBuildTester.BuildCrossParams(const ACPU, AOS, ABinutilsPath,
  ALibrariesPath, AOutputFile, ASourceFile: string): SysUtils.TStringArray;
var
  ParamCount: Integer;
begin
  Result := nil;
  ParamCount := 0;

  // Target CPU
  SetLength(Result, ParamCount + 1);
  Result[ParamCount] := '-P' + ACPU;
  Inc(ParamCount);

  // Target OS
  SetLength(Result, ParamCount + 1);
  Result[ParamCount] := '-T' + AOS;
  Inc(ParamCount);

  // Binutils prefix path
  if (ABinutilsPath <> '') and DirectoryExists(ABinutilsPath) then
  begin
    SetLength(Result, ParamCount + 1);
    Result[ParamCount] := '-XP' + ABinutilsPath + PathDelim;
    Inc(ParamCount);
  end;

  // Libraries path
  if (ALibrariesPath <> '') and DirectoryExists(ALibrariesPath) then
  begin
    SetLength(Result, ParamCount + 1);
    Result[ParamCount] := '-Fl' + ALibrariesPath;
    Inc(ParamCount);
  end;

  // Output file
  SetLength(Result, ParamCount + 1);
  Result[ParamCount] := '-o' + AOutputFile;
  Inc(ParamCount);

  // Source file
  SetLength(Result, ParamCount + 1);
  Result[ParamCount] := ASourceFile;
end;

function TCrossBuildTester.ExecuteTest(const ATarget, ACPU, AOS: string;
  const ABinutilsPath, ALibrariesPath: string;
  const ASourceFile: string): TCrossBuildTestResult;
var
  TestSource, TestOutput: string;
  FPCPath: string;
  Params: SysUtils.TStringArray;
  LResult: TProcessResult;
  ToolchainMgr: IToolchainManager;
  DefaultToolchain: string;
  ToolchainInfo: TToolchainInfo;
  CreatedSource: Boolean;
  TargetPath: string;
begin
  // Initialize result
  Result.Success := False;
  Result.OutputFile := '';
  Result.ErrorMessage := '';
  Result.ExitCode := -1;

  if ATarget = '' then
  begin
    Result.ErrorMessage := 'Target not specified';
    Exit;
  end;

  TargetPath := GetTargetInstallPath(ATarget);

  // Create or use provided source file
  CreatedSource := False;
  if ASourceFile = '' then
  begin
    TestSource := CreateTestSource(TargetPath);
    if TestSource = '' then
    begin
      Result.ErrorMessage := 'Failed to create test source file';
      Exit;
    end;
    CreatedSource := True;
  end
  else
    TestSource := ASourceFile;

  // Determine output file name
  TestOutput := ChangeFileExt(TestSource, '');
  if (AOS = 'win32') or (AOS = 'win64') then
    TestOutput := TestOutput + '.exe';

  // Get FPC path from toolchain manager
  ToolchainMgr := FConfigManager.GetToolchainManager;
  DefaultToolchain := ToolchainMgr.GetDefaultToolchain;
  if DefaultToolchain = '' then
  begin
    Result.ErrorMessage := 'No FPC toolchain installed';
    if CreatedSource and FileExists(TestSource) then
      DeleteFile(TestSource);
    Exit;
  end;

  if not ToolchainMgr.GetToolchain(DefaultToolchain, ToolchainInfo) then
  begin
    Result.ErrorMessage := 'Failed to get FPC toolchain info';
    if CreatedSource and FileExists(TestSource) then
      DeleteFile(TestSource);
    Exit;
  end;

  FPCPath := FindFPCPath(ToolchainInfo.InstallPath, ToolchainInfo.Version, ACPU);
  if FPCPath = '' then
  begin
    Result.ErrorMessage := 'FPC compiler not found at ' + ToolchainInfo.InstallPath;
    if CreatedSource and FileExists(TestSource) then
      DeleteFile(TestSource);
    Exit;
  end;

  // Build parameters
  Params := BuildCrossParams(ACPU, AOS, ABinutilsPath, ALibrariesPath,
    TestOutput, TestSource);

  // Execute cross-compilation
  try
    LResult := TProcessExecutor.Execute(FPCPath, Params, '');
    Result.ExitCode := LResult.ExitCode;

    if LResult.Success then
    begin
      if FileExists(TestOutput) then
      begin
        Result.Success := True;
        Result.OutputFile := TestOutput;
      end
      else
      begin
        Result.ErrorMessage := 'Output file not created';
      end;
    end
    else
    begin
      Result.ErrorMessage := 'Compilation failed with exit code ' + IntToStr(LResult.ExitCode);
    end;
  except
    on E: Exception do
    begin
      Result.ErrorMessage := E.Message;
    end;
  end;

  // Clean up test source if we created it
  if CreatedSource and FileExists(TestSource) then
    DeleteFile(TestSource);
end;

end.
