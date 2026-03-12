unit fpdev.build.cache.binaryrestore;

{$mode objfpc}{$H+}

interface

type
  TBuildCacheBinaryRestorePlan = record
    FileExt: string;
    ArchivePath: string;
    TarFlags: string;
  end;

function BuildCacheBuildBinaryRestorePlan(const ACacheDirWithDelim, AArtifactKey,
  AStoredFileExt: string): TBuildCacheBinaryRestorePlan;

implementation

function BuildCacheBuildBinaryRestorePlan(const ACacheDirWithDelim, AArtifactKey,
  AStoredFileExt: string): TBuildCacheBinaryRestorePlan;
begin
  Result.FileExt := AStoredFileExt;
  if Result.FileExt = '' then
    Result.FileExt := '.tar.gz';

  Result.ArchivePath := ACacheDirWithDelim + AArtifactKey + '-binary' + Result.FileExt;

  if (Result.FileExt = '.tar.gz') or (Result.FileExt = '.tgz') then
    Result.TarFlags := '-xzf'
  else if Result.FileExt = '.tar' then
    Result.TarFlags := '-xf'
  else
    Result.TarFlags := '-xzf';
end;

end.
