unit fpdev.errors.recovery;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpdev.errors;

{ Network error recovery }
function CreateNetworkTimeoutError(const AURL: string; const ATimeout: Integer): TEnhancedError;
function CreateNetworkConnectionError(const AURL: string; const ADetails: string = ''): TEnhancedError;

{ File system error recovery }
function CreateFileNotFoundError(const AFilePath: string): TEnhancedError;
function CreateDirectoryNotFoundError(const ADirPath: string): TEnhancedError;
function CreatePermissionDeniedError(const APath: string; const AOperation: string = ''): TEnhancedError;

{ Version and dependency error recovery }
function CreateInvalidVersionError(const AVersion: string; const AExpectedFormat: string = ''): TEnhancedError;
function CreateDependencyMissingError(const ADependency: string; const AInstallCommand: string = ''): TEnhancedError;

{ Build and installation error recovery }
function CreateBuildFailedError(const AComponent: string; const ALogFile: string = ''): TEnhancedError;
function CreateInstallationFailedError(const APackage: string; const AReason: string = ''): TEnhancedError;
function CreateChecksumMismatchError(const AFile: string; const AExpected, AActual: string): TEnhancedError;

{ Configuration error recovery }
function CreateConfigurationError(const AConfigFile: string; const AReason: string): TEnhancedError;

{ Register default error suggestions }
procedure RegisterDefaultErrorSuggestions;

implementation

{ Network error recovery }

function CreateNetworkTimeoutError(const AURL: string; const ATimeout: Integer): TEnhancedError;
begin
  Result := NewError(ecNetworkTimeout, Format('Connection timed out after %ds', [ATimeout]));
  Result.AddContext('URL', AURL);
  Result.AddContext('Timeout', IntToStr(ATimeout) + 's');

  Result.AddSuggestion(
    'Check your internet connection',
    'ping 8.8.8.8',
    'Verify network connectivity'
  );

  Result.AddSuggestion(
    'Try a different mirror',
    'fpdev fpc install <version> --mirror gitlab',
    'Use alternative download source'
  );

  Result.AddSuggestion(
    'Install from cache (if available)',
    'fpdev fpc cache list' + LineEnding + 'fpdev fpc install <version> --offline',
    'Use cached version without network'
  );

  Result.AddSuggestion(
    'Install from source instead',
    'fpdev fpc install <version> --from-source',
    'Build from source repository'
  );
end;

function CreateNetworkConnectionError(const AURL: string; const ADetails: string): TEnhancedError;
var
  Msg: string;
begin
  if ADetails <> '' then
    Msg := 'Network connection failed: ' + ADetails
  else
    Msg := 'Network connection failed';

  Result := NewError(ecNetworkConnectionFailed, Msg);
  Result.AddContext('URL', AURL);

  Result.AddSuggestion(
    'Check your internet connection',
    'ping 8.8.8.8',
    'Verify network connectivity'
  );

  Result.AddSuggestion(
    'Check if URL is accessible',
    'curl -I ' + AURL,
    'Test URL accessibility'
  );

  Result.AddSuggestion(
    'Try using a VPN or proxy',
    '',
    'Some networks may block certain domains'
  );
end;

{ File system error recovery }

function CreateFileNotFoundError(const AFilePath: string): TEnhancedError;
begin
  Result := NewError(ecFileNotFound, 'File not found: ' + AFilePath);
  Result.AddContext('Path', AFilePath);

  Result.AddSuggestion(
    'Check if the file path is correct',
    'ls -la ' + ExtractFileDir(AFilePath),
    'List directory contents'
  );

  Result.AddSuggestion(
    'Check if the file was moved or deleted',
    '',
    'Verify file location'
  );

  Result.AddSuggestion(
    'Run fpdev system doctor to check installation',
    'fpdev system doctor',
    'Diagnose system configuration'
  );
end;

function CreateDirectoryNotFoundError(const ADirPath: string): TEnhancedError;
begin
  Result := NewError(ecDirectoryNotFound, 'Directory not found: ' + ADirPath);
  Result.AddContext('Path', ADirPath);

  Result.AddSuggestion(
    'Check if the directory path is correct',
    'ls -la ' + ExtractFileDir(ADirPath),
    'List parent directory contents'
  );

  Result.AddSuggestion(
    'Create the directory',
    'mkdir -p ' + ADirPath,
    'Create directory and parent directories'
  );
end;

function CreatePermissionDeniedError(const APath: string; const AOperation: string): TEnhancedError;
var
  Msg: string;
begin
  if AOperation <> '' then
    Msg := Format('Permission denied: %s (%s)', [APath, AOperation])
  else
    Msg := 'Permission denied: ' + APath;

  Result := NewError(ecPermissionDenied, Msg);
  Result.AddContext('Path', APath);
  if AOperation <> '' then
    Result.AddContext('Operation', AOperation);

  Result.AddSuggestion(
    'Check file permissions',
    'ls -la ' + APath,
    'View file permissions'
  );

  Result.AddSuggestion(
    'Run with appropriate permissions',
    'sudo fpdev <command>',
    'Use elevated privileges (use with caution)'
  );

  Result.AddSuggestion(
    'Change file ownership',
    'sudo chown $USER:$USER ' + APath,
    'Take ownership of the file'
  );
end;

{ Version and dependency error recovery }

function CreateInvalidVersionError(const AVersion: string; const AExpectedFormat: string): TEnhancedError;
var
  Msg: string;
begin
  if AExpectedFormat <> '' then
    Msg := Format('Invalid version format: %s (expected: %s)', [AVersion, AExpectedFormat])
  else
    Msg := 'Invalid version format: ' + AVersion;

  Result := NewError(ecInvalidVersion, Msg);
  Result.AddContext('Version', AVersion);
  if AExpectedFormat <> '' then
    Result.AddContext('Expected Format', AExpectedFormat);

  Result.AddSuggestion(
    'List available versions',
    'fpdev fpc list --remote',
    'View all available FPC versions'
  );

  Result.AddSuggestion(
    'Use semantic version format',
    'fpdev fpc install 3.2.2',
    'Example: major.minor.patch'
  );
end;

function CreateDependencyMissingError(const ADependency: string; const AInstallCommand: string): TEnhancedError;
begin
  Result := NewError(ecDependencyMissing, 'Required dependency missing: ' + ADependency);
  Result.AddContext('Dependency', ADependency);

  if AInstallCommand <> '' then
  begin
    Result.AddSuggestion(
      'Install the missing dependency',
      AInstallCommand,
      'Install required dependency'
    );
  end;

  Result.AddSuggestion(
    'Run system diagnostics',
    'fpdev system doctor',
    'Check all system dependencies'
  );

  Result.AddSuggestion(
    'Check system package manager',
    'apt search ' + ADependency + ' # or: yum search, brew search',
    'Search for dependency in system packages'
  );
end;

{ Build and installation error recovery }

function CreateBuildFailedError(const AComponent: string; const ALogFile: string): TEnhancedError;
begin
  Result := NewError(ecBuildFailed, 'Build failed: ' + AComponent);
  Result.AddContext('Component', AComponent);
  if ALogFile <> '' then
    Result.AddContext('Log File', ALogFile);

  if ALogFile <> '' then
  begin
    Result.AddSuggestion(
      'Check build log for details',
      'cat ' + ALogFile,
      'View complete build log'
    );
  end;

  Result.AddSuggestion(
    'Check for missing dependencies',
    'fpdev system doctor',
    'Verify all build dependencies are installed'
  );

  Result.AddSuggestion(
    'Try building from source',
    'fpdev fpc install <version> --from-source',
    'Build from source repository'
  );

  Result.AddSuggestion(
    'Retry with a fresh source build',
    'fpdev fpc install <version> --from-source',
    'If a stale source tree is causing the failure, manually delete <data-root>/sources/fpc/fpc-<version> before retrying.'
  );
end;

function CreateInstallationFailedError(const APackage: string; const AReason: string): TEnhancedError;
var
  Msg: string;
begin
  if AReason <> '' then
    Msg := Format('Installation failed: %s (%s)', [APackage, AReason])
  else
    Msg := 'Installation failed: ' + APackage;

  Result := NewError(ecInstallationFailed, Msg);
  Result.AddContext('Package', APackage);
  if AReason <> '' then
    Result.AddContext('Reason', AReason);

  Result.AddSuggestion(
    'Check available disk space',
    'df -h',
    'Verify sufficient disk space'
  );

  Result.AddSuggestion(
    'Try installing from cache',
    'fpdev fpc cache list' + LineEnding + 'fpdev fpc install <version> --offline',
    'Use cached version'
  );

  Result.AddSuggestion(
    'Retry after removing stale source artifacts',
    'fpdev fpc install <version> --from-source',
    'If a stale source tree is causing the failure, manually delete <data-root>/sources/fpc/fpc-<version> before retrying.'
  );
end;

function CreateChecksumMismatchError(const AFile: string; const AExpected, AActual: string): TEnhancedError;
begin
  Result := NewError(ecChecksumMismatch, 'Checksum verification failed: ' + AFile);
  Result.AddContext('File', AFile);
  Result.AddContext('Expected', AExpected);
  Result.AddContext('Actual', AActual);

  Result.AddSuggestion(
    'Re-download the file',
    'fpdev fpc install <version> --no-cache',
    'Force fresh download'
  );

  Result.AddSuggestion(
    'Check network connection',
    'ping 8.8.8.8',
    'Verify network stability'
  );

  Result.AddSuggestion(
    'Try a different mirror',
    'fpdev fpc install <version> --mirror gitlab',
    'Use alternative download source'
  );
end;

{ Configuration error recovery }

function CreateConfigurationError(const AConfigFile: string; const AReason: string): TEnhancedError;
begin
  Result := NewError(ecConfigurationError, 'Configuration error: ' + AReason);
  Result.AddContext('Config File', AConfigFile);
  Result.AddContext('Reason', AReason);

  Result.AddSuggestion(
    'Check configuration file syntax',
    'cat ' + AConfigFile,
    'View configuration file'
  );

  Result.AddSuggestion(
    'Reset to default configuration',
    'mv ' + AConfigFile + ' ' + AConfigFile + '.backup',
    'Backup current config so fpdev can recreate it on next run'
  );

  Result.AddSuggestion(
    'Validate configuration',
    'fpdev system config show',
    'Try loading configuration and inspect current values'
  );
end;

{ Register default error suggestions }

procedure RegisterDefaultErrorSuggestions;
var
  Registry: TErrorRegistry;
  Suggestions: TRecoverySuggestions;
begin
  Registry := TErrorRegistry.Instance;

  // Network timeout default suggestions
  SetLength(Suggestions, 2);
  Suggestions[0].Action := 'Check your internet connection';
  Suggestions[0].Command := 'ping 8.8.8.8';
  Suggestions[0].Description := 'Verify network connectivity';
  Suggestions[1].Action := 'Try a different mirror';
  Suggestions[1].Command := 'fpdev fpc install <version> --mirror gitlab';
  Suggestions[1].Description := 'Use alternative download source';
  Registry.RegisterError(ecNetworkTimeout, 'Network connection timeout', Suggestions);

  // Permission denied default suggestions
  SetLength(Suggestions, 2);
  Suggestions[0].Action := 'Check file permissions';
  Suggestions[0].Command := 'ls -la <path>';
  Suggestions[0].Description := 'View file permissions';
  Suggestions[1].Action := 'Run with appropriate permissions';
  Suggestions[1].Command := 'sudo fpdev <command>';
  Suggestions[1].Description := 'Use elevated privileges (use with caution)';
  Registry.RegisterError(ecPermissionDenied, 'Permission denied', Suggestions);

  // Build failed default suggestions
  SetLength(Suggestions, 2);
  Suggestions[0].Action := 'Check for missing dependencies';
  Suggestions[0].Command := 'fpdev system doctor';
  Suggestions[0].Description := 'Verify all build dependencies are installed';
  Suggestions[1].Action := 'Retry with a fresh source build';
  Suggestions[1].Command := 'fpdev fpc install <version> --from-source';
  Suggestions[1].Description := 'If a stale source tree is causing the failure, manually delete <data-root>/sources/fpc/fpc-<version> before retrying.';
  Registry.RegisterError(ecBuildFailed, 'Build failed', Suggestions);
end;

initialization
  RegisterDefaultErrorSuggestions;

end.
