unit fpdev.build.cache.binaryartifactflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types;

type
  TBuildCacheBinaryFileCopyCallback = function(const ASource,
    ADest: string): Boolean of object;
  TBuildCacheBinaryRunCommandCallback = function(const ACmd: string;
    const AArgs: array of string; const AWorkDir: string): Boolean of object;
  TBuildCacheBinaryVerifyArtifactCallback = function(const AArchivePath,
    AExpectedHash: string): Boolean of object;

function BuildCacheSaveBinaryArtifactCore(
  const AVersion, ADownloadedFile, ACacheDir, ACacheDirWithDelim,
    AArtifactKey, ACPU, AOS, AProvidedSHA256: string;
  AFileCopy: TBuildCacheBinaryFileCopyCallback
): Boolean;
function BuildCacheRestoreBinaryArtifactCore(
  const AVersion, ADestPath, ACacheDirWithDelim, AArtifactKey: string;
  const AInfo: TArtifactInfo;
  AVerifyOnRestore: Boolean;
  AVerifyArtifact: TBuildCacheBinaryVerifyArtifactCallback;
  ARunCommand: TBuildCacheBinaryRunCommandCallback;
  out ACountAsMiss: Boolean
): Boolean;
function BuildCacheGetBinaryArtifactInfoCore(
  const ACacheDirWithDelim, AArtifactKey: string;
  out AInfo: TArtifactInfo
): Boolean;

implementation

uses
  SysUtils,
  fpdev.build.cache.binaryinfo,
  fpdev.build.cache.binaryrestore,
  fpdev.build.cache.binarysave,
  fpdev.build.cache.oldmeta;

function BuildCacheSaveBinaryArtifactCore(
  const AVersion, ADownloadedFile, ACacheDir, ACacheDirWithDelim,
    AArtifactKey, ACPU, AOS, AProvidedSHA256: string;
  AFileCopy: TBuildCacheBinaryFileCopyCallback
): Boolean;
var
  ArchiveSize: Int64;
  FileExt: string;
  Paths: TBuildCacheBinaryArtifactPaths;
  SHA256Hash: string;
begin
  Result := False;

  if not FileExists(ADownloadedFile) then
    Exit;

  if not Assigned(AFileCopy) then
    Exit;

  ForceDirectories(ACacheDir);

  FileExt := BuildCacheResolveBinaryFileExt(ADownloadedFile);
  Paths := BuildCacheBuildBinaryArtifactPaths(ACacheDirWithDelim,
    AArtifactKey, FileExt);

  try
    if not AFileCopy(ADownloadedFile, Paths.ArchivePath) then
      Exit;
  except
    on E: Exception do
      Exit;
  end;

  ArchiveSize := BuildCacheReadBinaryArchiveSize(Paths.ArchivePath);
  SHA256Hash := BuildCacheResolveBinarySHA256(AProvidedSHA256,
    Paths.ArchivePath);

  BuildCacheSaveBinaryMeta(Paths.MetaPath, AVersion, ACPU, AOS,
    SHA256Hash, FileExt, ArchiveSize);
  Result := True;
end;

function BuildCacheRestoreBinaryArtifactCore(
  const AVersion, ADestPath, ACacheDirWithDelim, AArtifactKey: string;
  const AInfo: TArtifactInfo;
  AVerifyOnRestore: Boolean;
  AVerifyArtifact: TBuildCacheBinaryVerifyArtifactCallback;
  ARunCommand: TBuildCacheBinaryRunCommandCallback;
  out ACountAsMiss: Boolean
): Boolean;
var
  Plan: TBuildCacheBinaryRestorePlan;
begin
  Result := False;
  ACountAsMiss := False;

  if not Assigned(ARunCommand) then
    Exit;

  Plan := BuildCacheBuildBinaryRestorePlan(ACacheDirWithDelim,
    AArtifactKey, AInfo.FileExt);

  if not FileExists(Plan.ArchivePath) then
    Exit;

  if AVerifyOnRestore and (AInfo.SHA256 <> '') and Assigned(AVerifyArtifact) then
    if not AVerifyArtifact(Plan.ArchivePath, AInfo.SHA256) then
    begin
      WriteLn('Error: Cache integrity verification failed for ', AVersion);
      WriteLn('  Expected SHA256: ', AInfo.SHA256);
      WriteLn('  The cached artifact may be corrupted or tampered with.');
      ACountAsMiss := True;
      Exit(False);
    end;

  ForceDirectories(ADestPath);

  {$IFDEF MSWINDOWS}
  if not ARunCommand('tar', ['--version'], '') then
    Result := ARunCommand('7z',
      ['x', '-y', '-o' + ADestPath, Plan.ArchivePath], '')
  else
    Result := ARunCommand('tar',
      [Plan.TarFlags, Plan.ArchivePath, '-C', ADestPath,
        '--strip-components=1'], '');
  {$ELSE}
  Result := ARunCommand('tar',
    [Plan.TarFlags, Plan.ArchivePath, '-C', ADestPath,
      '--strip-components=1'], '');
  {$ENDIF}

  if not Result then
    ACountAsMiss := True;
end;

function BuildCacheGetBinaryArtifactInfoCore(
  const ACacheDirWithDelim, AArtifactKey: string;
  out AInfo: TArtifactInfo
): Boolean;
var
  BinaryInfo: TBinaryMetaArtifactInfo;
  MetaPath: string;
begin
  Result := False;
  Initialize(AInfo);

  MetaPath := BuildCacheGetBinaryMetaPath(ACacheDirWithDelim, AArtifactKey);
  if not BuildCacheLoadBinaryMeta(MetaPath, BinaryInfo) then
    Exit;

  AInfo := BuildCacheCreateBinaryArtifactInfo(ACacheDirWithDelim,
    AArtifactKey, BinaryInfo);
  Result := AInfo.Version <> '';
end;

end.
