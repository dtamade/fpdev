unit fpdev.build.cache.migrationbackup;

{$mode objfpc}{$H+}

interface

function BuildCacheGetMetaBackupPath(const AOldMetaPath: string): string;
function BuildCacheFinalizeMetaMigration(const AOldMetaPath: string): Boolean;

implementation

uses
  SysUtils;

function BuildCacheGetMetaBackupPath(const AOldMetaPath: string): string;
begin
  Result := AOldMetaPath + '.bak';
end;

function BuildCacheFinalizeMetaMigration(const AOldMetaPath: string): Boolean;
var
  BackupPath: string;
begin
  Result := False;
  if not FileExists(AOldMetaPath) then
    Exit;

  BackupPath := BuildCacheGetMetaBackupPath(AOldMetaPath);
  if FileExists(BackupPath) then
    DeleteFile(BackupPath);

  Result := RenameFile(AOldMetaPath, BackupPath);
end;

end.
