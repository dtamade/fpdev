program test_resource_repo_binary;

{$mode objfpc}{$H+}

uses
  SysUtils, fpjson, fpdev.resource.repo.binary;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(const ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

function BuildTestManifest: TJSONObject;
var
  Manifest, FPCReleases, Version322, Platforms, PlatformLinux: TJSONObject;
  MirrorsArr: TJSONArray;
begin
  Manifest := TJSONObject.Create;
  FPCReleases := TJSONObject.Create;
  Version322 := TJSONObject.Create;
  Platforms := TJSONObject.Create;
  PlatformLinux := TJSONObject.Create;

  PlatformLinux.Add('url', 'https://example.com/fpc-3.2.2-x86_64-linux.tar.gz');
  PlatformLinux.Add('sha256', 'abc123def456');
  PlatformLinux.Add('size', Int64(50000000));
  PlatformLinux.Add('tested', True);

  MirrorsArr := TJSONArray.Create;
  MirrorsArr.Add('https://mirror1.com/fpc.tar.gz');
  MirrorsArr.Add('https://mirror2.com/fpc.tar.gz');
  PlatformLinux.Add('mirrors', MirrorsArr);

  Platforms.Add('x86_64-linux', PlatformLinux);

  Version322.Add('path', '/releases/3.2.2');
  Version322.Add('platforms', Platforms);

  FPCReleases.Add('3.2.2', Version322);

  Manifest.Add('fpc_releases', FPCReleases);

  Result := Manifest;
end;

function BuildV1Manifest: TJSONObject;
var
  Manifest, BinaryReleases, Version322, Platforms, PlatformLinux: TJSONObject;
begin
  Manifest := TJSONObject.Create;
  BinaryReleases := TJSONObject.Create;
  Version322 := TJSONObject.Create;
  Platforms := TJSONObject.Create;
  PlatformLinux := TJSONObject.Create;

  PlatformLinux.Add('archive', 'fpc-3.2.2-linux.tar.gz');
  PlatformLinux.Add('sha256', 'v1hash123');

  Platforms.Add('x86_64-linux', PlatformLinux);

  Version322.Add('path', '/v1/releases/3.2.2');
  Version322.Add('platforms', Platforms);

  BinaryReleases.Add('3.2.2', Version322);

  Manifest.Add('binary_releases', BinaryReleases);

  Result := Manifest;
end;

{ --- HasBinaryRelease tests --- }

procedure TestHasBinaryReleaseTrue;
var
  Manifest: TJSONObject;
begin
  Manifest := BuildTestManifest;
  try
    Check(ResourceRepoHasBinaryRelease(Manifest, '3.2.2', 'x86_64-linux') = True,
          'HasBinaryRelease: existing version+platform -> True');
  finally
    Manifest.Free;
  end;
end;

procedure TestHasBinaryReleaseMissingVersion;
var
  Manifest: TJSONObject;
begin
  Manifest := BuildTestManifest;
  try
    Check(ResourceRepoHasBinaryRelease(Manifest, '3.0.0', 'x86_64-linux') = False,
          'HasBinaryRelease: missing version -> False');
  finally
    Manifest.Free;
  end;
end;

procedure TestHasBinaryReleaseMissingPlatform;
var
  Manifest: TJSONObject;
begin
  Manifest := BuildTestManifest;
  try
    Check(ResourceRepoHasBinaryRelease(Manifest, '3.2.2', 'aarch64-darwin') = False,
          'HasBinaryRelease: missing platform -> False');
  finally
    Manifest.Free;
  end;
end;

procedure TestHasBinaryReleaseNilManifest;
begin
  Check(ResourceRepoHasBinaryRelease(nil, '3.2.2', 'x86_64-linux') = False,
        'HasBinaryRelease: nil manifest -> False');
end;

procedure TestHasBinaryReleaseV1Format;
var
  Manifest: TJSONObject;
begin
  Manifest := BuildV1Manifest;
  try
    Check(ResourceRepoHasBinaryRelease(Manifest, '3.2.2', 'x86_64-linux') = True,
          'HasBinaryRelease v1: existing version+platform -> True');
  finally
    Manifest.Free;
  end;
end;

procedure TestHasBinaryReleaseEmptyManifest;
var
  Manifest: TJSONObject;
begin
  Manifest := TJSONObject.Create;
  try
    Check(ResourceRepoHasBinaryRelease(Manifest, '3.2.2', 'x86_64-linux') = False,
          'HasBinaryRelease: empty manifest -> False');
  finally
    Manifest.Free;
  end;
end;

{ --- GetBinaryReleaseInfo tests --- }

procedure TestGetBinaryReleaseInfoV2;
var
  Manifest: TJSONObject;
  Info: TBinaryReleaseInfo;
begin
  Manifest := BuildTestManifest;
  try
    Check(ResourceRepoGetBinaryReleaseInfo(Manifest, '3.2.2', 'x86_64-linux', Info) = True,
          'GetInfo v2: returns True');
    Check(Info.URL = 'https://example.com/fpc-3.2.2-x86_64-linux.tar.gz',
          'GetInfo v2: URL correct');
    Check(Info.SHA256 = 'abc123def456',
          'GetInfo v2: SHA256 correct');
    Check(Info.Size = 50000000,
          'GetInfo v2: Size correct');
    Check(Info.Tested = True,
          'GetInfo v2: Tested correct');
    Check(Info.Path = '/releases/3.2.2',
          'GetInfo v2: Path correct');
    Check(Length(Info.Mirrors) = 2,
          'GetInfo v2: 2 mirrors');
    Check(Info.Mirrors[0] = 'https://mirror1.com/fpc.tar.gz',
          'GetInfo v2: first mirror correct');
  finally
    Manifest.Free;
  end;
end;

procedure TestGetBinaryReleaseInfoV1;
var
  Manifest: TJSONObject;
  Info: TBinaryReleaseInfo;
begin
  Manifest := BuildV1Manifest;
  try
    Check(ResourceRepoGetBinaryReleaseInfo(Manifest, '3.2.2', 'x86_64-linux', Info) = True,
          'GetInfo v1: returns True');
    Check(Info.Path = 'fpc-3.2.2-linux.tar.gz',
          'GetInfo v1: archive -> Path');
    Check(Info.SHA256 = 'v1hash123',
          'GetInfo v1: SHA256 correct');
  finally
    Manifest.Free;
  end;
end;

procedure TestGetBinaryReleaseInfoMissingVersion;
var
  Manifest: TJSONObject;
  Info: TBinaryReleaseInfo;
begin
  Manifest := BuildTestManifest;
  try
    Check(ResourceRepoGetBinaryReleaseInfo(Manifest, '3.0.0', 'x86_64-linux', Info) = False,
          'GetInfo: missing version -> False');
  finally
    Manifest.Free;
  end;
end;

procedure TestGetBinaryReleaseInfoMissingPlatform;
var
  Manifest: TJSONObject;
  Info: TBinaryReleaseInfo;
begin
  Manifest := BuildTestManifest;
  try
    Check(ResourceRepoGetBinaryReleaseInfo(Manifest, '3.2.2', 'aarch64-darwin', Info) = False,
          'GetInfo: missing platform -> False');
  finally
    Manifest.Free;
  end;
end;

procedure TestGetBinaryReleaseInfoNilManifest;
var
  Info: TBinaryReleaseInfo;
begin
  Check(ResourceRepoGetBinaryReleaseInfo(nil, '3.2.2', 'x86_64-linux', Info) = False,
        'GetInfo: nil manifest -> False');
end;

procedure TestGetBinaryReleaseInfoEmptyManifest;
var
  Manifest: TJSONObject;
  Info: TBinaryReleaseInfo;
begin
  Manifest := TJSONObject.Create;
  try
    Check(ResourceRepoGetBinaryReleaseInfo(Manifest, '3.2.2', 'x86_64-linux', Info) = False,
          'GetInfo: empty manifest -> False');
  finally
    Manifest.Free;
  end;
end;

begin
  WriteLn('=== Resource Repo Binary Unit Tests ===');
  WriteLn;

  TestHasBinaryReleaseTrue;
  TestHasBinaryReleaseMissingVersion;
  TestHasBinaryReleaseMissingPlatform;
  TestHasBinaryReleaseNilManifest;
  TestHasBinaryReleaseV1Format;
  TestHasBinaryReleaseEmptyManifest;
  TestGetBinaryReleaseInfoV2;
  TestGetBinaryReleaseInfoV1;
  TestGetBinaryReleaseInfoMissingVersion;
  TestGetBinaryReleaseInfoMissingPlatform;
  TestGetBinaryReleaseInfoNilManifest;
  TestGetBinaryReleaseInfoEmptyManifest;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
