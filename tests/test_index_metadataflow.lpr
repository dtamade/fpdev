program test_index_metadataflow;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpjson, jsonparser,
  fpdev.index.metadataflow;

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

function ParseJSONObject(const AJSON: string): TJSONObject;
var
  Parser: TJSONParser;
begin
  Parser := TJSONParser.Create(AJSON, []);
  try
    Result := Parser.Parse as TJSONObject;
  finally
    Parser.Free;
  end;
end;

procedure TestRawURLConversion;
begin
  Check('index metadataflow converts GitHub repo URL to raw URL',
    BuildIndexRawURLCore(
      'https://github.com/dtamade/fpdev-fpc.git',
      'main',
      'manifest.json'
    ) = 'https://raw.githubusercontent.com/dtamade/fpdev-fpc/main/manifest.json');
  Check('index metadataflow converts Gitee repo URL to raw URL',
    BuildIndexRawURLCore(
      'https://gitee.com/dtamade/fpdev-fpc.git',
      'main',
      'manifest.json'
    ) = 'https://gitee.com/dtamade/fpdev-fpc/raw/main/manifest.json');
end;

procedure TestMirrorSelection;
var
  PrimaryURL: string;
  FallbackURL: string;
begin
  PrimaryURL := SelectIndexPrimaryURLCore(
    'china',
    'https://github.com/dtamade/fpdev-index.git',
    'https://gitee.com/dtamade/fpdev-index.git',
    'index.json'
  );
  Check('index metadataflow prefers gitee for china mirror preference',
    PrimaryURL = 'https://gitee.com/dtamade/fpdev-index/raw/main/index.json',
    PrimaryURL);

  FallbackURL := SelectIndexFallbackURLCore(
    'china',
    'https://github.com/dtamade/fpdev-index.git',
    'https://gitee.com/dtamade/fpdev-index.git',
    PrimaryURL,
    'index.json'
  );
  Check('index metadataflow keeps github as fallback when gitee is primary',
    FallbackURL = 'https://raw.githubusercontent.com/dtamade/fpdev-index/main/index.json',
    FallbackURL);

  PrimaryURL := SelectIndexPrimaryURLCore(
    'auto',
    'https://github.com/dtamade/fpdev-index.git',
    'https://gitee.com/dtamade/fpdev-index.git',
    'index.json'
  );
  Check('index metadataflow prefers github for auto mirror preference',
    PrimaryURL = 'https://raw.githubusercontent.com/dtamade/fpdev-index/main/index.json',
    PrimaryURL);

  FallbackURL := SelectIndexFallbackURLCore(
    'auto',
    'https://github.com/dtamade/fpdev-index.git',
    'https://gitee.com/dtamade/fpdev-index.git',
    PrimaryURL,
    'index.json'
  );
  Check('index metadataflow keeps gitee as fallback when github is primary',
    FallbackURL = 'https://gitee.com/dtamade/fpdev-index/raw/main/index.json',
    FallbackURL);
end;

procedure TestRepoMetadataExtraction;
var
  IndexData: TJSONObject;
  Name: string;
  GitHubURL: string;
  GiteeURL: string;
begin
  IndexData := ParseJSONObject(
    '{' +
    '"repositories":{' +
      '"bootstrap":{"name":"fpdev-bootstrap","github":"https://github.com/dtamade/fpdev-bootstrap.git","gitee":"https://gitee.com/dtamade/fpdev-bootstrap.git"},' +
      '"fpc":{"name":"fpdev-fpc","github":"https://github.com/dtamade/fpdev-fpc.git","gitee":"https://gitee.com/dtamade/fpdev-fpc.git"}' +
    '}' +
    '}'
  );
  try
    Check('index metadataflow extracts repo metadata from repositories section',
      TryGetIndexRepoMetadataCore(IndexData, 'fpc', Name, GitHubURL, GiteeURL),
      'expected repo metadata');
    Check('index metadataflow repo metadata keeps repo name',
      Name = 'fpdev-fpc',
      Name);
    Check('index metadataflow repo metadata keeps github URL',
      GitHubURL = 'https://github.com/dtamade/fpdev-fpc.git',
      GitHubURL);
    Check('index metadataflow repo metadata keeps gitee URL',
      GiteeURL = 'https://gitee.com/dtamade/fpdev-fpc.git',
      GiteeURL);
  finally
    IndexData.Free;
  end;
end;

procedure TestChannelMetadataExtraction;
var
  IndexData: TJSONObject;
  BootstrapRef: string;
  FPCRef: string;
  LazarusRef: string;
  CrossRef: string;
begin
  IndexData := ParseJSONObject(
    '{' +
    '"channels":{' +
      '"stable":{' +
        '"bootstrap":{"ref":"3.2.2"},' +
        '"fpc":{"ref":"3.2.2"},' +
        '"lazarus":{"ref":"3.6"},' +
        '"cross":{"ref":"main"}' +
      '}' +
    '}' +
    '}'
  );
  try
    Check('index metadataflow extracts channel metadata from channels section',
      TryGetIndexChannelMetadataCore(
        IndexData,
        'stable',
        BootstrapRef,
        FPCRef,
        LazarusRef,
        CrossRef
      ),
      'expected channel metadata');
    Check('index metadataflow channel bootstrap ref',
      BootstrapRef = '3.2.2',
      BootstrapRef);
    Check('index metadataflow channel fpc ref',
      FPCRef = '3.2.2',
      FPCRef);
    Check('index metadataflow channel lazarus ref',
      LazarusRef = '3.6',
      LazarusRef);
    Check('index metadataflow channel cross ref',
      CrossRef = 'main',
      CrossRef);
  finally
    IndexData.Free;
  end;
end;

begin
  TestRawURLConversion;
  TestMirrorSelection;
  TestRepoMetadataExtraction;
  TestChannelMetadataExtraction;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
