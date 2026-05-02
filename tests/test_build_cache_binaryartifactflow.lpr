program test_build_cache_binaryartifactflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.cache.types,
  fpdev.build.cache.binaryartifactflow,
  test_temp_paths;

type
  TBinaryArtifactFlowHarness = class
  public
    FileCopyResult: Boolean;
    FileCopyCalls: Integer;
    RunCommandResult: Boolean;
    RunCommandCalls: Integer;
    VerifyResult: Boolean;
    VerifyCalls: Integer;
    LastCopySource: string;
    LastCopyDest: string;
    LastVerifyPath: string;
    LastVerifyHash: string;
    LastCmd: string;
    LastArg0: string;
    LastArg1: string;
    LastArg2: string;
    LastArg3: string;
    procedure Reset;
    function FileCopy(const ASource, ADest: string): Boolean;
    function RunCommand(const ACmd: string; const AArgs: array of string;
      const AWorkDir: string): Boolean;
    function VerifyArtifact(const AArchivePath, AExpectedHash: string): Boolean;
  end;

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

procedure WriteTextFile(const APath, AContent: string);
var
  Lines: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  Lines := TStringList.Create;
  try
    Lines.Text := AContent;
    Lines.SaveToFile(APath);
  finally
    Lines.Free;
  end;
end;

procedure TBinaryArtifactFlowHarness.Reset;
begin
  FileCopyResult := True;
  FileCopyCalls := 0;
  RunCommandResult := True;
  RunCommandCalls := 0;
  VerifyResult := True;
  VerifyCalls := 0;
  LastCopySource := '';
  LastCopyDest := '';
  LastVerifyPath := '';
  LastVerifyHash := '';
  LastCmd := '';
  LastArg0 := '';
  LastArg1 := '';
  LastArg2 := '';
  LastArg3 := '';
end;

function TBinaryArtifactFlowHarness.FileCopy(
  const ASource, ADest: string
): Boolean;
var
  InputStream: TFileStream;
  OutputStream: TFileStream;
begin
  Inc(FileCopyCalls);
  LastCopySource := ASource;
  LastCopyDest := ADest;

  if not FileCopyResult then
    Exit(False);

  ForceDirectories(ExtractFileDir(ADest));
  InputStream := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
  try
    OutputStream := TFileStream.Create(ADest, fmCreate);
    try
      OutputStream.CopyFrom(InputStream, 0);
    finally
      OutputStream.Free;
    end;
  finally
    InputStream.Free;
  end;
  Result := True;
end;

function TBinaryArtifactFlowHarness.RunCommand(
  const ACmd: string;
  const AArgs: array of string;
  const AWorkDir: string
): Boolean;
begin
  Inc(RunCommandCalls);
  LastCmd := ACmd;
  if Length(AArgs) > 0 then LastArg0 := AArgs[0] else LastArg0 := '';
  if Length(AArgs) > 1 then LastArg1 := AArgs[1] else LastArg1 := '';
  if Length(AArgs) > 2 then LastArg2 := AArgs[2] else LastArg2 := '';
  if Length(AArgs) > 3 then LastArg3 := AArgs[3] else LastArg3 := '';
  Result := RunCommandResult;
end;

function TBinaryArtifactFlowHarness.VerifyArtifact(
  const AArchivePath, AExpectedHash: string
): Boolean;
begin
  Inc(VerifyCalls);
  LastVerifyPath := AArchivePath;
  LastVerifyHash := AExpectedHash;
  Result := VerifyResult;
end;

procedure TestSaveBinaryArtifactCopiesArchiveAndWritesMeta;
var
  TempRoot: string;
  Harness: TBinaryArtifactFlowHarness;
  DownloadedFile: string;
  CacheDir: string;
  CacheDirWithDelim: string;
  ArtifactKey: string;
  Info: TArtifactInfo;
begin
  TempRoot := CreateUniqueTempDir('test_build_cache_binaryartifactflow_save');
  Harness := TBinaryArtifactFlowHarness.Create;
  try
    Check('binaryartifactflow temp root uses shared temp helper',
      PathUsesSystemTempRoot(TempRoot), TempRoot);

    Harness.Reset;
    CacheDir := IncludeTrailingPathDelimiter(TempRoot) + 'cache';
    CacheDirWithDelim := IncludeTrailingPathDelimiter(CacheDir);
    DownloadedFile := IncludeTrailingPathDelimiter(TempRoot) + 'downloads/fpc.tar.gz';
    ArtifactKey := 'fpc-3.2.2-x86_64-linux';
    WriteTextFile(DownloadedFile, 'binary-archive');

    Check('binaryartifactflow save copies archive and writes meta',
      BuildCacheSaveBinaryArtifactCore(
        '3.2.2',
        DownloadedFile,
        CacheDir,
        CacheDirWithDelim,
        ArtifactKey,
        'x86_64',
        'linux',
        'provided-hash',
        @Harness.FileCopy
      ),
      'save should succeed');
    Check('binaryartifactflow save uses file copy callback',
      Harness.FileCopyCalls = 1,
      IntToStr(Harness.FileCopyCalls));
    Check('binaryartifactflow save writes binary meta',
      BuildCacheGetBinaryArtifactInfoCore(CacheDirWithDelim, ArtifactKey, Info),
      'expected binary info success');
    Check('binaryartifactflow info preserves binary source type',
      Info.SourceType = 'binary',
      Info.SourceType);
    Check('binaryartifactflow info preserves provided hash',
      Info.SHA256 = 'provided-hash',
      Info.SHA256);
    Check('binaryartifactflow info rebuilds binary archive path',
      Pos('-binary.tar.gz', Info.ArchivePath) > 0,
      Info.ArchivePath);
  finally
    Harness.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestRestoreBinaryArtifactUsesVerifyAndTarCallbacks;
var
  TempRoot: string;
  Harness: TBinaryArtifactFlowHarness;
  CacheDirWithDelim: string;
  ArtifactKey: string;
  ArchivePath: string;
  DestPath: string;
  Info: TArtifactInfo;
  CountAsMiss: Boolean;
begin
  TempRoot := CreateUniqueTempDir('test_build_cache_binaryartifactflow_restore');
  Harness := TBinaryArtifactFlowHarness.Create;
  try
    Check('binaryartifactflow restore temp root uses shared temp helper',
      PathUsesSystemTempRoot(TempRoot), TempRoot);

    Harness.Reset;
    CacheDirWithDelim := IncludeTrailingPathDelimiter(TempRoot) + 'cache' + PathDelim;
    ForceDirectories(ExcludeTrailingPathDelimiter(CacheDirWithDelim));
    ArtifactKey := 'fpc-3.2.2-x86_64-linux';
    ArchivePath := CacheDirWithDelim + ArtifactKey + '-binary.tar.gz';
    DestPath := IncludeTrailingPathDelimiter(TempRoot) + 'restore';
    WriteTextFile(ArchivePath, 'binary-archive');
    Initialize(Info);
    Info.Version := '3.2.2';
    Info.SourceType := 'binary';
    Info.SHA256 := 'expected-hash';
    Info.FileExt := '.tar.gz';

    CountAsMiss := False;
    Check('binaryartifactflow restore runs verify and tar callbacks',
      BuildCacheRestoreBinaryArtifactCore(
        '3.2.2',
        DestPath,
        CacheDirWithDelim,
        ArtifactKey,
        Info,
        True,
        @Harness.VerifyArtifact,
        @Harness.RunCommand,
        CountAsMiss
      ),
      'restore should succeed');
    Check('binaryartifactflow restore verifies before extraction',
      Harness.VerifyCalls = 1,
      IntToStr(Harness.VerifyCalls));
    Check('binaryartifactflow restore uses tar extraction',
      Harness.LastCmd = 'tar',
      Harness.LastCmd);
    Check('binaryartifactflow restore uses xzf flags',
      Harness.LastArg0 = '-xzf',
      Harness.LastArg0);
    Check('binaryartifactflow restore does not count success as miss',
      not CountAsMiss,
      'counted as miss');
  finally
    Harness.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestRestoreBinaryArtifactVerificationFailureCountsAsMiss;
var
  TempRoot: string;
  Harness: TBinaryArtifactFlowHarness;
  CacheDirWithDelim: string;
  ArtifactKey: string;
  ArchivePath: string;
  DestPath: string;
  Info: TArtifactInfo;
  CountAsMiss: Boolean;
begin
  TempRoot := CreateUniqueTempDir('test_build_cache_binaryartifactflow_verifyfail');
  Harness := TBinaryArtifactFlowHarness.Create;
  try
    Check('binaryartifactflow verifyfail temp root uses shared temp helper',
      PathUsesSystemTempRoot(TempRoot), TempRoot);

    Harness.Reset;
    Harness.VerifyResult := False;
    CacheDirWithDelim := IncludeTrailingPathDelimiter(TempRoot) + 'cache' + PathDelim;
    ForceDirectories(ExcludeTrailingPathDelimiter(CacheDirWithDelim));
    ArtifactKey := 'fpc-3.2.3-x86_64-linux';
    ArchivePath := CacheDirWithDelim + ArtifactKey + '-binary.tar.gz';
    DestPath := IncludeTrailingPathDelimiter(TempRoot) + 'restore';
    WriteTextFile(ArchivePath, 'binary-archive');
    Initialize(Info);
    Info.Version := '3.2.3';
    Info.SourceType := 'binary';
    Info.SHA256 := 'expected-hash';
    Info.FileExt := '.tar.gz';

    CountAsMiss := False;
    Check('binaryartifactflow restore fails on verification mismatch',
      not BuildCacheRestoreBinaryArtifactCore(
        '3.2.3',
        DestPath,
        CacheDirWithDelim,
        ArtifactKey,
        Info,
        True,
        @Harness.VerifyArtifact,
        @Harness.RunCommand,
        CountAsMiss
      ),
      'restore should fail');
    Check('binaryartifactflow mismatch still calls verify callback',
      Harness.VerifyCalls = 1,
      IntToStr(Harness.VerifyCalls));
    Check('binaryartifactflow mismatch does not invoke extraction callback',
      Harness.RunCommandCalls = 0,
      IntToStr(Harness.RunCommandCalls));
    Check('binaryartifactflow mismatch counts as miss-worthy failure',
      CountAsMiss,
      'miss flag not raised');
  finally
    Harness.Free;
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestSaveBinaryArtifactCopiesArchiveAndWritesMeta;
  TestRestoreBinaryArtifactUsesVerifyAndTarCallbacks;
  TestRestoreBinaryArtifactVerificationFailureCountsAsMiss;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
