program test_resource_repo_cross;

{$mode objfpc}{$H+}

uses
  SysUtils, fpjson, fpdev.resource.repo.cross;

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

function BuildCrossManifest: TJSONObject;
var
  Manifest, CrossToolchains, ArmTarget, HostPlatforms, LinuxHost: TJSONObject;
  WinTarget, WinHosts, WinLinuxHost: TJSONObject;
begin
  Manifest := TJSONObject.Create;
  CrossToolchains := TJSONObject.Create;

  // arm-linux target
  ArmTarget := TJSONObject.Create;
  ArmTarget.Add('display_name', 'ARM Linux');
  ArmTarget.Add('cpu', 'arm');
  ArmTarget.Add('os', 'linux');
  ArmTarget.Add('binutils_prefix', 'arm-linux-gnueabihf-');

  HostPlatforms := TJSONObject.Create;
  LinuxHost := TJSONObject.Create;
  LinuxHost.Add('binutils', 'arm-binutils-linux.tar.gz');
  LinuxHost.Add('libs', 'arm-libs-linux.tar.gz');
  LinuxHost.Add('binutils_sha256', 'binsha256');
  LinuxHost.Add('libs_sha256', 'libsha256');
  HostPlatforms.Add('x86_64-linux', LinuxHost);

  ArmTarget.Add('host_platforms', HostPlatforms);
  CrossToolchains.Add('arm-linux', ArmTarget);

  // win64 target
  WinTarget := TJSONObject.Create;
  WinTarget.Add('display_name', 'Windows 64-bit');
  WinTarget.Add('cpu', 'x86_64');
  WinTarget.Add('os', 'win64');
  WinTarget.Add('binutils_prefix', 'x86_64-w64-mingw32-');

  WinHosts := TJSONObject.Create;
  WinLinuxHost := TJSONObject.Create;
  WinLinuxHost.Add('binutils', 'win64-binutils.tar.gz');
  WinLinuxHost.Add('libs', 'win64-libs.tar.gz');
  WinLinuxHost.Add('binutils_sha256', 'winbinsha');
  WinLinuxHost.Add('libs_sha256', 'winlibsha');
  WinHosts.Add('x86_64-linux', WinLinuxHost);

  WinTarget.Add('host_platforms', WinHosts);
  CrossToolchains.Add('x86_64-win64', WinTarget);

  Manifest.Add('cross_toolchains', CrossToolchains);

  Result := Manifest;
end;

{ --- HasCrossToolchain tests --- }

procedure TestHasCrossToolchainTrue;
var
  Manifest: TJSONObject;
begin
  Manifest := BuildCrossManifest;
  try
    Check(ResourceRepoHasCrossToolchain(Manifest, 'arm-linux', 'x86_64-linux') = True,
          'HasCross: existing target+host -> True');
  finally
    Manifest.Free;
  end;
end;

procedure TestHasCrossToolchainMissingTarget;
var
  Manifest: TJSONObject;
begin
  Manifest := BuildCrossManifest;
  try
    Check(ResourceRepoHasCrossToolchain(Manifest, 'mips-linux', 'x86_64-linux') = False,
          'HasCross: missing target -> False');
  finally
    Manifest.Free;
  end;
end;

procedure TestHasCrossToolchainMissingHost;
var
  Manifest: TJSONObject;
begin
  Manifest := BuildCrossManifest;
  try
    Check(ResourceRepoHasCrossToolchain(Manifest, 'arm-linux', 'aarch64-darwin') = False,
          'HasCross: missing host platform -> False');
  finally
    Manifest.Free;
  end;
end;

procedure TestHasCrossToolchainNilManifest;
begin
  Check(ResourceRepoHasCrossToolchain(nil, 'arm-linux', 'x86_64-linux') = False,
        'HasCross: nil manifest -> False');
end;

procedure TestHasCrossToolchainEmptyManifest;
var
  Manifest: TJSONObject;
begin
  Manifest := TJSONObject.Create;
  try
    Check(ResourceRepoHasCrossToolchain(Manifest, 'arm-linux', 'x86_64-linux') = False,
          'HasCross: empty manifest -> False');
  finally
    Manifest.Free;
  end;
end;

{ --- GetCrossToolchainInfo tests --- }

procedure TestGetCrossInfoComplete;
var
  Manifest: TJSONObject;
  Info: TResourceRepoCrossInfo;
begin
  Manifest := BuildCrossManifest;
  try
    Check(ResourceRepoGetCrossToolchainInfo(Manifest, 'arm-linux', 'x86_64-linux', Info) = True,
          'GetCrossInfo: returns True');
    Check(Info.TargetName = 'arm-linux', 'GetCrossInfo: TargetName correct');
    Check(Info.DisplayName = 'ARM Linux', 'GetCrossInfo: DisplayName correct');
    Check(Info.CPU = 'arm', 'GetCrossInfo: CPU correct');
    Check(Info.OS = 'linux', 'GetCrossInfo: OS correct');
    Check(Info.BinutilsPrefix = 'arm-linux-gnueabihf-', 'GetCrossInfo: BinutilsPrefix correct');
    Check(Info.BinutilsArchive = 'arm-binutils-linux.tar.gz', 'GetCrossInfo: BinutilsArchive correct');
    Check(Info.LibsArchive = 'arm-libs-linux.tar.gz', 'GetCrossInfo: LibsArchive correct');
    Check(Info.BinutilsSHA256 = 'binsha256', 'GetCrossInfo: BinutilsSHA256 correct');
    Check(Info.LibsSHA256 = 'libsha256', 'GetCrossInfo: LibsSHA256 correct');
  finally
    Manifest.Free;
  end;
end;

procedure TestGetCrossInfoWin64;
var
  Manifest: TJSONObject;
  Info: TResourceRepoCrossInfo;
begin
  Manifest := BuildCrossManifest;
  try
    Check(ResourceRepoGetCrossToolchainInfo(Manifest, 'x86_64-win64', 'x86_64-linux', Info) = True,
          'GetCrossInfo Win64: returns True');
    Check(Info.DisplayName = 'Windows 64-bit', 'GetCrossInfo Win64: DisplayName correct');
    Check(Info.CPU = 'x86_64', 'GetCrossInfo Win64: CPU correct');
    Check(Info.OS = 'win64', 'GetCrossInfo Win64: OS correct');
  finally
    Manifest.Free;
  end;
end;

procedure TestGetCrossInfoMissingTarget;
var
  Manifest: TJSONObject;
  Info: TResourceRepoCrossInfo;
begin
  Manifest := BuildCrossManifest;
  try
    Check(ResourceRepoGetCrossToolchainInfo(Manifest, 'mips-linux', 'x86_64-linux', Info) = False,
          'GetCrossInfo: missing target -> False');
  finally
    Manifest.Free;
  end;
end;

procedure TestGetCrossInfoMissingHost;
var
  Manifest: TJSONObject;
  Info: TResourceRepoCrossInfo;
begin
  Manifest := BuildCrossManifest;
  try
    Check(ResourceRepoGetCrossToolchainInfo(Manifest, 'arm-linux', 'aarch64-darwin', Info) = False,
          'GetCrossInfo: missing host -> False');
  finally
    Manifest.Free;
  end;
end;

procedure TestGetCrossInfoNil;
var
  Info: TResourceRepoCrossInfo;
begin
  Check(ResourceRepoGetCrossToolchainInfo(nil, 'arm-linux', 'x86_64-linux', Info) = False,
        'GetCrossInfo: nil manifest -> False');
end;

procedure TestGetCrossInfoEmptyManifest;
var
  Manifest: TJSONObject;
  Info: TResourceRepoCrossInfo;
begin
  Manifest := TJSONObject.Create;
  try
    Check(ResourceRepoGetCrossToolchainInfo(Manifest, 'arm-linux', 'x86_64-linux', Info) = False,
          'GetCrossInfo: empty manifest -> False');
  finally
    Manifest.Free;
  end;
end;

{ --- ListCrossTargets tests --- }

procedure TestListCrossTargets;
var
  Manifest: TJSONObject;
  Targets: TStringArray;
begin
  Manifest := BuildCrossManifest;
  try
    Targets := ResourceRepoListCrossTargets(Manifest);
    Check(Length(Targets) = 2, 'ListTargets: returns 2 targets');
    // Order depends on JSON object insertion order
    Check((Targets[0] = 'arm-linux') or (Targets[0] = 'x86_64-win64'),
          'ListTargets: first target valid');
    Check((Targets[1] = 'arm-linux') or (Targets[1] = 'x86_64-win64'),
          'ListTargets: second target valid');
    Check(Targets[0] <> Targets[1], 'ListTargets: targets are different');
  finally
    Manifest.Free;
  end;
end;

procedure TestListCrossTargetsNil;
var
  Targets: TStringArray;
begin
  Targets := ResourceRepoListCrossTargets(nil);
  Check(Length(Targets) = 0, 'ListTargets: nil manifest -> empty');
end;

procedure TestListCrossTargetsEmpty;
var
  Manifest: TJSONObject;
  Targets: TStringArray;
begin
  Manifest := TJSONObject.Create;
  try
    Targets := ResourceRepoListCrossTargets(Manifest);
    Check(Length(Targets) = 0, 'ListTargets: empty manifest -> empty');
  finally
    Manifest.Free;
  end;
end;

begin
  WriteLn('=== Resource Repo Cross Unit Tests ===');
  WriteLn;

  TestHasCrossToolchainTrue;
  TestHasCrossToolchainMissingTarget;
  TestHasCrossToolchainMissingHost;
  TestHasCrossToolchainNilManifest;
  TestHasCrossToolchainEmptyManifest;
  TestGetCrossInfoComplete;
  TestGetCrossInfoWin64;
  TestGetCrossInfoMissingTarget;
  TestGetCrossInfoMissingHost;
  TestGetCrossInfoNil;
  TestGetCrossInfoEmptyManifest;
  TestListCrossTargets;
  TestListCrossTargetsNil;
  TestListCrossTargetsEmpty;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
