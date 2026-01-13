unit fpdev.fpc.types;

{$mode objfpc}{$H+}

{
  FPC Types
  
  This module defines ALL common types, constants, and utility functions
  used across FPC management modules. This is the SINGLE SOURCE OF TRUTH
  for shared definitions to avoid code duplication.
}

interface

uses
  SysUtils, Classes, fpdev.constants;

type
  { TFPCErrorCode - Error codes for FPC operations }
  TFPCErrorCode = (
    ecSuccess = 0,
    ecUnknownError = 1,
    ecVersionNotFound = 10,
    ecVersionInvalid = 11,
    ecVersionAlreadyInstalled = 12,
    ecVersionNotInstalled = 13,
    ecDownloadFailed = 20,
    ecChecksumMismatch = 21,
    ecExtractionFailed = 22,
    ecBuildFailed = 30,
    ecCompilationFailed = 31,
    ecInstallationFailed = 40,
    ecUninstallationFailed = 41,
    ecVerificationFailed = 50,
    ecSmokeTestFailed = 51,
    ecActivationFailed = 60,
    ecConfigurationError = 70,
    ecFileSystemError = 80,
    ecNetworkError = 90,
    ecPermissionDenied = 100,
    ecTimeout = 110
  );

  { TOperationWarning - Warning information }
  TOperationWarning = record
    Code: Integer;
    Message: string;
  end;
  TOperationWarnings = array of TOperationWarning;

  { TOperationResult - Unified operation result type }
  TOperationResult = record
    Success: Boolean;
    ErrorCode: TFPCErrorCode;
    ErrorMessage: string;
    Warnings: TOperationWarnings;
    Data: Pointer;
  end;

  { TFPCVersionInfo - Information about an FPC version }
  TFPCVersionInfo = record
    Version: string;      // e.g., '3.2.2'
    ReleaseDate: string;  // e.g., '2021-05-19'
    GitTag: string;       // e.g., '3_2_2'
    Branch: string;       // e.g., 'fixes_3_2'
    Available: Boolean;   // Available for download
    Installed: Boolean;   // Installed locally
  end;
  TFPCVersionArray = array of TFPCVersionInfo;

  { TVerificationResult - Result of verification operation }
  TVerificationResult = record
    Verified: Boolean;
    ExecutableExists: Boolean;
    DetectedVersion: string;
    SmokeTestPassed: Boolean;
    ErrorMessage: string;
  end;

  { TInstallScope - Installation scope }
  TInstallScope = (isUser, isProject, isSystem);

  { TSourceMode - Source mode for installation }
  TSourceMode = (smAuto, smBinary, smSource);

  { TActivationResult - Result of activation operation }
  TActivationResult = record
    Success: Boolean;
    Scope: TInstallScope;
    ActivationScript: string;
    VSCodeSettings: string;
    ShellCommand: string;
    ErrorMessage: string;
  end;

  { TVerifyInfo - Verification info for metadata }
  TVerifyInfo = record
    Timestamp: TDateTime;
    OK: Boolean;
    DetectedVersion: string;
    SmokeTestPassed: Boolean;
  end;

  { TOriginInfo - Origin info for metadata }
  TOriginInfo = record
    RepoURL: string;
    Commit: string;
    BuiltFromSource: Boolean;
  end;

  { TFPDevMetadata - FPDev installation metadata }
  TFPDevMetadata = record
    Version: string;
    Scope: TInstallScope;
    SourceMode: TSourceMode;
    Channel: string;
    Prefix: string;
    Verify: TVerifyInfo;
    Origin: TOriginInfo;
    InstalledAt: TDateTime;
  end;

  { TBinaryDownloadInfo - Binary download info }
  TBinaryDownloadInfo = record
    URL: string;
    Checksum: string;
    Platform: string;
    Architecture: string;
  end;

const
  { FPC Release Catalog }
  FPC_RELEASES: array[0..4] of TFPCVersionInfo = (
    (Version:'3.2.2'; ReleaseDate:'2021-05-19'; GitTag:'3_2_2'; Branch:'fixes_3_2'; Available:True; Installed:False),
    (Version:'3.2.0'; ReleaseDate:'2020-06-19'; GitTag:'3_2_0'; Branch:'fixes_3_2'; Available:True; Installed:False),
    (Version:'3.0.4'; ReleaseDate:'2017-11-21'; GitTag:'3_0_4'; Branch:'fixes_3_0'; Available:True; Installed:False),
    (Version:'3.3.1'; ReleaseDate:'rolling';    GitTag:'main';  Branch:'main';    Available:True; Installed:False),
    (Version:'main';  ReleaseDate:'rolling';    GitTag:'main';  Branch:'main';    Available:True; Installed:False)
  );

{ TOperationResult helper functions }
function OperationSuccess: TOperationResult;
function OperationError(AErrorCode: TFPCErrorCode; const AMessage: string): TOperationResult;
function OperationWarning(var AResult: TOperationResult; ACode: Integer; const AMessage: string): TOperationResult;
function ErrorCodeToString(ACode: TFPCErrorCode): string;

{ Version parsing and comparison utilities }
procedure ParseVersion(const AVer: string; out AMajor, AMinor, APatch: Integer);
function CompareSemVer(const AV1, AV2: string): Integer;
function SameMajorMinor(const AV1, AV2: string): Boolean;

{ File utilities }
procedure SafeWriteAllText(const APath, AText: string);
function ReadAllTextIfExists(const APath: string): string;

implementation

{ TOperationResult helpers }

function OperationSuccess: TOperationResult;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Success := True;
  Result.ErrorCode := ecSuccess;
  Result.ErrorMessage := '';
  SetLength(Result.Warnings, 0);
  Result.Data := nil;
end;

function OperationError(AErrorCode: TFPCErrorCode; const AMessage: string): TOperationResult;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Success := False;
  Result.ErrorCode := AErrorCode;
  Result.ErrorMessage := AMessage;
  SetLength(Result.Warnings, 0);
  Result.Data := nil;
end;

function OperationWarning(var AResult: TOperationResult; ACode: Integer; const AMessage: string): TOperationResult;
var
  Len: Integer;
begin
  Len := Length(AResult.Warnings);
  SetLength(AResult.Warnings, Len + 1);
  AResult.Warnings[Len].Code := ACode;
  AResult.Warnings[Len].Message := AMessage;
  Result := AResult;
end;

function ErrorCodeToString(ACode: TFPCErrorCode): string;
begin
  case ACode of
    ecSuccess: Result := 'Success';
    ecUnknownError: Result := 'Unknown error';
    ecVersionNotFound: Result := 'Version not found';
    ecVersionInvalid: Result := 'Invalid version';
    ecVersionAlreadyInstalled: Result := 'Version already installed';
    ecVersionNotInstalled: Result := 'Version not installed';
    ecDownloadFailed: Result := 'Download failed';
    ecChecksumMismatch: Result := 'Checksum mismatch';
    ecExtractionFailed: Result := 'Extraction failed';
    ecBuildFailed: Result := 'Build failed';
    ecCompilationFailed: Result := 'Compilation failed';
    ecInstallationFailed: Result := 'Installation failed';
    ecUninstallationFailed: Result := 'Uninstallation failed';
    ecVerificationFailed: Result := 'Verification failed';
    ecSmokeTestFailed: Result := 'Smoke test failed';
    ecActivationFailed: Result := 'Activation failed';
    ecConfigurationError: Result := 'Configuration error';
    ecFileSystemError: Result := 'File system error';
    ecNetworkError: Result := 'Network error';
    ecPermissionDenied: Result := 'Permission denied';
    ecTimeout: Result := 'Operation timed out';
  else
    Result := 'Error code: ' + IntToStr(Ord(ACode));
  end;
end;

{ Version parsing utilities }

function TryParseInt(const S: string; out N: Integer): Boolean;
var
  Code: Integer;
begin
  Val(S, N, Code);
  Result := Code = 0;
end;

procedure ParseVersion(const AVer: string; out AMajor, AMinor, APatch: Integer);
var
  i, p1, p2: Integer;
  s: string;
begin
  AMajor := 0; AMinor := 0; APatch := 0;
  s := AVer;
  p1 := Pos('.', s);
  if p1 > 0 then
  begin
    if not TryParseInt(Copy(s, 1, p1-1), AMajor) then AMajor := 0;
    Delete(s, 1, p1);
    p2 := Pos('.', s);
    if p2 > 0 then
    begin
      if not TryParseInt(Copy(s, 1, p2-1), AMinor) then AMinor := 0;
      Delete(s, 1, p2);
      i := 1;
      while (i <= Length(s)) and (s[i] in ['0'..'9']) do Inc(i);
      if i > 1 then
        if not TryParseInt(Copy(s, 1, i-1), APatch) then APatch := 0;
    end
    else
    begin
      if not TryParseInt(s, AMinor) then AMinor := 0;
    end;
  end
  else
  begin
    TryParseInt(s, AMajor);
  end;
end;

function CompareSemVer(const AV1, AV2: string): Integer;
var
  a1, b1, c1, a2, b2, c2: Integer;
begin
  ParseVersion(AV1, a1, b1, c1);
  ParseVersion(AV2, a2, b2, c2);
  if a1 <> a2 then Exit(Ord(a1 > a2) - Ord(a1 < a2));
  if b1 <> b2 then Exit(Ord(b1 > b2) - Ord(b1 < b2));
  if c1 <> c2 then Exit(Ord(c1 > c2) - Ord(c1 < c2));
  Result := 0;
end;

function SameMajorMinor(const AV1, AV2: string): Boolean;
var
  a1, b1, c1, a2, b2, c2: Integer;
begin
  ParseVersion(AV1, a1, b1, c1);
  ParseVersion(AV2, a2, b2, c2);
  Result := (a1 = a2) and (b1 = b2);
end;

{ File utilities }

procedure SafeWriteAllText(const APath, AText: string);
var
  Dir: string;
  L: TStringList;
begin
  Dir := ExtractFileDir(APath);
  if (Dir <> '') and (not DirectoryExists(Dir)) then
    ForceDirectories(Dir);
  L := TStringList.Create;
  try
    L.Text := AText;
    L.SaveToFile(APath);
  finally
    L.Free;
  end;
end;

function ReadAllTextIfExists(const APath: string): string;
var
  L: TStringList;
begin
  Result := '';
  if not FileExists(APath) then Exit;
  L := TStringList.Create;
  try
    L.LoadFromFile(APath);
    Result := Trim(L.Text);
  finally
    L.Free;
  end;
end;

end.
