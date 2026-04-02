program test_fpc_metadata;

{$mode objfpc}{$H+}

{
  Unit tests for fpdev.fpc.metadata helper

  Tests:
  - WriteFPCMetadata: Write metadata to JSON file
  - ReadFPCMetadata: Read metadata from JSON file
  - HasFPCMetadata: Check if metadata file exists
  - GetMetadataPath: Get metadata file path
  - Round-trip: Write then read preserves data
}

uses
  SysUtils, Classes, fpdev.types, fpdev.fpc.types, fpdev.fpc.metadata,
  test_temp_paths;

var
  TestDir: string;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure SetupTestDir;
begin
  TestDir := CreateUniqueTempDir('test_fpc_metadata');
  WriteLn('[Setup] Created test directory: ', TestDir);
end;

procedure CleanupTestDir;
begin
  if TestDir <> '' then
  begin
    CleanupTempDir(TestDir);
    WriteLn('[Teardown] Deleted test directory: ', TestDir);
    TestDir := '';
  end;
end;

procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('  FAILED: ', AMessage);
    Inc(TestsFailed);
  end
  else
  begin
    WriteLn('  PASSED: ', AMessage);
    Inc(TestsPassed);
  end;
end;

procedure AssertEquals(const AExpected, AActual, AMessage: string);
begin
  if AExpected <> AActual then
  begin
    WriteLn('  FAILED: ', AMessage, ' (expected "', AExpected, '", got "', AActual, '")');
    Inc(TestsFailed);
  end
  else
  begin
    WriteLn('  PASSED: ', AMessage);
    Inc(TestsPassed);
  end;
end;

procedure TestGetMetadataPath;
begin
  WriteLn;
  WriteLn('=== TestGetMetadataPath ===');
  AssertEquals(TestDir + PathDelim + '.fpdev-meta.json',
    GetMetadataPath(TestDir), 'GetMetadataPath returns correct path');
end;

procedure TestHasMetadata_NotExists;
begin
  WriteLn;
  WriteLn('=== TestHasMetadata_NotExists ===');
  AssertTrue(not HasFPCMetadata(TestDir), 'HasFPCMetadata returns False for non-existent');
end;

procedure TestWriteMetadata;
var
  Meta: TFPDevMetadata;
begin
  WriteLn;
  WriteLn('=== TestWriteMetadata ===');

  // Setup metadata
  FillChar(Meta, SizeOf(Meta), 0);
  Meta.Version := '3.2.2';
  Meta.Scope := isUser;
  Meta.SourceMode := smBinary;
  Meta.Channel := 'stable';
  Meta.Prefix := '';
  Meta.Verify.Timestamp := EncodeDate(2026, 3, 19) + EncodeTime(10, 11, 12, 0);
  Meta.Verify.OK := True;
  Meta.Verify.DetectedVersion := '3.2.2';
  Meta.Verify.SmokeTestPassed := True;
  Meta.Origin.RepoURL := '';
  Meta.Origin.Commit := '';
  Meta.Origin.BuiltFromSource := False;
  Meta.InstalledAt := EncodeDate(2026, 3, 18) + EncodeTime(8, 9, 10, 0);

  AssertTrue(WriteFPCMetadata(TestDir, Meta), 'WriteFPCMetadata succeeds');
  AssertTrue(FileExists(GetMetadataPath(TestDir)), 'Metadata file created');
end;

procedure TestHasMetadata_Exists;
begin
  WriteLn;
  WriteLn('=== TestHasMetadata_Exists ===');
  AssertTrue(HasFPCMetadata(TestDir), 'HasFPCMetadata returns True after write');
end;

procedure TestReadMetadata;
var
  Meta: TFPDevMetadata;
begin
  WriteLn;
  WriteLn('=== TestReadMetadata ===');

  AssertTrue(ReadFPCMetadata(TestDir, Meta), 'ReadFPCMetadata succeeds');
  AssertEquals('3.2.2', Meta.Version, 'Version matches');
  AssertTrue(Meta.Scope = isUser, 'Scope is isUser');
  AssertTrue(Meta.SourceMode = smBinary, 'SourceMode is smBinary');
  AssertEquals('stable', Meta.Channel, 'Channel matches');
  AssertTrue(Meta.Verify.OK, 'Verify.OK is True');
  AssertEquals('3.2.2', Meta.Verify.DetectedVersion, 'DetectedVersion matches');
  AssertTrue(Meta.Verify.SmokeTestPassed, 'SmokeTestPassed is True');
  AssertTrue(Abs(Meta.Verify.Timestamp - (EncodeDate(2026, 3, 19) + EncodeTime(10, 11, 12, 0))) < 1 / SecsPerDay,
    'Verify.Timestamp preserved');
  AssertTrue(not Meta.Origin.BuiltFromSource, 'BuiltFromSource is False');
  AssertTrue(Abs(Meta.InstalledAt - (EncodeDate(2026, 3, 18) + EncodeTime(8, 9, 10, 0))) < 1 / SecsPerDay,
    'InstalledAt preserved');
end;

procedure TestRoundTrip_AllScopes;
var
  Meta, ReadMeta: TFPDevMetadata;
  Scope: TInstallScope;
  ScopeNames: array[TInstallScope] of string = ('isUser', 'isProject', 'isSystem');
  SubDir: string;
begin
  WriteLn;
  WriteLn('=== TestRoundTrip_AllScopes ===');

  for Scope := Low(TInstallScope) to High(TInstallScope) do
  begin
    SubDir := TestDir + PathDelim + ScopeNames[Scope];
    ForceDirectories(SubDir);

    FillChar(Meta, SizeOf(Meta), 0);
    Meta.Version := '3.2.2';
    Meta.Scope := Scope;
    Meta.SourceMode := smAuto;

    AssertTrue(WriteFPCMetadata(SubDir, Meta), 'Write ' + ScopeNames[Scope]);
    AssertTrue(ReadFPCMetadata(SubDir, ReadMeta), 'Read ' + ScopeNames[Scope]);
    AssertTrue(ReadMeta.Scope = Scope, 'Scope preserved for ' + ScopeNames[Scope]);
  end;
end;

procedure TestRoundTrip_AllSourceModes;
var
  Meta, ReadMeta: TFPDevMetadata;
  Mode: TSourceMode;
  ModeNames: array[TSourceMode] of string = ('smAuto', 'smBinary', 'smSource');
  SubDir: string;
begin
  WriteLn;
  WriteLn('=== TestRoundTrip_AllSourceModes ===');

  for Mode := Low(TSourceMode) to High(TSourceMode) do
  begin
    SubDir := TestDir + PathDelim + ModeNames[Mode];
    ForceDirectories(SubDir);

    FillChar(Meta, SizeOf(Meta), 0);
    Meta.Version := '3.2.2';
    Meta.Scope := isUser;
    Meta.SourceMode := Mode;

    AssertTrue(WriteFPCMetadata(SubDir, Meta), 'Write ' + ModeNames[Mode]);
    AssertTrue(ReadFPCMetadata(SubDir, ReadMeta), 'Read ' + ModeNames[Mode]);
    AssertTrue(ReadMeta.SourceMode = Mode, 'SourceMode preserved for ' + ModeNames[Mode]);
  end;
end;

procedure TestReadMetadata_NonExistent;
var
  Meta: TFPDevMetadata;
  NonExistentDir: string;
begin
  WriteLn;
  WriteLn('=== TestReadMetadata_NonExistent ===');
  NonExistentDir := TestDir + PathDelim + 'nonexistent';
  AssertTrue(not ReadFPCMetadata(NonExistentDir, Meta), 'ReadFPCMetadata returns False for non-existent dir');
end;

begin
  WriteLn('========================================');
  WriteLn('  FPC Metadata Helper Unit Tests');
  WriteLn('========================================');

  SetupTestDir;
  try
    TestGetMetadataPath;
    TestHasMetadata_NotExists;
    TestWriteMetadata;
    TestHasMetadata_Exists;
    TestReadMetadata;
    TestRoundTrip_AllScopes;
    TestRoundTrip_AllSourceModes;
    TestReadMetadata_NonExistent;

    WriteLn;
    WriteLn('========================================');
    WriteLn('  Test Summary');
    WriteLn('========================================');
    WriteLn('  Passed: ', TestsPassed);
    WriteLn('  Failed: ', TestsFailed);
    WriteLn('  Total:  ', TestsPassed + TestsFailed);

    if TestsFailed > 0 then
      ExitCode := 1
    else
      WriteLn('  ALL TESTS PASSED');
  finally
    CleanupTestDir;
  end;
end.
