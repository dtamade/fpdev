program test_resource_repo_distributionflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson,
  test_temp_paths,
  fpdev.resource.repo.types,
  fpdev.resource.repo.binary,
  fpdev.resource.repo.cross,
  fpdev.resource.repo.distributionflow;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

function BuildBinaryManifest: TJSONObject;
begin
  Result := TJSONObject.Create([
    'fpc_releases', TJSONObject.Create([
      '3.2.2', TJSONObject.Create([
        'path', 'releases/3.2.2',
        'platforms', TJSONObject.Create([
          'linux-x86_64', TJSONObject.Create([
            'url', 'https://example.invalid/fpc.tar.gz',
            'mirrors', TJSONArray.Create(['https://mirror1.invalid/fpc.tar.gz', 'https://mirror2.invalid/fpc.tar.gz']),
            'sha256', 'abc123',
            'size', Int64(123456),
            'tested', True
          ])
        ])
      ])
    ])
  ]);
end;

function BuildCrossManifest: TJSONObject;
begin
  Result := TJSONObject.Create([
    'cross_toolchains', TJSONObject.Create([
      'arm-linux', TJSONObject.Create([
        'display_name', 'ARM Linux',
        'cpu', 'arm',
        'os', 'linux',
        'binutils_prefix', 'arm-linux-',
        'host_platforms', TJSONObject.Create([
          'linux-x86_64', TJSONObject.Create([
            'binutils', 'cross/arm-linux/binutils.tar.gz',
            'libs', 'cross/arm-linux/libs.tar.gz',
            'binutils_sha256', 'bin123',
            'libs_sha256', 'lib123'
          ])
        ])
      ])
    ])
  ]);
end;

type
  TDistributionFlowHarness = class
  public
    Logs: TStringList;
    BinaryInfoAvailable: Boolean;
    CrossInfoAvailable: Boolean;
    PackageInfoAvailable: Boolean;
    BinaryInstallResult: Boolean;
    CrossInstallResult: Boolean;
    PackageInstallResult: Boolean;
    BinaryInfo: TPlatformInfo;
    CrossInfo: TCrossToolchainInfo;
    PackageInfo: TRepoPackageInfo;
    BinaryInstallCalls: Integer;
    CrossInstallCalls: Integer;
    PackageInstallCalls: Integer;
    LastBinaryVersion: string;
    LastBinaryPlatform: string;
    LastCrossTarget: string;
    LastCrossHost: string;
    LastPackageName: string;
    LastPackageVersion: string;
    LastDestDir: string;
    constructor Create;
    destructor Destroy; override;
    procedure LogLine(const AMsg: string);
    function GetBinaryInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
    function InstallBinary(const AInfo: TPlatformInfo; const AVersion, APlatform, ADestDir: string): Boolean;
    function GetCrossInfo(const ATarget, AHostPlatform: string; out AInfo: TCrossToolchainInfo): Boolean;
    function InstallCross(const AInfo: TCrossToolchainInfo; const ATarget, ADestDir: string): Boolean;
    function GetPackageInfo(const AName, AVersion: string; out AInfo: TRepoPackageInfo): Boolean;
    function InstallPackage(const AInfo: TRepoPackageInfo; const AName, AVersion, ADestDir: string): Boolean;
  end;

constructor TDistributionFlowHarness.Create;
begin
  inherited Create;
  Logs := TStringList.Create;
  BinaryInstallResult := True;
  CrossInstallResult := True;
  PackageInstallResult := True;
end;

destructor TDistributionFlowHarness.Destroy;
begin
  Logs.Free;
  inherited Destroy;
end;

procedure TDistributionFlowHarness.LogLine(const AMsg: string);
begin
  Logs.Add(AMsg);
end;

function TDistributionFlowHarness.GetBinaryInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
begin
  LastBinaryVersion := AVersion;
  LastBinaryPlatform := APlatform;
  AInfo := BinaryInfo;
  Result := BinaryInfoAvailable;
end;

function TDistributionFlowHarness.InstallBinary(const AInfo: TPlatformInfo; const AVersion, APlatform, ADestDir: string): Boolean;
begin
  Inc(BinaryInstallCalls);
  BinaryInfo := AInfo;
  LastBinaryVersion := AVersion;
  LastBinaryPlatform := APlatform;
  LastDestDir := ADestDir;
  Result := BinaryInstallResult;
end;

function TDistributionFlowHarness.GetCrossInfo(const ATarget, AHostPlatform: string; out AInfo: TCrossToolchainInfo): Boolean;
begin
  LastCrossTarget := ATarget;
  LastCrossHost := AHostPlatform;
  AInfo := CrossInfo;
  Result := CrossInfoAvailable;
end;

function TDistributionFlowHarness.InstallCross(const AInfo: TCrossToolchainInfo; const ATarget, ADestDir: string): Boolean;
begin
  Inc(CrossInstallCalls);
  CrossInfo := AInfo;
  LastCrossTarget := ATarget;
  LastDestDir := ADestDir;
  Result := CrossInstallResult;
end;

function TDistributionFlowHarness.GetPackageInfo(const AName, AVersion: string; out AInfo: TRepoPackageInfo): Boolean;
begin
  LastPackageName := AName;
  LastPackageVersion := AVersion;
  AInfo := PackageInfo;
  Result := PackageInfoAvailable;
end;

function TDistributionFlowHarness.InstallPackage(const AInfo: TRepoPackageInfo; const AName, AVersion, ADestDir: string): Boolean;
begin
  Inc(PackageInstallCalls);
  PackageInfo := AInfo;
  LastPackageName := AName;
  LastPackageVersion := AVersion;
  LastDestDir := ADestDir;
  Result := PackageInstallResult;
end;

procedure CreateTextFile(const APath, AContent: string);
var
  SL: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  SL := TStringList.Create;
  try
    SL.Text := AContent;
    SL.SaveToFile(APath);
  finally
    SL.Free;
  end;
end;

procedure TestGetBinaryReleaseInfoCore;
var
  Manifest: TJSONObject;
  Info: TPlatformInfo;
begin
  Manifest := BuildBinaryManifest;
  try
    Check('GetBinaryReleaseInfoCore parses manifest',
      ResourceRepoGetBinaryReleaseInfoCore(Manifest, '3.2.2', 'linux-x86_64', Info));
    Check('GetBinaryReleaseInfoCore maps path', Info.Path = 'releases/3.2.2', 'path=' + Info.Path);
    Check('GetBinaryReleaseInfoCore maps url', Info.URL = 'https://example.invalid/fpc.tar.gz', 'url=' + Info.URL);
    Check('GetBinaryReleaseInfoCore maps mirrors', Length(Info.Mirrors) = 2, 'mirrors=' + IntToStr(Length(Info.Mirrors)));
    Check('GetBinaryReleaseInfoCore maps sha', Info.SHA256 = 'abc123', 'sha=' + Info.SHA256);
    Check('GetBinaryReleaseInfoCore maps size', Info.Size = 123456, 'size=' + IntToStr(Info.Size));
    Check('GetBinaryReleaseInfoCore maps tested', Info.Tested, 'tested should be true');
  finally
    Manifest.Free;
  end;
end;

procedure TestGetCrossToolchainInfoCore;
var
  Manifest: TJSONObject;
  Info: TCrossToolchainInfo;
begin
  Manifest := BuildCrossManifest;
  try
    Check('GetCrossToolchainInfoCore parses manifest',
      ResourceRepoGetCrossToolchainInfoCore(Manifest, 'arm-linux', 'linux-x86_64', Info));
    Check('GetCrossToolchainInfoCore maps target', Info.TargetName = 'arm-linux', 'target=' + Info.TargetName);
    Check('GetCrossToolchainInfoCore maps display name', Info.DisplayName = 'ARM Linux', 'display=' + Info.DisplayName);
    Check('GetCrossToolchainInfoCore maps cpu', Info.CPU = 'arm', 'cpu=' + Info.CPU);
    Check('GetCrossToolchainInfoCore maps os', Info.OS = 'linux', 'os=' + Info.OS);
    Check('GetCrossToolchainInfoCore maps binutils prefix', Info.BinutilsPrefix = 'arm-linux-', 'prefix=' + Info.BinutilsPrefix);
    Check('GetCrossToolchainInfoCore maps binutils archive', Info.BinutilsArchive <> '', 'binutils should not be empty');
    Check('GetCrossToolchainInfoCore maps libs archive', Info.LibsArchive <> '', 'libs should not be empty');
  finally
    Manifest.Free;
  end;
end;

procedure TestHasPackageCore;
var
  RootDir: string;
  MetaPath: string;
begin
  RootDir := CreateUniqueTempDir('test_repo_distribution_pkg');
  try
    MetaPath := RootDir + PathDelim + 'packages' + PathDelim + 'utils' + PathDelim + 'jsonlib' + PathDelim + 'jsonlib.json';
    CreateTextFile(MetaPath, '{}');
    Check('HasPackageCore finds local package metadata',
      ResourceRepoHasPackageCore(RootDir, 'jsonlib', '1.0.0'));
    Check('HasPackageCore rejects missing package',
      not ResourceRepoHasPackageCore(RootDir, 'httplib', '1.0.0'));
  finally
    CleanupTempDir(RootDir);
  end;
end;

procedure TestGetPackageInfoCore;
var
  RootDir: string;
  MetaPath: string;
  Info: TRepoPackageInfo;
begin
  RootDir := CreateUniqueTempDir('test_repo_distribution_info');
  try
    MetaPath := RootDir + PathDelim + 'packages' + PathDelim + 'core' + PathDelim + 'jsonlib' + PathDelim + 'jsonlib.json';
    CreateTextFile(MetaPath,
      '{' +
      '"name":"jsonlib",' +
      '"version":"1.0.0",' +
      '"description":"JSON parsing library",' +
      '"category":"core",' +
      '"archive":"packages/core/jsonlib/jsonlib-1.0.0.tar.gz",' +
      '"sha256":"pkg123"' +
      '}');
    Check('GetPackageInfoCore loads package metadata',
      ResourceRepoGetPackageInfoCore(RootDir, 'jsonlib', '1.0.0', Info));
    Check('GetPackageInfoCore keeps name', Info.Name = 'jsonlib', 'name=' + Info.Name);
    Check('GetPackageInfoCore keeps archive', Info.Archive <> '', 'archive should not be empty');
  finally
    CleanupTempDir(RootDir);
  end;
end;

procedure TestInstallBinaryReleaseCore;
var
  Harness: TDistributionFlowHarness;
begin
  Harness := TDistributionFlowHarness.Create;
  try
    Harness.BinaryInfoAvailable := True;
    Harness.BinaryInfo.URL := 'https://example.invalid/fpc.tar.gz';
    Check('InstallBinaryReleaseCore delegates install',
      ExecuteResourceRepoInstallBinaryReleaseCore(
        '3.2.2', 'linux-x86_64', '/tmp/fpdev-dist-bin',
        @Harness.GetBinaryInfo, @Harness.InstallBinary, @Harness.LogLine));
    Check('InstallBinaryReleaseCore calls installer once', Harness.BinaryInstallCalls = 1,
      'calls=' + IntToStr(Harness.BinaryInstallCalls));
    Check('InstallBinaryReleaseCore forwards version', Harness.LastBinaryVersion = '3.2.2',
      'version=' + Harness.LastBinaryVersion);
    Check('InstallBinaryReleaseCore forwards platform', Harness.LastBinaryPlatform = 'linux-x86_64',
      'platform=' + Harness.LastBinaryPlatform);
  finally
    Harness.Free;
  end;
end;

procedure TestInstallBinaryReleaseCoreLogsMissingInfo;
var
  Harness: TDistributionFlowHarness;
begin
  Harness := TDistributionFlowHarness.Create;
  try
    Harness.BinaryInfoAvailable := False;
    Check('InstallBinaryReleaseCore fails without info',
      not ExecuteResourceRepoInstallBinaryReleaseCore(
        '3.2.2', 'linux-x86_64', '/tmp/fpdev-dist-bin',
        @Harness.GetBinaryInfo, @Harness.InstallBinary, @Harness.LogLine));
    Check('InstallBinaryReleaseCore logs missing info',
      Harness.Logs.IndexOf('Error: Binary release info not found') >= 0,
      'logs=' + Harness.Logs.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestInstallCrossToolchainCore;
var
  Harness: TDistributionFlowHarness;
begin
  Harness := TDistributionFlowHarness.Create;
  try
    Harness.CrossInfoAvailable := True;
    Harness.CrossInfo.TargetName := 'arm-linux';
    Check('InstallCrossToolchainCore delegates install',
      ExecuteResourceRepoInstallCrossToolchainCore(
        'arm-linux', 'linux-x86_64', '/tmp/fpdev-dist-cross',
        @Harness.GetCrossInfo, @Harness.InstallCross, @Harness.LogLine));
    Check('InstallCrossToolchainCore calls installer once', Harness.CrossInstallCalls = 1,
      'calls=' + IntToStr(Harness.CrossInstallCalls));
    Check('InstallCrossToolchainCore forwards target', Harness.LastCrossTarget = 'arm-linux',
      'target=' + Harness.LastCrossTarget);
  finally
    Harness.Free;
  end;
end;

procedure TestInstallPackageCore;
var
  Harness: TDistributionFlowHarness;
begin
  Harness := TDistributionFlowHarness.Create;
  try
    Harness.PackageInfoAvailable := True;
    Harness.PackageInfo.Name := 'jsonlib';
    Check('InstallPackageCore delegates install',
      ExecuteResourceRepoInstallPackageCore(
        'jsonlib', '1.0.0', '/tmp/fpdev-dist-pkg',
        @Harness.GetPackageInfo, @Harness.InstallPackage, @Harness.LogLine));
    Check('InstallPackageCore calls installer once', Harness.PackageInstallCalls = 1,
      'calls=' + IntToStr(Harness.PackageInstallCalls));
    Check('InstallPackageCore forwards name', Harness.LastPackageName = 'jsonlib',
      'name=' + Harness.LastPackageName);
    Check('InstallPackageCore forwards version', Harness.LastPackageVersion = '1.0.0',
      'version=' + Harness.LastPackageVersion);
  finally
    Harness.Free;
  end;
end;

begin
  TestGetBinaryReleaseInfoCore;
  TestGetCrossToolchainInfoCore;
  TestHasPackageCore;
  TestGetPackageInfoCore;
  TestInstallBinaryReleaseCore;
  TestInstallBinaryReleaseCoreLogsMissingInfo;
  TestInstallCrossToolchainCore;
  TestInstallPackageCore;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
