program test_errors_recovery;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, fpdev.errors, fpdev.errors.recovery, fpdev.utils;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

function CaptureErrorDisplay(AErr: TEnhancedError; AVerbose: Boolean = False): string;
var
  SavedOutput: Text;
  TempPath: string;
begin
  TempPath := GetTempFileName(GetTempDir(False), 'fpe');
  SavedOutput := Output;
  Assign(Output, TempPath);
  Rewrite(Output);
  try
    AErr.Verbose := AVerbose;
    AErr.Display;
    Flush(Output);
  finally
    Close(Output);
    Output := SavedOutput;
  end;

  Result := ReadAllTextIfExists(TempPath);
  DeleteFile(TempPath);
end;

procedure TestNetworkTimeoutError;
var
  Err: TEnhancedError;
begin
  WriteLn('Testing CreateNetworkTimeoutError...');

  Err := CreateNetworkTimeoutError('https://example.com/file.tar.gz', 30);
  try
    AssertTrue(Err.Code = ecNetworkTimeout, 'Error code should be ecNetworkTimeout');
    AssertTrue(Pos('30s', Err.Message) > 0, 'Message should contain timeout duration');
    AssertTrue(Pos('https://example.com', Err.ToString) > 0, 'Context should contain URL');
  finally
    Err.Free;
  end;
end;

procedure TestNetworkConnectionError;
var
  Err: TEnhancedError;
begin
  WriteLn('Testing CreateNetworkConnectionError...');

  Err := CreateNetworkConnectionError('https://example.com', 'DNS resolution failed');
  try
    AssertTrue(Err.Code = ecNetworkConnectionFailed, 'Error code should be ecNetworkConnectionFailed');
    AssertTrue(Pos('DNS resolution failed', Err.Message) > 0, 'Message should contain details');
  finally
    Err.Free;
  end;
end;

procedure TestFileNotFoundError;
var
  Err: TEnhancedError;
begin
  WriteLn('Testing CreateFileNotFoundError...');

  Err := CreateFileNotFoundError('/path/to/missing/file.txt');
  try
    AssertTrue(Err.Code = ecFileNotFound, 'Error code should be ecFileNotFound');
    AssertTrue(Pos('/path/to/missing/file.txt', Err.Message) > 0, 'Message should contain file path');
  finally
    Err.Free;
  end;
end;

procedure TestDirectoryNotFoundError;
var
  Err: TEnhancedError;
begin
  WriteLn('Testing CreateDirectoryNotFoundError...');

  Err := CreateDirectoryNotFoundError('/path/to/missing/dir');
  try
    AssertTrue(Err.Code = ecDirectoryNotFound, 'Error code should be ecDirectoryNotFound');
    AssertTrue(Pos('/path/to/missing/dir', Err.Message) > 0, 'Message should contain directory path');
  finally
    Err.Free;
  end;
end;

procedure TestPermissionDeniedError;
var
  Err: TEnhancedError;
begin
  WriteLn('Testing CreatePermissionDeniedError...');

  Err := CreatePermissionDeniedError('/etc/shadow', 'read');
  try
    AssertTrue(Err.Code = ecPermissionDenied, 'Error code should be ecPermissionDenied');
    AssertTrue(Pos('/etc/shadow', Err.Message) > 0, 'Message should contain path');
    AssertTrue(Pos('read', Err.Message) > 0, 'Message should contain operation');
  finally
    Err.Free;
  end;
end;

procedure TestInvalidVersionError;
var
  Err: TEnhancedError;
begin
  WriteLn('Testing CreateInvalidVersionError...');

  Err := CreateInvalidVersionError('3.x.y', 'major.minor.patch');
  try
    AssertTrue(Err.Code = ecInvalidVersion, 'Error code should be ecInvalidVersion');
    AssertTrue(Pos('3.x.y', Err.Message) > 0, 'Message should contain invalid version');
    AssertTrue(Pos('major.minor.patch', Err.Message) > 0, 'Message should contain expected format');
  finally
    Err.Free;
  end;
end;

procedure TestDependencyMissingError;
var
  Err: TEnhancedError;
begin
  WriteLn('Testing CreateDependencyMissingError...');

  Err := CreateDependencyMissingError('git', 'apt install git');
  try
    AssertTrue(Err.Code = ecDependencyMissing, 'Error code should be ecDependencyMissing');
    AssertTrue(Pos('git', Err.Message) > 0, 'Message should contain dependency name');
  finally
    Err.Free;
  end;
end;

procedure TestBuildFailedError;
var
  Err: TEnhancedError;
  DisplayText: string;
begin
  WriteLn('Testing CreateBuildFailedError...');

  Err := CreateBuildFailedError('compiler', '/var/log/build.log');
  try
    AssertTrue(Err.Code = ecBuildFailed, 'Error code should be ecBuildFailed');
    AssertTrue(Pos('compiler', Err.Message) > 0, 'Message should contain component name');
    AssertTrue(Pos('/var/log/build.log', Err.ToString) > 0, 'Context should contain log file');

    DisplayText := CaptureErrorDisplay(Err, True);
    AssertTrue(Pos('fpdev fpc clean', DisplayText) = 0,
      'Build recovery should not suggest the missing `fpdev fpc clean` command');
    AssertTrue(Pos('fpdev fpc install <version> --from-source', DisplayText) > 0,
      'Build recovery should suggest retrying with `--from-source`');
    AssertTrue(Pos('<data-root>/sources/fpc/fpc-<version>', DisplayText) > 0,
      'Build recovery should describe manual cleanup under the active data root');
  finally
    Err.Free;
  end;
end;

procedure TestInstallationFailedError;
var
  Err: TEnhancedError;
  DisplayText: string;
begin
  WriteLn('Testing CreateInstallationFailedError...');

  Err := CreateInstallationFailedError('FPC 3.2.2', 'insufficient disk space');
  try
    AssertTrue(Err.Code = ecInstallationFailed, 'Error code should be ecInstallationFailed');
    AssertTrue(Pos('FPC 3.2.2', Err.Message) > 0, 'Message should contain package name');
    AssertTrue(Pos('insufficient disk space', Err.Message) > 0, 'Message should contain reason');

    DisplayText := CaptureErrorDisplay(Err, True);
    AssertTrue(Pos('fpdev fpc clean', DisplayText) = 0,
      'Installation recovery should not suggest the missing `fpdev fpc clean` command');
    AssertTrue(Pos('fpdev fpc install <version> --from-source', DisplayText) > 0,
      'Installation recovery should suggest retrying with `--from-source`');
    AssertTrue(Pos('<data-root>/sources/fpc/fpc-<version>', DisplayText) > 0,
      'Installation recovery should describe manual cleanup under the active data root');
  finally
    Err.Free;
  end;
end;

procedure TestChecksumMismatchError;
var
  Err: TEnhancedError;
begin
  WriteLn('Testing CreateChecksumMismatchError...');

  Err := CreateChecksumMismatchError('file.tar.gz', 'abc123', 'def456');
  try
    AssertTrue(Err.Code = ecChecksumMismatch, 'Error code should be ecChecksumMismatch');
    AssertTrue(Pos('file.tar.gz', Err.Message) > 0, 'Message should contain file name');
    AssertTrue(Pos('abc123', Err.ToString) > 0, 'Context should contain expected checksum');
    AssertTrue(Pos('def456', Err.ToString) > 0, 'Context should contain actual checksum');
  finally
    Err.Free;
  end;
end;

procedure TestConfigurationError;
var
  Err: TEnhancedError;
begin
  WriteLn('Testing CreateConfigurationError...');

  Err := CreateConfigurationError('/etc/fpdev/config.json', 'invalid JSON syntax');
  try
    AssertTrue(Err.Code = ecConfigurationError, 'Error code should be ecConfigurationError');
    AssertTrue(Pos('invalid JSON syntax', Err.Message) > 0, 'Message should contain reason');
    AssertTrue(Pos('/etc/fpdev/config.json', Err.ToString) > 0, 'Context should contain config file');
  finally
    Err.Free;
  end;
end;

procedure TestDefaultSuggestionsRegistered;
var
  Registry: TErrorRegistry;
  Err: TEnhancedError;
  DisplayText: string;
begin
  WriteLn('Testing default suggestions are registered...');

  Registry := TErrorRegistry.Instance;

  // Test that default suggestions were registered in initialization
  Err := Registry.CreateError(ecNetworkTimeout, '');
  try
    AssertTrue(Err.Message <> '', 'Default message should be registered');
  finally
    Err.Free;
  end;

  Err := Registry.CreateError(ecPermissionDenied, '');
  try
    AssertTrue(Err.Message <> '', 'Default message should be registered');
  finally
    Err.Free;
  end;

  Err := Registry.CreateError(ecBuildFailed, '');
  try
    AssertTrue(Err.Message <> '', 'Default message should be registered');
    DisplayText := CaptureErrorDisplay(Err, True);
    AssertTrue(Pos('fpdev fpc clean', DisplayText) = 0,
      'Default build-failed recovery should not suggest the missing `fpdev fpc clean` command');
    AssertTrue(Pos('fpdev fpc install <version> --from-source', DisplayText) > 0,
      'Default build-failed recovery should point to a fresh source build');
  finally
    Err.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Running Error Recovery Tests');
  WriteLn('========================================');
  WriteLn;

  TestNetworkTimeoutError;
  TestNetworkConnectionError;
  TestFileNotFoundError;
  TestDirectoryNotFoundError;
  TestPermissionDeniedError;
  TestInvalidVersionError;
  TestDependencyMissingError;
  TestBuildFailedError;
  TestInstallationFailedError;
  TestChecksumMismatchError;
  TestConfigurationError;
  TestDefaultSuggestionsRegistered;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Test Results');
  WriteLn('========================================');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn;

  if TestsFailed > 0 then
  begin
    WriteLn('FAILED: ', TestsFailed, ' test(s) failed');
    Halt(1);
  end
  else
  begin
    WriteLn('SUCCESS: All tests passed');
    Halt(0);
  end;
end.
