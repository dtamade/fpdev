unit fpdev.errors;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  { Error codes for fpdev operations }
  TErrorCode = (
    ecSuccess,
    ecNetworkTimeout,
    ecNetworkConnectionFailed,
    ecPermissionDenied,
    ecFileNotFound,
    ecDirectoryNotFound,
    ecDependencyMissing,
    ecInvalidVersion,
    ecInvalidInput,
    ecChecksumMismatch,
    ecBuildFailed,
    ecInstallationFailed,
    ecConfigurationError,
    ecUnknownError
  );

  { Error registry interface (future-facing).
    Note: Current codebase primarily uses the concrete singleton `TErrorRegistry.Instance`. }
  IErrorRegistry = interface
    ['{4C0B38F7-9E20-4E9B-8C0D-FA5E58F9E2D1}']
    procedure RegisterError(ACode: Integer; const AMessage: string);
    function CreateError(ACode: Integer; const AMessage: string = ''): TObject;
    function GetErrorMessage(ACode: Integer): string;
  end;

  { Recovery suggestion for an error }
  TRecoverySuggestion = record
    Action: string;        // Human-readable action description
    Command: string;       // Executable command (if applicable)
    Description: string;   // Detailed explanation
  end;

  { Array of recovery suggestions }
  TRecoverySuggestions = array of TRecoverySuggestion;

  { Enhanced error with context and recovery suggestions }
  TEnhancedError = class
  private
    FCode: TErrorCode;
    FMessage: string;
    FContext: TStringList;
    FSuggestions: TRecoverySuggestions;
    FVerbose: Boolean;
  public
    constructor Create(ACode: TErrorCode; const AMessage: string);
    destructor Destroy; override;

    { Add context information }
    procedure AddContext(const AKey, AValue: string);

    { Add recovery suggestion }
    procedure AddSuggestion(const AAction, ACommand, ADescription: string);

    { Display error with formatting }
    procedure Display;

    { Get error as string (for logging) }
    function ToString: string; override;

    property Code: TErrorCode read FCode;
    property Message: string read FMessage;
    property Verbose: Boolean read FVerbose write FVerbose;
  end;

  { Error registry for managing error codes and default suggestions }
  TErrorRegistry = class
  private
    class var FInstance: TErrorRegistry;
    FErrorMessages: array[TErrorCode] of string;
    FDefaultSuggestions: array[TErrorCode] of TRecoverySuggestions;
  public
    constructor Create;

    { Singleton accessor }
    class function Instance: TErrorRegistry; static;

    { Primary API (used by tests and recovery helpers) }
    procedure RegisterError(ACode: TErrorCode; const AMessage: string; const ASuggestions: TRecoverySuggestions); overload;
    function CreateError(ACode: TErrorCode; const AMessage: string = ''): TEnhancedError; overload;
    function GetErrorMessage(ACode: TErrorCode): string; overload;

    { IErrorRegistry-compatible API }
    procedure RegisterError(ACode: Integer; const AMessage: string); overload;
    function CreateError(ACode: Integer; const AMessage: string = ''): TObject; overload;
    function GetErrorMessage(ACode: Integer): string; overload;

    { Legacy methods for backward compatibility }
    procedure RegisterErrorWithSuggestions(ACode: TErrorCode; const AMessage: string;
      const ASuggestions: TRecoverySuggestions);
    function CreateEnhancedError(ACode: TErrorCode; const AMessage: string = ''): TEnhancedError;
    function GetErrorMessageByCode(ACode: TErrorCode): string;
  end;

{ Helper function to create enhanced error }
function NewError(ACode: TErrorCode; const AMessage: string = ''): TEnhancedError;

{ Helper function to get error code name }
function ErrorCodeToString(ACode: TErrorCode): string;

implementation

{ TEnhancedError }

constructor TEnhancedError.Create(ACode: TErrorCode; const AMessage: string);
begin
  inherited Create;
  FCode := ACode;
  FMessage := AMessage;
  FContext := TStringList.Create;
  SetLength(FSuggestions, 0);
  FVerbose := False;
end;

destructor TEnhancedError.Destroy;
begin
  FContext.Free;
  inherited Destroy;
end;

procedure TEnhancedError.AddContext(const AKey, AValue: string);
begin
  FContext.Add(AKey + '=' + AValue);
end;

procedure TEnhancedError.AddSuggestion(const AAction, ACommand, ADescription: string);
var
  Idx: Integer;
begin
  Idx := Length(FSuggestions);
  SetLength(FSuggestions, Idx + 1);
  FSuggestions[Idx].Action := AAction;
  FSuggestions[Idx].Command := ACommand;
  FSuggestions[Idx].Description := ADescription;
end;

procedure TEnhancedError.Display;
var
  I: Integer;
  Suggestion: TRecoverySuggestion;
begin
  // Display error header
  WriteLn('[ERROR] Failed: ' + FMessage);
  WriteLn;

  // Display error code
  WriteLn('Error Code: ', ErrorCodeToString(FCode));

  // Display context if verbose mode
  if FVerbose and (FContext.Count > 0) then
  begin
    WriteLn;
    WriteLn('Context:');
    for I := 0 to FContext.Count - 1 do
      WriteLn('  ', FContext[I]);
  end;

  // Display recovery suggestions
  if Length(FSuggestions) > 0 then
  begin
    WriteLn;
    WriteLn('Possible solutions:');
    for I := 0 to High(FSuggestions) do
    begin
      Suggestion := FSuggestions[I];
      WriteLn('  ', I + 1, '. ', Suggestion.Action);
      if Suggestion.Command <> '' then
        WriteLn('     -> ', Suggestion.Command);
      if FVerbose and (Suggestion.Description <> '') then
        WriteLn('     ', Suggestion.Description);
    end;
  end;

  // Display help footer
  WriteLn;
  WriteLn('Need more help?');
  WriteLn('  • fpdev doctor          - Run system diagnostics');
  WriteLn('  • fpdev help            - View all commands');
end;

function TEnhancedError.ToString: string;
var
  I: Integer;
begin
  Result := Format('[%s] %s', [ErrorCodeToString(FCode), FMessage]);
  if FContext.Count > 0 then
  begin
    Result := Result + LineEnding + 'Context:';
    for I := 0 to FContext.Count - 1 do
      Result := Result + LineEnding + '  ' + FContext[I];
  end;
end;

{ TErrorRegistry }

constructor TErrorRegistry.Create;
begin
  inherited Create;
  // Initialize default error messages
  FErrorMessages[ecSuccess] := 'Operation completed successfully';
  FErrorMessages[ecNetworkTimeout] := 'Network connection timeout';
  FErrorMessages[ecNetworkConnectionFailed] := 'Network connection failed';
  FErrorMessages[ecPermissionDenied] := 'Permission denied';
  FErrorMessages[ecFileNotFound] := 'File not found';
  FErrorMessages[ecDirectoryNotFound] := 'Directory not found';
  FErrorMessages[ecDependencyMissing] := 'Required dependency missing';
  FErrorMessages[ecInvalidVersion] := 'Invalid version format';
  FErrorMessages[ecInvalidInput] := 'Invalid input';
  FErrorMessages[ecChecksumMismatch] := 'Checksum verification failed';
  FErrorMessages[ecBuildFailed] := 'Build failed';
  FErrorMessages[ecInstallationFailed] := 'Installation failed';
  FErrorMessages[ecConfigurationError] := 'Configuration error';
  FErrorMessages[ecUnknownError] := 'Unknown error';
  end;

class function TErrorRegistry.Instance: TErrorRegistry;
begin
  if FInstance = nil then
    FInstance := TErrorRegistry.Create;
  Result := FInstance;
end;

{ Primary API }

procedure TErrorRegistry.RegisterError(ACode: TErrorCode; const AMessage: string;
  const ASuggestions: TRecoverySuggestions);
begin
  RegisterErrorWithSuggestions(ACode, AMessage, ASuggestions);
end;

function TErrorRegistry.CreateError(ACode: TErrorCode; const AMessage: string): TEnhancedError;
begin
  Result := CreateEnhancedError(ACode, AMessage);
end;

function TErrorRegistry.GetErrorMessage(ACode: TErrorCode): string;
begin
  Result := GetErrorMessageByCode(ACode);
end;

{ IErrorRegistry-compatible API }

procedure TErrorRegistry.RegisterError(ACode: Integer; const AMessage: string);
begin
  if (ACode >= Ord(Low(TErrorCode))) and (ACode <= Ord(High(TErrorCode))) then
    FErrorMessages[TErrorCode(ACode)] := AMessage;
end;

function TErrorRegistry.CreateError(ACode: Integer; const AMessage: string): TObject;
begin
  if (ACode >= Ord(Low(TErrorCode))) and (ACode <= Ord(High(TErrorCode))) then
    Result := CreateEnhancedError(TErrorCode(ACode), AMessage)
  else
    Result := nil;
end;

function TErrorRegistry.GetErrorMessage(ACode: Integer): string;
begin
  if (ACode >= Ord(Low(TErrorCode))) and (ACode <= Ord(High(TErrorCode))) then
    Result := FErrorMessages[TErrorCode(ACode)]
  else
    Result := '';
end;

{ Legacy methods for backward compatibility }

procedure TErrorRegistry.RegisterErrorWithSuggestions(ACode: TErrorCode; const AMessage: string;
  const ASuggestions: TRecoverySuggestions);
begin
  FErrorMessages[ACode] := AMessage;
  FDefaultSuggestions[ACode] := ASuggestions;
end;

function TErrorRegistry.CreateEnhancedError(ACode: TErrorCode; const AMessage: string): TEnhancedError;
var
  Msg: string;
  I: Integer;
  Suggestion: TRecoverySuggestion;
begin
  // Use custom message or default
  if AMessage <> '' then
    Msg := AMessage
  else
    Msg := FErrorMessages[ACode];

  Result := TEnhancedError.Create(ACode, Msg);

  // Add default suggestions
  for I := 0 to High(FDefaultSuggestions[ACode]) do
  begin
    Suggestion := FDefaultSuggestions[ACode][I];
    Result.AddSuggestion(Suggestion.Action, Suggestion.Command, Suggestion.Description);
  end;
end;

function TErrorRegistry.GetErrorMessageByCode(ACode: TErrorCode): string;
begin
  Result := FErrorMessages[ACode];
end;

{ Helper functions }

function NewError(ACode: TErrorCode; const AMessage: string): TEnhancedError;
begin
  Result := TErrorRegistry.Instance.CreateError(ACode, AMessage);
end;

function ErrorCodeToString(ACode: TErrorCode): string;
begin
  case ACode of
    ecSuccess: Result := 'SUCCESS';
    ecNetworkTimeout: Result := 'NETWORK_TIMEOUT';
    ecNetworkConnectionFailed: Result := 'NETWORK_CONNECTION_FAILED';
    ecPermissionDenied: Result := 'PERMISSION_DENIED';
    ecFileNotFound: Result := 'FILE_NOT_FOUND';
    ecDirectoryNotFound: Result := 'DIRECTORY_NOT_FOUND';
    ecDependencyMissing: Result := 'DEPENDENCY_MISSING';
    ecInvalidVersion: Result := 'INVALID_VERSION';
    ecInvalidInput: Result := 'INVALID_INPUT';
    ecChecksumMismatch: Result := 'CHECKSUM_MISMATCH';
    ecBuildFailed: Result := 'BUILD_FAILED';
    ecInstallationFailed: Result := 'INSTALLATION_FAILED';
    ecConfigurationError: Result := 'CONFIGURATION_ERROR';
    ecUnknownError: Result := 'UNKNOWN_ERROR';
  else
    Result := 'UNKNOWN';
  end;
end;

end.

finalization
  if TErrorRegistry.FInstance <> nil then
  begin
    TErrorRegistry.FInstance.Free;
    TErrorRegistry.FInstance := nil;
  end;
