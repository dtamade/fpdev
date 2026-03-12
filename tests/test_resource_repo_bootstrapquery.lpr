program test_resource_repo_bootstrapquery;

{$mode objfpc}{$H+}

uses
  SysUtils, fpjson,
  fpdev.resource.repo.types,
  fpdev.resource.repo.bootstrapquery;

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

function BuildBootstrapManifest: TJSONObject;
begin
  Result := TJSONObject.Create([
    'bootstrap_compilers', TJSONObject.Create([
      '3.2.2', TJSONObject.Create([
        'path', 'bootstrap/3.2.2',
        'platforms', TJSONObject.Create([
          'linux-x86_64', TJSONObject.Create([
            'url', 'https://example.invalid/fpc-3.2.2.tar.gz',
            'mirrors', TJSONArray.Create(['https://mirror1.invalid/fpc-3.2.2.tar.gz', 'https://mirror2.invalid/fpc-3.2.2.tar.gz']),
            'executable', 'bin/ppcx64',
            'sha256', 'abc123',
            'size', Int64(123456),
            'tested', True
          ]),
          'win64-x86_64', TJSONObject.Create([
            'archive', 'bootstrap/win64/fpc.zip',
            'executable', 'bin/ppcx64.exe',
            'sha256', 'def456',
            'size', Int64(654321),
            'tested', False
          ])
        ])
      ])
    ])
  ]);
end;

procedure TestHasBootstrapCompiler;
var
  Manifest: TJSONObject;
begin
  Manifest := BuildBootstrapManifest;
  try
    Check('HasBootstrapCompiler detects existing platform',
      ResourceRepoHasBootstrapCompiler(Manifest, '3.2.2', 'linux-x86_64'));
    Check('HasBootstrapCompiler rejects missing platform',
      not ResourceRepoHasBootstrapCompiler(Manifest, '3.2.2', 'darwin-aarch64'));
    Check('HasBootstrapCompiler rejects missing version',
      not ResourceRepoHasBootstrapCompiler(Manifest, '9.9.9', 'linux-x86_64'));
    Check('HasBootstrapCompiler rejects nil manifest',
      not ResourceRepoHasBootstrapCompiler(nil, '3.2.2', 'linux-x86_64'));
  finally
    Manifest.Free;
  end;
end;

procedure TestGetBootstrapCompilerInfoV2;
var
  Manifest: TJSONObject;
  Info: TPlatformInfo;
begin
  Manifest := BuildBootstrapManifest;
  try
    Check('GetBootstrapCompilerInfo parses v2 manifest',
      ResourceRepoGetBootstrapCompilerInfo(Manifest, '3.2.2', 'linux-x86_64', Info));
    Check('GetBootstrapCompilerInfo keeps path', Info.Path = 'bootstrap/3.2.2', 'path=' + Info.Path);
    Check('GetBootstrapCompilerInfo keeps url', Info.URL = 'https://example.invalid/fpc-3.2.2.tar.gz', 'url=' + Info.URL);
    Check('GetBootstrapCompilerInfo parses mirrors', Length(Info.Mirrors) = 2, 'mirrors=' + IntToStr(Length(Info.Mirrors)));
    Check('GetBootstrapCompilerInfo keeps executable', Info.Executable = 'bin/ppcx64', 'exe=' + Info.Executable);
    Check('GetBootstrapCompilerInfo keeps sha', Info.SHA256 = 'abc123', 'sha=' + Info.SHA256);
    Check('GetBootstrapCompilerInfo keeps size', Info.Size = 123456, 'size=' + IntToStr(Info.Size));
    Check('GetBootstrapCompilerInfo keeps tested flag', Info.Tested, 'tested should be true');
  finally
    Manifest.Free;
  end;
end;

procedure TestGetBootstrapCompilerInfoLegacyArchiveFallback;
var
  Manifest: TJSONObject;
  Info: TPlatformInfo;
begin
  Manifest := BuildBootstrapManifest;
  try
    Check('GetBootstrapCompilerInfo parses legacy archive fallback',
      ResourceRepoGetBootstrapCompilerInfo(Manifest, '3.2.2', 'win64-x86_64', Info));
    Check('GetBootstrapCompilerInfo uses archive when url missing',
      (Info.URL = '') and (Info.Path = 'bootstrap/win64/fpc.zip'),
      'url=' + Info.URL + ' path=' + Info.Path);
    Check('GetBootstrapCompilerInfo keeps windows executable',
      Info.Executable = 'bin/ppcx64.exe', 'exe=' + Info.Executable);
    Check('GetBootstrapCompilerInfo defaults mirrors empty',
      Length(Info.Mirrors) = 0, 'mirrors=' + IntToStr(Length(Info.Mirrors)));
  finally
    Manifest.Free;
  end;
end;

procedure TestGetBootstrapCompilerInfoRejectsMissingEntries;
var
  Manifest: TJSONObject;
  Info: TPlatformInfo;
begin
  Manifest := BuildBootstrapManifest;
  try
    Check('GetBootstrapCompilerInfo rejects missing platform',
      not ResourceRepoGetBootstrapCompilerInfo(Manifest, '3.2.2', 'missing', Info));
    Check('GetBootstrapCompilerInfo rejects missing version',
      not ResourceRepoGetBootstrapCompilerInfo(Manifest, '0.0.0', 'linux-x86_64', Info));
    Check('GetBootstrapCompilerInfo rejects nil manifest',
      not ResourceRepoGetBootstrapCompilerInfo(nil, '3.2.2', 'linux-x86_64', Info));
  finally
    Manifest.Free;
  end;
end;

procedure TestGetBootstrapExecutablePath;
var
  PathValue: string;
begin
  PathValue := ResourceRepoGetBootstrapExecutablePath('/tmp/fpdev-repo', 'bin/ppcx64');
  Check('GetBootstrapExecutablePath joins root and executable',
    PathValue = '/tmp/fpdev-repo' + PathDelim + 'bin/ppcx64',
    'path=' + PathValue);
  Check('GetBootstrapExecutablePath rejects empty executable',
    ResourceRepoGetBootstrapExecutablePath('/tmp/fpdev-repo', '') = '');
end;

begin
  TestHasBootstrapCompiler;
  TestGetBootstrapCompilerInfoV2;
  TestGetBootstrapCompilerInfoLegacyArchiveFallback;
  TestGetBootstrapCompilerInfoRejectsMissingEntries;
  TestGetBootstrapExecutablePath;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
