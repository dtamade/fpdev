unit fpdev.build.cache.sourceartifactflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types;

type
  TBuildCacheRunCommandCallback = function(const ACmd: string;
    const AArgs: array of string; const AWorkDir: string): Boolean of object;
  TBuildCacheVerifyArtifactCallback = function(const AArchivePath,
    AExpectedHash: string): Boolean of object;

function BuildCacheSaveSourceArtifactsCore(
  const AVersion, AInstallPath, ACacheDir, AArchivePath, AMetaPath,
    ACPU, AOS: string;
  ARunCommand: TBuildCacheRunCommandCallback
): Boolean;
function BuildCacheRestoreSourceArtifactsCore(
  const AArchivePath, ADestPath: string;
  ARunCommand: TBuildCacheRunCommandCallback
): Boolean; overload;
function BuildCacheRestoreSourceArtifactsCore(
  const AArchivePath, ADestPath, AVersion: string;
  const AInfo: TArtifactInfo;
  AVerifyOnRestore: Boolean;
  AVerifyArtifact: TBuildCacheVerifyArtifactCallback;
  ARunCommand: TBuildCacheRunCommandCallback
): Boolean; overload;
function BuildCacheGetSourceArtifactInfoCore(
  const AMetaPath, AArchivePath: string;
  out AInfo: TArtifactInfo
): Boolean;
function BuildCacheDeleteSourceArtifactsCore(
  const AArchivePath, AMetaPath: string
): Boolean;

implementation

uses
  SysUtils,
  fpdev.build.cache.artifactmeta,
  fpdev.build.cache.deletefiles,
  fpdev.build.cache.oldmeta,
  fpdev.build.cache.sourceinfo;

function BuildCacheSaveSourceArtifactsCore(
  const AVersion, AInstallPath, ACacheDir, AArchivePath, AMetaPath,
    ACPU, AOS: string;
  ARunCommand: TBuildCacheRunCommandCallback
): Boolean;
var
  SR: TSearchRec;
  ArchiveSize: Int64;
begin
  Result := False;

  if not DirectoryExists(AInstallPath) then
    Exit;

  if not Assigned(ARunCommand) then
    Exit;

  ForceDirectories(ACacheDir);

  {$IFDEF MSWINDOWS}
  if not ARunCommand('tar', ['--version'], '') then
  begin
    Result := ARunCommand('7z',
      ['a', '-ttar', AArchivePath + '.tar', AInstallPath + PathDelim + '*'], '');
    if Result then
      Result := ARunCommand('7z',
        ['a', '-tgzip', AArchivePath, AArchivePath + '.tar'], '');
    if FileExists(AArchivePath + '.tar') then
      DeleteFile(AArchivePath + '.tar');
  end
  else
    Result := ARunCommand('tar', ['-czf', AArchivePath, '-C', AInstallPath, '.'], '');
  {$ELSE}
  Result := ARunCommand('tar', ['-czf', AArchivePath, '-C', AInstallPath, '.'], '');
  {$ENDIF}

  if not Result then
    Exit;

  ArchiveSize := 0;
  if FindFirst(AArchivePath, faAnyFile, SR) = 0 then
  begin
    try
      ArchiveSize := SR.Size;
    finally
      FindClose(SR);
    end;
  end;

  BuildCacheSaveOldMeta(AMetaPath, AVersion, ACPU, AOS, AInstallPath, ArchiveSize);
  Result := True;
end;

function BuildCacheRestoreSourceArtifactsCore(
  const AArchivePath, ADestPath: string;
  ARunCommand: TBuildCacheRunCommandCallback
): Boolean;
var
  EmptyInfo: TArtifactInfo;
begin
  Initialize(EmptyInfo);
  Result := BuildCacheRestoreSourceArtifactsCore(
    AArchivePath,
    ADestPath,
    '',
    EmptyInfo,
    False,
    nil,
    ARunCommand
  );
end;

function BuildCacheRestoreSourceArtifactsCore(
  const AArchivePath, ADestPath, AVersion: string;
  const AInfo: TArtifactInfo;
  AVerifyOnRestore: Boolean;
  AVerifyArtifact: TBuildCacheVerifyArtifactCallback;
  ARunCommand: TBuildCacheRunCommandCallback
): Boolean;
begin
  Result := False;

  if not FileExists(AArchivePath) then
    Exit;

  if not Assigned(ARunCommand) then
    Exit;

  if AVerifyOnRestore and (AInfo.SHA256 <> '') and Assigned(AVerifyArtifact) then
    if not AVerifyArtifact(AArchivePath, AInfo.SHA256) then
    begin
      WriteLn('Error: Cache integrity verification failed for ', AVersion);
      WriteLn('  Expected SHA256: ', AInfo.SHA256);
      WriteLn('  The cached artifact may be corrupted or tampered with.');
      Exit(False);
    end;

  ForceDirectories(ADestPath);

  {$IFDEF MSWINDOWS}
  if not ARunCommand('tar', ['--version'], '') then
    Result := ARunCommand('7z', ['x', '-y', '-o' + ADestPath, AArchivePath], '')
  else
    Result := ARunCommand('tar', ['-xzf', AArchivePath, '-C', ADestPath], '');
  {$ELSE}
  Result := ARunCommand('tar', ['-xzf', AArchivePath, '-C', ADestPath], '');
  {$ENDIF}
end;

function BuildCacheGetSourceArtifactInfoCore(
  const AMetaPath, AArchivePath: string;
  out AInfo: TArtifactInfo
): Boolean;
var
  OldInfo: TOldMetaArtifactInfo;
begin
  Result := False;
  Initialize(AInfo);

  if not BuildCacheLoadOldMeta(AMetaPath, OldInfo) then
    Exit;

  AInfo := BuildCacheCreateSourceArtifactInfo(AArchivePath, OldInfo);
  Result := AInfo.Version <> '';
end;

function BuildCacheDeleteSourceArtifactsCore(
  const AArchivePath, AMetaPath: string
): Boolean;
begin
  Result := BuildCacheDeleteArtifactFiles(AArchivePath, AMetaPath);
end;

end.
