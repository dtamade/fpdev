program test_build_cache_migrationbackup;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.cache.migrationbackup;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  GTempPathSequence: Int64 = 0;

function BuildTempMetaPath(const APrefix: string): string;
begin
  Inc(GTempPathSequence);
  Result := IncludeTrailingPathDelimiter(GetTempDir(False))
    + APrefix + '-' + IntToStr(GetTickCount64) + '-'
    + IntToStr(GTempPathSequence) + '.meta';
end;

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

procedure WriteTextFile(const AFilePath, AText: string);
var
  F: TextFile;
begin
  AssignFile(F, AFilePath);
  Rewrite(F);
  Write(F, AText);
  CloseFile(F);
end;

function ReadTextFile(const AFilePath: string): string;
var
  F: TextFile;
  S: string;
begin
  S := '';
  AssignFile(F, AFilePath);
  Reset(F);
  while not EOF(F) do
  begin
    ReadLn(F, Result);
    if not EOF(F) then
      S := S + Result + LineEnding
    else
      S := S + Result;
  end;
  CloseFile(F);
  Result := S;
end;

procedure TestBackupPathSuffix;
begin
  AssertEquals('/tmp/fpc-3.2.1.meta.bak',
    BuildCacheGetMetaBackupPath('/tmp/fpc-3.2.1.meta'),
    'backup path appends .bak suffix');
end;

procedure TestBuildTempMetaPathUsesSystemTempAndUniqueSuffix;
var
  FirstPath: string;
  SecondPath: string;
  TempRoot: string;
begin
  FirstPath := BuildTempMetaPath('fpdev-migrate');
  SecondPath := BuildTempMetaPath('fpdev-migrate');
  TempRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));

  AssertTrue(Pos(TempRoot, ExpandFileName(FirstPath)) = 1,
    'temp migration meta path uses system temp root');
  AssertTrue(FirstPath <> SecondPath, 'temp migration meta path is unique');
end;

procedure TestFinalizeMetaMigrationRenamesFile;
var
  OldMetaPath: string;
  BackupPath: string;
begin
  OldMetaPath := BuildTempMetaPath('fpdev-migrate-old');
  BackupPath := BuildCacheGetMetaBackupPath(OldMetaPath);
  WriteTextFile(OldMetaPath, 'version=3.2.1');
  DeleteFile(BackupPath);

  AssertTrue(BuildCacheFinalizeMetaMigration(OldMetaPath),
    'existing old meta is renamed to backup');
  AssertTrue(not FileExists(OldMetaPath), 'old meta is removed after backup');
  AssertTrue(FileExists(BackupPath), 'backup file is created');
  AssertEquals('version=3.2.1', ReadTextFile(BackupPath), 'backup keeps original contents');

  DeleteFile(BackupPath);
end;

procedure TestFinalizeMetaMigrationOverwritesExistingBackup;
var
  OldMetaPath: string;
  BackupPath: string;
begin
  OldMetaPath := BuildTempMetaPath('fpdev-migrate-overwrite');
  BackupPath := BuildCacheGetMetaBackupPath(OldMetaPath);
  WriteTextFile(OldMetaPath, 'new-content');
  WriteTextFile(BackupPath, 'old-content');

  AssertTrue(BuildCacheFinalizeMetaMigration(OldMetaPath),
    'existing backup is replaced during migration');
  AssertEquals('new-content', ReadTextFile(BackupPath),
    'backup contains latest old-meta content');

  DeleteFile(BackupPath);
end;

begin
  TestBuildTempMetaPathUsesSystemTempAndUniqueSuffix;
  TestBackupPathSuffix;
  TestFinalizeMetaMigrationRenamesFile;
  TestFinalizeMetaMigrationOverwritesExistingBackup;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
