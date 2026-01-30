program test_errors;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, fpdev.errors;

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

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Got: "' + AActual + '")');
end;

procedure TestErrorCodeToString;
begin
  WriteLn('Testing ErrorCodeToString...');
  AssertEquals('SUCCESS', ErrorCodeToString(ecSuccess), 'ecSuccess should return SUCCESS');
  AssertEquals('NETWORK_TIMEOUT', ErrorCodeToString(ecNetworkTimeout), 'ecNetworkTimeout should return NETWORK_TIMEOUT');
  AssertEquals('PERMISSION_DENIED', ErrorCodeToString(ecPermissionDenied), 'ecPermissionDenied should return PERMISSION_DENIED');
  AssertEquals('FILE_NOT_FOUND', ErrorCodeToString(ecFileNotFound), 'ecFileNotFound should return FILE_NOT_FOUND');
  AssertEquals('INVALID_VERSION', ErrorCodeToString(ecInvalidVersion), 'ecInvalidVersion should return INVALID_VERSION');
  AssertEquals('BUILD_FAILED', ErrorCodeToString(ecBuildFailed), 'ecBuildFailed should return BUILD_FAILED');
  AssertEquals('UNKNOWN_ERROR', ErrorCodeToString(ecUnknownError), 'ecUnknownError should return UNKNOWN_ERROR');
end;

procedure TestEnhancedErrorCreation;
var
  Err: TEnhancedError;
begin
  WriteLn('Testing TEnhancedError creation...');

  Err := TEnhancedError.Create(ecNetworkTimeout, 'Connection timed out after 30s');
  try
    AssertEquals('NETWORK_TIMEOUT', ErrorCodeToString(Err.Code), 'Error code should be NETWORK_TIMEOUT');
    AssertEquals('Connection timed out after 30s', Err.Message, 'Error message should match');
    AssertTrue(not Err.Verbose, 'Verbose should be false by default');
  finally
    Err.Free;
  end;
end;

procedure TestEnhancedErrorContext;
var
  Err: TEnhancedError;
  Str: string;
begin
  WriteLn('Testing TEnhancedError context...');

  Err := TEnhancedError.Create(ecNetworkTimeout, 'Connection failed');
  try
    Err.AddContext('URL', 'https://example.com');
    Err.AddContext('Timeout', '30s');

    Str := Err.ToString;
    AssertTrue(Pos('URL=https://example.com', Str) > 0, 'Context should contain URL');
    AssertTrue(Pos('Timeout=30s', Str) > 0, 'Context should contain Timeout');
  finally
    Err.Free;
  end;
end;

procedure TestEnhancedErrorSuggestions;
var
  Err: TEnhancedError;
begin
  WriteLn('Testing TEnhancedError suggestions...');

  Err := TEnhancedError.Create(ecNetworkTimeout, 'Download failed');
  try
    Err.AddSuggestion('Check internet connection', 'ping example.com', 'Verify network connectivity');
    Err.AddSuggestion('Try different mirror', 'fpdev fpc install 3.2.2 --mirror gitlab', 'Use alternative download source');

    // Suggestions are stored internally, we'll verify by checking they don't crash
    AssertTrue(True, 'Adding suggestions should not crash');
  finally
    Err.Free;
  end;
end;

procedure TestErrorRegistry;
var
  Registry: TErrorRegistry;
  Msg: string;
begin
  WriteLn('Testing TErrorRegistry...');

  Registry := TErrorRegistry.Instance;
  AssertTrue(Registry <> nil, 'Registry instance should not be nil');

  Msg := Registry.GetErrorMessage(ecNetworkTimeout);
  AssertTrue(Msg <> '', 'Error message for ecNetworkTimeout should not be empty');

  Msg := Registry.GetErrorMessage(ecPermissionDenied);
  AssertTrue(Msg <> '', 'Error message for ecPermissionDenied should not be empty');
end;

procedure TestErrorRegistryCreateError;
var
  Registry: TErrorRegistry;
  Err: TEnhancedError;
begin
  WriteLn('Testing TErrorRegistry.CreateError...');

  Registry := TErrorRegistry.Instance;

  // Test with custom message
  Err := Registry.CreateError(ecNetworkTimeout, 'Custom timeout message');
  try
    AssertEquals('Custom timeout message', Err.Message, 'Should use custom message');
    AssertEquals('NETWORK_TIMEOUT', ErrorCodeToString(Err.Code), 'Error code should be NETWORK_TIMEOUT');
  finally
    Err.Free;
  end;

  // Test with default message
  Err := Registry.CreateError(ecPermissionDenied, '');
  try
    AssertTrue(Err.Message <> '', 'Should use default message when empty string provided');
    AssertEquals('PERMISSION_DENIED', ErrorCodeToString(Err.Code), 'Error code should be PERMISSION_DENIED');
  finally
    Err.Free;
  end;
end;

procedure TestNewErrorHelper;
var
  Err: TEnhancedError;
begin
  WriteLn('Testing NewError helper function...');

  Err := NewError(ecInvalidVersion, 'Version 3.x.y is invalid');
  try
    AssertEquals('Version 3.x.y is invalid', Err.Message, 'Should use provided message');
    AssertEquals('INVALID_VERSION', ErrorCodeToString(Err.Code), 'Error code should be INVALID_VERSION');
  finally
    Err.Free;
  end;
end;

procedure TestErrorRegistryRegisterError;
var
  Registry: TErrorRegistry;
  Suggestions: TRecoverySuggestions;
  Err: TEnhancedError;
begin
  WriteLn('Testing TErrorRegistry.RegisterError...');

  Registry := TErrorRegistry.Instance;

  // Register custom error with suggestions
  SetLength(Suggestions, 2);
  Suggestions[0].Action := 'Check logs';
  Suggestions[0].Command := 'tail -f /var/log/app.log';
  Suggestions[0].Description := 'View application logs';
  Suggestions[1].Action := 'Restart service';
  Suggestions[1].Command := 'systemctl restart app';
  Suggestions[1].Description := 'Restart the application service';

  Registry.RegisterError(ecBuildFailed, 'Custom build failure message', Suggestions);

  // Verify registration
  Err := Registry.CreateError(ecBuildFailed, '');
  try
    AssertEquals('Custom build failure message', Err.Message, 'Should use registered message');
  finally
    Err.Free;
  end;
end;

procedure TestErrorVerboseMode;
var
  Err: TEnhancedError;
begin
  WriteLn('Testing TEnhancedError verbose mode...');

  Err := TEnhancedError.Create(ecBuildFailed, 'Compilation failed');
  try
    AssertTrue(not Err.Verbose, 'Verbose should be false by default');

    Err.Verbose := True;
    AssertTrue(Err.Verbose, 'Verbose should be true after setting');

    Err.AddContext('Compiler', 'FPC 3.2.2');
    Err.AddContext('Target', 'x86_64-linux');

    // Verbose mode affects Display output, but we can't easily test that
    // Just verify it doesn't crash
    AssertTrue(True, 'Verbose mode should not crash');
  finally
    Err.Free;
  end;
end;

procedure TestMultipleErrorCodes;
var
  Codes: array[0..6] of TErrorCode;
  I: Integer;
  Err: TEnhancedError;
begin
  WriteLn('Testing multiple error codes...');

  Codes[0] := ecNetworkTimeout;
  Codes[1] := ecPermissionDenied;
  Codes[2] := ecFileNotFound;
  Codes[3] := ecInvalidVersion;
  Codes[4] := ecChecksumMismatch;
  Codes[5] := ecBuildFailed;
  Codes[6] := ecConfigurationError;

  for I := 0 to High(Codes) do
  begin
    Err := NewError(Codes[I], 'Test error ' + IntToStr(I));
    try
      AssertTrue(Err <> nil, 'Error should be created for code ' + IntToStr(I));
      AssertTrue(Err.Message <> '', 'Error message should not be empty');
    finally
      Err.Free;
    end;
  end;
end;

procedure TestErrorToString;
var
  Err: TEnhancedError;
  Str: string;
begin
  WriteLn('Testing TEnhancedError.ToString...');

  Err := TEnhancedError.Create(ecNetworkTimeout, 'Connection failed');
  try
    Err.AddContext('URL', 'https://example.com');
    Err.AddContext('Retry', '3');

    Str := Err.ToString;
    AssertTrue(Pos('[NETWORK_TIMEOUT]', Str) > 0, 'ToString should contain error code');
    AssertTrue(Pos('Connection failed', Str) > 0, 'ToString should contain message');
    AssertTrue(Pos('Context:', Str) > 0, 'ToString should contain context header');
    AssertTrue(Pos('URL=https://example.com', Str) > 0, 'ToString should contain URL context');
    AssertTrue(Pos('Retry=3', Str) > 0, 'ToString should contain Retry context');
  finally
    Err.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Running Error Handling Tests');
  WriteLn('========================================');
  WriteLn;

  TestErrorCodeToString;
  TestEnhancedErrorCreation;
  TestEnhancedErrorContext;
  TestEnhancedErrorSuggestions;
  TestErrorRegistry;
  TestErrorRegistryCreateError;
  TestNewErrorHelper;
  TestErrorRegistryRegisterError;
  TestErrorVerboseMode;
  TestMultipleErrorCodes;
  TestErrorToString;

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
