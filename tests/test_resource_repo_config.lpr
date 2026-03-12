program test_resource_repo_config;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.constants,
  fpdev.resource.repo.types,
  fpdev.resource.repo.config;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('PASS: ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('FAIL: ', AMessage);
  end;
end;

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual,
    AMessage + ' (expected: ' + AExpected + ', got: ' + AActual + ')');
end;

procedure TestCurrentPlatformIsKnown;
var
  Platform: string;
begin
  Platform := ResourceRepoGetCurrentPlatform;
  AssertTrue(Platform <> '', 'platform helper returns non-empty value');
  AssertTrue(Pos('-', Platform) > 0, 'platform helper returns os-arch style identifier');
end;

procedure TestCreateDefaultConfig;
var
  Config: TResourceRepoConfig;
begin
  Config := ResourceRepoCreateDefaultConfig;
  AssertEquals(FPDEV_REPO_URL, Config.URL, 'default config uses primary repo URL');
  AssertTrue(Length(Config.Mirrors) = 1, 'default config exposes one fallback mirror');
  AssertEquals(FPDEV_REPO_MIRROR, Config.Mirrors[0], 'default config uses default mirror');
  AssertEquals('main', Config.Branch, 'default config uses main branch');
end;

procedure TestCreateConfigWithMirrorSelection;
var
  Config: TResourceRepoConfig;
begin
  Config := ResourceRepoCreateConfigWithMirror('github');
  AssertEquals(FPDEV_REPO_GITHUB, Config.URL, 'github mirror becomes primary URL');
  AssertEquals(FPDEV_REPO_GITEE, Config.Mirrors[0], 'gitee becomes github fallback');

  Config := ResourceRepoCreateConfigWithMirror('gitee');
  AssertEquals(FPDEV_REPO_GITEE, Config.URL, 'gitee mirror becomes primary URL');
  AssertEquals(FPDEV_REPO_GITHUB, Config.Mirrors[0], 'github becomes gitee fallback');
end;

procedure TestCreateConfigWithCustomURL;
var
  Config: TResourceRepoConfig;
begin
  Config := ResourceRepoCreateConfigWithMirror('github', 'https://custom.example/repo.git');
  AssertEquals('https://custom.example/repo.git', Config.URL, 'custom URL overrides mirror selection');
  AssertTrue(Length(Config.Mirrors) = 0, 'custom URL clears fallback mirrors');
end;

begin
  TestCurrentPlatformIsKnown;
  TestCreateDefaultConfig;
  TestCreateConfigWithMirrorSelection;
  TestCreateConfigWithCustomURL;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
