unit fpdev.manifest;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, fphttpclient, openssl;

const
  SUPPORTED_MANIFEST_VERSION = '1';
  MAX_PACKAGE_SIZE = 10737418240; // 10GB in bytes

type
  { TManifestTarget - Binary package information for a single platform }
  TManifestTarget = record
    URLs: array of string;      // Supports multiple mirrors
    Hash: string;                // Format: "sha256:abc123..." or "sha512:def456..."
    Size: Int64;                 // File size (bytes)
    Signature: string;           // Optional signature
  end;

  { TManifestPackage - Package information for a single version }
  TManifestPackage = record
    Version: string;
    Targets: array of record
      Platform: string;          // e.g. "linux-x86_64"
      Target: TManifestTarget;
    end;
  end;

  { TManifestParser - Parses and validates the manifest file }
  TManifestParser = class
  private
    FManifestVersion: string;
    FDate: string;
    FChannel: string;
    FPackages: array of TManifestPackage;
    FLastError: string;
    FJSONData: TJSONData;

    function ParseJSON(const AContent: string): Boolean;
    function ValidateManifest: Boolean;
    function ParseTarget(ATargetObj: TJSONObject): TManifestTarget;
    function ParsePackage(const {%H-} AName: string; APkgObj: TJSONObject): TManifestPackage;
  public
    constructor Create;
    destructor Destroy; override;

    { Load manifest }
    function LoadFromFile(const AFile: string): Boolean;
    function LoadFromURL(const AURL: string): Boolean;
    function LoadFromString(const AContent: string): Boolean;

    { Query package information }
    function GetPackage(const AName, AVersion, {%H-} APlatform: string; out APkg: TManifestPackage): Boolean;
    function GetTarget(const AName, AVersion, APlatform: string; out ATarget: TManifestTarget): Boolean;
    function ListVersions(const {%H-} AName: string): TStringArray;
    function ListPlatforms(const AName, AVersion: string): TStringArray;

    { Validate }
    function Validate: Boolean;

    { Properties }
    property ManifestVersion: string read FManifestVersion;
    property Date: string read FDate;
    property Channel: string read FChannel;
    property LastError: string read FLastError;
  end;

  { Helper functions }
  function ParseHashAlgorithm(const AHash: string; out AAlgorithm, ADigest: string): Boolean;
  function ValidateHashFormat(const AHash: string): Boolean;
  function ValidateURL(const AURL: string): Boolean;
  function ValidateHexDigest(const ADigest: string): Boolean;

implementation

uses
  fpdev.utils.fs;

{ Helper function implementations }

function ValidateURL(const AURL: string): Boolean;
begin
  Result := (Pos('https://', LowerCase(AURL)) = 1);
end;

function ValidateHexDigest(const ADigest: string): Boolean;
var
  I: Integer;
begin
  Result := False;

  if Length(ADigest) = 0 then
    Exit;

  // Validate all characters are hexadecimal
  for I := 1 to Length(ADigest) do
    if not (ADigest[I] in ['0'..'9', 'a'..'f', 'A'..'F']) then
      Exit;

  Result := True;
end;

function ParseHashAlgorithm(const AHash: string; out AAlgorithm, ADigest: string): Boolean;
var
  ColonPos: Integer;
begin
  Result := False;
  AAlgorithm := '';
  ADigest := '';

  ColonPos := Pos(':', AHash);
  if ColonPos <= 0 then
    Exit;

  AAlgorithm := LowerCase(Copy(AHash, 1, ColonPos - 1));
  ADigest := Copy(AHash, ColonPos + 1, Length(AHash));

  // Validate algorithm name
  if (AAlgorithm <> 'sha256') and (AAlgorithm <> 'sha512') then
    Exit;

  // Validate digest format (hexadecimal)
  if not ValidateHexDigest(ADigest) then
    Exit;

  Result := True;
end;

function ValidateHashFormat(const AHash: string): Boolean;
var
  Algorithm, Digest: string;
begin
  Result := ParseHashAlgorithm(AHash, Algorithm, Digest);
end;

{ TManifestParser }

constructor TManifestParser.Create;
begin
  inherited Create;
  FJSONData := nil;
  FManifestVersion := '';
  FDate := '';
  FChannel := '';
  SetLength(FPackages, 0);
  FLastError := '';
end;

destructor TManifestParser.Destroy;
begin
  if Assigned(FJSONData) then
    FJSONData.Free;
  inherited Destroy;
end;

function TManifestParser.ParseJSON(const AContent: string): Boolean;
var
  Parser: TJSONParser;
begin
  Result := False;
  FLastError := '';

  if Assigned(FJSONData) then
  begin
    FJSONData.Free;
    FJSONData := nil;
  end;

  try
    Parser := TJSONParser.Create(AContent, []);
    try
      FJSONData := Parser.Parse;
      Result := Assigned(FJSONData);
      if not Result then
        FLastError := 'Failed to parse JSON';
    finally
      Parser.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'JSON parse error: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TManifestParser.ValidateManifest: Boolean;
var
  RootObj: TJSONObject;
begin
  Result := False;
  FLastError := '';

  if not Assigned(FJSONData) then
  begin
    FLastError := 'No JSON data loaded';
    Exit;
  end;

  if FJSONData.JSONType <> jtObject then
  begin
    FLastError := 'Root element must be an object';
    Exit;
  end;

  RootObj := TJSONObject(FJSONData);

  // Validate required field: manifest-version
  if RootObj.IndexOfName('manifest-version') < 0 then
  begin
    FLastError := 'Missing required field: manifest-version';
    Exit;
  end;

  FManifestVersion := RootObj.Get('manifest-version', '');
  if FManifestVersion <> SUPPORTED_MANIFEST_VERSION then
  begin
    FLastError := 'Unsupported manifest version: ' + FManifestVersion;
    Exit;
  end;

  // Validate required field: date
  if RootObj.IndexOfName('date') < 0 then
  begin
    FLastError := 'Missing required field: date';
    Exit;
  end;

  FDate := RootObj.Get('date', '');

  // Optional field: channel
  FChannel := RootObj.Get('channel', '');

  // Validate required field: pkg
  if RootObj.IndexOfName('pkg') < 0 then
  begin
    FLastError := 'Missing required field: pkg';
    Exit;
  end;

  Result := True;
end;

function TManifestParser.ParseTarget(ATargetObj: TJSONObject): TManifestTarget;
var
  URLValue: TJSONData;
  URLArray: TJSONArray;
  I: Integer;
begin
  // Initialize
  Result := Default(TManifestTarget);
  SetLength(Result.URLs, 0);
  Result.Hash := '';
  Result.Size := 0;
  Result.Signature := '';

  // Parse URL (can be a string or an array)
  if ATargetObj.IndexOfName('url') >= 0 then
  begin
    URLValue := ATargetObj.Find('url');
    if URLValue.JSONType = jtString then
    begin
      // Single URL
      SetLength(Result.URLs, 1);
      Result.URLs[0] := URLValue.AsString;
    end
    else if URLValue.JSONType = jtArray then
    begin
      // Multiple URLs
      URLArray := TJSONArray(URLValue);
      SetLength(Result.URLs, URLArray.Count);
      for I := 0 to URLArray.Count - 1 do
        Result.URLs[I] := URLArray.Strings[I];
    end;
  end;

  // Parse hash
  Result.Hash := ATargetObj.Get('hash', '');

  // Parse size
  Result.Size := ATargetObj.Get('size', Int64(0));

  // Parse signature (optional)
  Result.Signature := ATargetObj.Get('signature', '');
end;

function TManifestParser.ParsePackage(const {%H-} AName: string; APkgObj: TJSONObject): TManifestPackage;
var
  TargetsObj: TJSONObject;
  I: Integer;
  TargetName: string;
  TargetObj: TJSONObject;
begin
  if AName <> '' then;

  // Initialize
  Result.Version := '';
  SetLength(Result.Targets, 0);

  // Parse version
  Result.Version := APkgObj.Get('version', '');

  // Parse targets
  if APkgObj.IndexOfName('targets') >= 0 then
  begin
    TargetsObj := APkgObj.Objects['targets'];
    if Assigned(TargetsObj) then
    begin
      SetLength(Result.Targets, TargetsObj.Count);
      for I := 0 to TargetsObj.Count - 1 do
      begin
        TargetName := TargetsObj.Names[I];
        TargetObj := TargetsObj.Objects[TargetName];
        if Assigned(TargetObj) then
        begin
          Result.Targets[I].Platform := TargetName;
          Result.Targets[I].Target := ParseTarget(TargetObj);
        end;
      end;
    end;
  end;
end;

function TManifestParser.LoadFromFile(const AFile: string): Boolean;
var
  Content: string;
  F: TextFile;
  Line: string;
begin
  Result := False;
  FLastError := '';

  if not FileExists(AFile) then
  begin
    FLastError := 'File not found: ' + AFile;
    Exit;
  end;

  try
    AssignFile(F, AFile);
    Reset(F);
    try
      Content := '';
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        Content := Content + Line + LineEnding;
      end;
    finally
      CloseFile(F);
    end;

    Result := LoadFromString(Content);
  except
    on E: Exception do
    begin
      FLastError := 'Failed to read file: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TManifestParser.LoadFromURL(const AURL: string): Boolean;
var
  HTTP: TFPHTTPClient;
  Content: string;
begin
  Result := False;
  FLastError := '';

  try
    HTTP := TFPHTTPClient.Create(nil);
    try
      // Initialize OpenSSL (for HTTPS)
      InitSSLInterface;

      Content := HTTP.Get(AURL);
      Result := LoadFromString(Content);
    finally
      HTTP.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to download manifest: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TManifestParser.LoadFromString(const AContent: string): Boolean;
var
  RootObj: TJSONObject;
  PkgObj: TJSONObject;
  I: Integer;
  PkgName: string;
begin
  Result := False;

  // Parse JSON
  if not ParseJSON(AContent) then
    Exit;

  // Validate manifest
  if not ValidateManifest then
    Exit;

  // Parse package information
  RootObj := TJSONObject(FJSONData);
  PkgObj := RootObj.Objects['pkg'];
  if not Assigned(PkgObj) then
  begin
    FLastError := 'Invalid pkg object';
    Exit;
  end;

  SetLength(FPackages, PkgObj.Count);
  for I := 0 to PkgObj.Count - 1 do
  begin
    PkgName := PkgObj.Names[I];
    FPackages[I] := ParsePackage(PkgName, PkgObj.Objects[PkgName]);
  end;

  Result := True;
end;

function TManifestParser.GetPackage(const AName, AVersion, {%H-} APlatform: string; out APkg: TManifestPackage): Boolean;
var
  I: Integer;
begin
  Result := False;
  if APlatform <> '' then;

  for I := 0 to High(FPackages) do
  begin
    if (FPackages[I].Version = AVersion) then
    begin
      APkg := FPackages[I];
      Result := True;
      Exit;
    end;
  end;

  FLastError := Format('Package not found: %s version %s', [AName, AVersion]);
end;

function TManifestParser.GetTarget(const AName, AVersion, APlatform: string; out ATarget: TManifestTarget): Boolean;
var
  Pkg: TManifestPackage;
  I: Integer;
begin
  Result := False;

  if not GetPackage(AName, AVersion, APlatform, Pkg) then
    Exit;

  for I := 0 to High(Pkg.Targets) do
  begin
    if Pkg.Targets[I].Platform = APlatform then
    begin
      ATarget := Pkg.Targets[I].Target;
      Result := True;
      Exit;
    end;
  end;

  FLastError := Format('Platform not found: %s for version %s', [APlatform, AVersion]);
end;

function TManifestParser.ListVersions(const {%H-} AName: string): TStringArray;
var
  I: Integer;
begin
  Result := nil;
  if AName <> '' then;
  SetLength(Result, Length(FPackages));
  for I := 0 to High(FPackages) do
    Result[I] := FPackages[I].Version;
end;

function TManifestParser.ListPlatforms(const AName, AVersion: string): TStringArray;
var
  Pkg: TManifestPackage;
  I: Integer;
begin
  Result := nil;
  SetLength(Result, 0);

  if not GetPackage(AName, AVersion, '', Pkg) then
    Exit;

  SetLength(Result, Length(Pkg.Targets));
  for I := 0 to High(Pkg.Targets) do
    Result[I] := Pkg.Targets[I].Platform;
end;

function TManifestParser.Validate: Boolean;
var
  I, J, K: Integer;
  Pkg: TManifestPackage;
  Target: TManifestTarget;
begin
  Result := False;
  FLastError := '';

  // Validate each package
  for I := 0 to High(FPackages) do
  begin
    Pkg := FPackages[I];

    // Validate version
    if Pkg.Version = '' then
    begin
      FLastError := 'Package has empty version';
      Exit;
    end;

    // Validate each target platform
    for J := 0 to High(Pkg.Targets) do
    begin
      Target := Pkg.Targets[J].Target;

      // Validate URL
      if Length(Target.URLs) = 0 then
      begin
        FLastError := Format('No URLs for platform %s', [Pkg.Targets[J].Platform]);
        Exit;
      end;

      // Ensure all URLs use HTTPS
      for K := 0 to High(Target.URLs) do
      begin
        if not ValidateURL(Target.URLs[K]) then
        begin
          FLastError := Format('URL must use HTTPS for platform %s: %s', [Pkg.Targets[J].Platform, Target.URLs[K]]);
          Exit;
        end;
      end;

      // Validate hash
      if not ValidateHashFormat(Target.Hash) then
      begin
        FLastError := Format('Invalid hash format for platform %s: %s', [Pkg.Targets[J].Platform, Target.Hash]);
        Exit;
      end;

      // Validate size
      if Target.Size <= 0 then
      begin
        FLastError := Format('Invalid size for platform %s: %d', [Pkg.Targets[J].Platform, Target.Size]);
        Exit;
      end;

      // Validate size does not exceed the maximum limit
      if Target.Size > MAX_PACKAGE_SIZE then
      begin
        FLastError := Format('Size exceeds maximum limit for platform %s: %d bytes (max: %d)', [Pkg.Targets[J].Platform, Target.Size, MAX_PACKAGE_SIZE]);
        Exit;
      end;
    end;
  end;

  Result := True;
end;

end.
