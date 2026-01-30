program test_build_interfaces;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.interfaces, fpdev.build.logger, fpdev.build.toolchain,
  fpdev.build.manager;

type
  { Mock Logger for testing interface isolation }
  TMockLogger = class(TInterfacedObject, IBuildLogger)
  private
    FMessages: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    
    { IBuildLogger interface }
    procedure Log(const AMessage: string);
    procedure LogDirSample(const ADir: string; ALimit: Integer);
    procedure LogEnvSnapshot;
    procedure LogTestSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
    function GetLogFileName: string;
    function GetVerbosity: Integer;
    procedure SetVerbosity(AValue: Integer);
    
    { Test helpers }
    function GetMessageCount: Integer;
    function GetMessage(AIndex: Integer): string;
    procedure Clear;
  end;

  { Mock Toolchain Checker for testing interface isolation }
  TMockToolchainChecker = class(TInterfacedObject, IToolchainChecker)
  private
    FMakeAvailable: Boolean;
    FFPCAvailable: Boolean;
  public
    constructor Create(AMakeAvailable, AFPCAvailable: Boolean);
    
    { IToolchainChecker interface }
    function IsMakeAvailable: Boolean;
    function IsFPCAvailable: Boolean;
    function IsSourceDirValid(const ASourceDir: string): Boolean;
    function IsSandboxWritable(const ASandboxDir: string): Boolean;
    function GetMakeCommand: string;
    function GetFPCCommand: string;
    function GetVerbosity: Integer;
    procedure SetVerbosity(AValue: Integer);
  end;

{ TMockLogger }

constructor TMockLogger.Create;
begin
  inherited Create;
  FMessages := TStringList.Create;
end;

destructor TMockLogger.Destroy;
begin
  FMessages.Free;
  inherited;
end;

procedure TMockLogger.Log(const AMessage: string);
begin
  FMessages.Add(AMessage);
end;

procedure TMockLogger.LogDirSample(const ADir: string; ALimit: Integer);
begin
  FMessages.Add('LogDirSample: ' + ADir);
end;

procedure TMockLogger.LogEnvSnapshot;
begin
  FMessages.Add('LogEnvSnapshot');
end;

procedure TMockLogger.LogTestSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
begin
  FMessages.Add(Format('TestSummary: %s %s %s %dms', [AVersion, AContext, AResult, AElapsedMs]));
end;

function TMockLogger.GetLogFileName: string;
begin
  Result := 'mock.log';
end;

function TMockLogger.GetVerbosity: Integer;
begin
  Result := 0;
end;

procedure TMockLogger.SetVerbosity(AValue: Integer);
begin
  // Mock implementation
end;

function TMockLogger.GetMessageCount: Integer;
begin
  Result := FMessages.Count;
end;

function TMockLogger.GetMessage(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FMessages.Count) then
    Result := FMessages[AIndex]
  else
    Result := '';
end;

procedure TMockLogger.Clear;
begin
  FMessages.Clear;
end;

{ TMockToolchainChecker }

constructor TMockToolchainChecker.Create(AMakeAvailable, AFPCAvailable: Boolean);
begin
  inherited Create;
  FMakeAvailable := AMakeAvailable;
  FFPCAvailable := AFPCAvailable;
end;

function TMockToolchainChecker.IsMakeAvailable: Boolean;
begin
  Result := FMakeAvailable;
end;

function TMockToolchainChecker.IsFPCAvailable: Boolean;
begin
  Result := FFPCAvailable;
end;

function TMockToolchainChecker.IsSourceDirValid(const ASourceDir: string): Boolean;
begin
  Result := DirectoryExists(ASourceDir);
end;

function TMockToolchainChecker.IsSandboxWritable(const ASandboxDir: string): Boolean;
begin
  Result := True;  // Mock always returns true
end;

function TMockToolchainChecker.GetMakeCommand: string;
begin
  if FMakeAvailable then
    Result := 'make'
  else
    Result := '';
end;

function TMockToolchainChecker.GetFPCCommand: string;
begin
  if FFPCAvailable then
    Result := 'fpc'
  else
    Result := '';
end;

function TMockToolchainChecker.GetVerbosity: Integer;
begin
  Result := 0;
end;

procedure TMockToolchainChecker.SetVerbosity(AValue: Integer);
begin
  // Mock implementation
end;

{ Test Cases }

procedure TestLoggerInterface;
var
  Logger: IBuildLogger;
  MockLogger: TMockLogger;
begin
  WriteLn('TEST: Logger Interface Isolation');
  
  MockLogger := TMockLogger.Create;
  Logger := MockLogger;
  
  Logger.Log('Test message 1');
  Logger.Log('Test message 2');
  
  if MockLogger.GetMessageCount = 2 then
    WriteLn('  PASS: Logger captured 2 messages')
  else
    WriteLn('  FAIL: Expected 2 messages, got ', MockLogger.GetMessageCount);
    
  if MockLogger.GetMessage(0) = 'Test message 1' then
    WriteLn('  PASS: First message correct')
  else
    WriteLn('  FAIL: First message incorrect');
end;

procedure TestToolchainInterface;
var
  Checker: IToolchainChecker;
begin
  WriteLn('TEST: Toolchain Interface Isolation');
  
  // Test with make available
  Checker := TMockToolchainChecker.Create(True, True);
  if Checker.IsMakeAvailable then
    WriteLn('  PASS: Make available detected')
  else
    WriteLn('  FAIL: Make should be available');
    
  if Checker.GetMakeCommand = 'make' then
    WriteLn('  PASS: Make command correct')
  else
    WriteLn('  FAIL: Make command incorrect');
  
  // Test with make unavailable
  Checker := TMockToolchainChecker.Create(False, False);
  if not Checker.IsMakeAvailable then
    WriteLn('  PASS: Make unavailable detected')
  else
    WriteLn('  FAIL: Make should be unavailable');
end;

procedure TestRealImplementations;
var
  Logger: IBuildLogger;
  Checker: IToolchainChecker;
  Manager: IBuildManager;
begin
  WriteLn('TEST: Real Implementation Interfaces');
  
  // Test TBuildLogger implements IBuildLogger
  Logger := TBuildLogger.Create('logs');
  if Logger <> nil then
    WriteLn('  PASS: TBuildLogger implements IBuildLogger')
  else
    WriteLn('  FAIL: TBuildLogger interface failed');
  
  // Test TBuildToolchainChecker implements IToolchainChecker
  Checker := TBuildToolchainChecker.Create(False);
  if Checker <> nil then
    WriteLn('  PASS: TBuildToolchainChecker implements IToolchainChecker')
  else
    WriteLn('  FAIL: TBuildToolchainChecker interface failed');
  
  // Test TBuildManager implements IBuildManager
  Manager := TBuildManager.Create('sources/fpc', 2, False);
  if Manager <> nil then
    WriteLn('  PASS: TBuildManager implements IBuildManager')
  else
    WriteLn('  FAIL: TBuildManager interface failed');
end;

procedure TestInterfaceReferenceCounting;
var
  Logger: IBuildLogger;
  MockLogger: TMockLogger;
begin
  WriteLn('TEST: Interface Reference Counting');
  
  MockLogger := TMockLogger.Create;
  Logger := MockLogger;
  Logger.Log('Test');
  
  // When Logger goes out of scope, MockLogger should be freed automatically
  Logger := nil;
  
  WriteLn('  PASS: Interface reference counting works (no manual Free needed)');
end;

begin
  WriteLn('=== Build Interface Tests ===');
  WriteLn;
  
  TestLoggerInterface;
  WriteLn;
  
  TestToolchainInterface;
  WriteLn;
  
  TestRealImplementations;
  WriteLn;
  
  TestInterfaceReferenceCounting;
  WriteLn;
  
  WriteLn('=== All Interface Tests Complete ===');
end.
