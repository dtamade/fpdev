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
  { TManifestTarget - 单个平台的二进制包信息 }
  TManifestTarget = record
    URLs: array of string;      // 支持多镜像
    Hash: string;                // 格式："sha256:abc123..." 或 "sha512:def456..."
    Size: Int64;                 // 文件大小（字节）
    Signature: string;           // 可选签名
  end;

  { TManifestPackage - 单个版本的包信息 }
  TManifestPackage = record
    Version: string;
    Targets: array of record
      Platform: string;          // 例如："linux-x86_64"
      Target: TManifestTarget;
    end;
  end;

  { TManifestParser - 解析和验证 manifest 文件 }
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

    { 加载 manifest }
    function LoadFromFile(const AFile: string): Boolean;
    function LoadFromURL(const AURL: string): Boolean;
    function LoadFromString(const AContent: string): Boolean;

    { 查询包信息 }
    function GetPackage(const AName, AVersion, {%H-} APlatform: string; out APkg: TManifestPackage): Boolean;
    function GetTarget(const AName, AVersion, APlatform: string; out ATarget: TManifestTarget): Boolean;
    function ListVersions(const {%H-} AName: string): TStringArray;
    function ListPlatforms(const AName, AVersion: string): TStringArray;

    { 验证 }
    function Validate: Boolean;

    { 属性 }
    property ManifestVersion: string read FManifestVersion;
    property Date: string read FDate;
    property Channel: string read FChannel;
    property LastError: string read FLastError;
  end;

  { 辅助函数 }
  function ParseHashAlgorithm(const AHash: string; out AAlgorithm, ADigest: string): Boolean;
  function ValidateHashFormat(const AHash: string): Boolean;
  function ValidateURL(const AURL: string): Boolean;
  function ValidateHexDigest(const ADigest: string): Boolean;

implementation

uses
  fpdev.utils.fs;

{ 辅助函数实现 }

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

  // 验证算法名称
  if (AAlgorithm <> 'sha256') and (AAlgorithm <> 'sha512') then
    Exit;

  // 验证摘要格式（十六进制）
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

  // 验证必需字段：manifest-version
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

  // 验证必需字段：date
  if RootObj.IndexOfName('date') < 0 then
  begin
    FLastError := 'Missing required field: date';
    Exit;
  end;

  FDate := RootObj.Get('date', '');

  // 可选字段：channel
  FChannel := RootObj.Get('channel', '');

  // 验证必需字段：pkg
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
  // 初始化
  Result := Default(TManifestTarget);
  SetLength(Result.URLs, 0);
  Result.Hash := '';
  Result.Size := 0;
  Result.Signature := '';

  // 解析 URL（可以是字符串或数组）
  if ATargetObj.IndexOfName('url') >= 0 then
  begin
    URLValue := ATargetObj.Find('url');
    if URLValue.JSONType = jtString then
    begin
      // 单个 URL
      SetLength(Result.URLs, 1);
      Result.URLs[0] := URLValue.AsString;
    end
    else if URLValue.JSONType = jtArray then
    begin
      // 多个 URL
      URLArray := TJSONArray(URLValue);
      SetLength(Result.URLs, URLArray.Count);
      for I := 0 to URLArray.Count - 1 do
        Result.URLs[I] := URLArray.Strings[I];
    end;
  end;

  // 解析 hash
  Result.Hash := ATargetObj.Get('hash', '');

  // 解析 size
  Result.Size := ATargetObj.Get('size', Int64(0));

  // 解析 signature（可选）
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

  // 初始化
  Result.Version := '';
  SetLength(Result.Targets, 0);

  // 解析 version
  Result.Version := APkgObj.Get('version', '');

  // 解析 targets
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
      // 初始化 OpenSSL（用于 HTTPS）
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

  // 解析 JSON
  if not ParseJSON(AContent) then
    Exit;

  // 验证 manifest
  if not ValidateManifest then
    Exit;

  // 解析包信息
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

  // 验证每个包
  for I := 0 to High(FPackages) do
  begin
    Pkg := FPackages[I];

    // 验证版本号
    if Pkg.Version = '' then
    begin
      FLastError := 'Package has empty version';
      Exit;
    end;

    // 验证每个目标平台
    for J := 0 to High(Pkg.Targets) do
    begin
      Target := Pkg.Targets[J].Target;

      // 验证 URL
      if Length(Target.URLs) = 0 then
      begin
        FLastError := Format('No URLs for platform %s', [Pkg.Targets[J].Platform]);
        Exit;
      end;

      // 验证所有 URL 必须使用 HTTPS
      for K := 0 to High(Target.URLs) do
      begin
        if not ValidateURL(Target.URLs[K]) then
        begin
          FLastError := Format('URL must use HTTPS for platform %s: %s', [Pkg.Targets[J].Platform, Target.URLs[K]]);
          Exit;
        end;
      end;

      // 验证 hash
      if not ValidateHashFormat(Target.Hash) then
      begin
        FLastError := Format('Invalid hash format for platform %s: %s', [Pkg.Targets[J].Platform, Target.Hash]);
        Exit;
      end;

      // 验证 size
      if Target.Size <= 0 then
      begin
        FLastError := Format('Invalid size for platform %s: %d', [Pkg.Targets[J].Platform, Target.Size]);
        Exit;
      end;

      // 验证 size 不超过最大限制
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
