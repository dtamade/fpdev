program test_package_verify;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes,
  fpdev.cmd.package.verify, fpdev.hash;

var
  Passed, Failed: Integer;
  TempRoot: string;

procedure Check(ACondition: Boolean; const AMsg: string);
begin
  if ACondition then
  begin
    Inc(Passed);
    WriteLn('PASS: ', AMsg);
  end
  else
  begin
    Inc(Failed);
    WriteLn('FAIL: ', AMsg);
  end;
end;

procedure WriteFile(const APath, AContent: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Text := AContent;
    SL.SaveToFile(APath);
  finally
    SL.Free;
  end;
end;

function MakeTempPkgDir(const AName: string): string;
begin
  Result := TempRoot + AName + PathDelim;
  ForceDirectories(Result);
end;

// ---- VerifyInstalledPackageCore tests ----

procedure TestVerify_ValidPackage;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_ValidPackage --');
  Dir := MakeTempPkgDir('valid_pkg');
  WriteFile(Dir + 'package.json',
    '{"name":"mylib","version":"1.0.0","files":["src/main.pas"]}');
  ForceDirectories(Dir + 'src');
  WriteFile(Dir + 'src' + PathDelim + 'main.pas', 'unit main; end.');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsValid, 'Valid package status');
  Check(R.PackageName = 'mylib', 'Package name extracted');
  Check(R.Version = '1.0.0', 'Version extracted');
  Check(Length(R.MissingFiles) = 0, 'No missing files');
end;

procedure TestVerify_NoPackageJson;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_NoPackageJson --');
  Dir := MakeTempPkgDir('no_json');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsMetadataError, 'Missing package.json = MetadataError');
end;

procedure TestVerify_InvalidJson;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_InvalidJson --');
  Dir := MakeTempPkgDir('invalid_json');
  WriteFile(Dir + 'package.json', 'not valid json {{{');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsMetadataError, 'Invalid JSON = MetadataError');
end;

procedure TestVerify_MissingName;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_MissingName --');
  Dir := MakeTempPkgDir('no_name');
  WriteFile(Dir + 'package.json', '{"version":"1.0.0"}');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsMetadataError, 'Missing name = MetadataError');
end;

procedure TestVerify_MissingVersion;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_MissingVersion --');
  Dir := MakeTempPkgDir('no_ver');
  WriteFile(Dir + 'package.json', '{"name":"mylib"}');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsMetadataError, 'Missing version = MetadataError');
end;

procedure TestVerify_MissingFiles;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_MissingFiles --');
  Dir := MakeTempPkgDir('missing_files');
  WriteFile(Dir + 'package.json',
    '{"name":"mylib","version":"1.0.0","files":["src/a.pas","src/b.pas"]}');
  // Only create a.pas, not b.pas
  ForceDirectories(Dir + 'src');
  WriteFile(Dir + 'src' + PathDelim + 'a.pas', 'unit a; end.');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsMissingFiles, 'Missing files status');
  Check(Length(R.MissingFiles) = 1, 'One missing file');
  Check(R.MissingFiles[0] = 'src/b.pas', 'Missing file is src/b.pas');
end;

procedure TestVerify_NoFilesArray;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_NoFilesArray --');
  Dir := MakeTempPkgDir('no_files_array');
  WriteFile(Dir + 'package.json', '{"name":"mylib","version":"1.0.0"}');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsValid, 'No files array = valid (nothing to check)');
end;

procedure TestVerify_EmptyFilesArray;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_EmptyFilesArray --');
  Dir := MakeTempPkgDir('empty_files');
  WriteFile(Dir + 'package.json', '{"name":"mylib","version":"1.0.0","files":[]}');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsValid, 'Empty files array = valid');
end;

procedure TestVerify_JsonArray;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_JsonArray --');
  Dir := MakeTempPkgDir('json_array');
  WriteFile(Dir + 'package.json', '[1,2,3]');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsMetadataError, 'JSON array (not object) = MetadataError');
end;

procedure TestVerify_NonexistentDir;
var
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_NonexistentDir --');
  R := VerifyInstalledPackageCore(TempRoot + 'nonexistent_dir_xyz');
  Check(R.Status = pvsMetadataError, 'Nonexistent dir = MetadataError');
end;

// ---- VerifyPackageChecksumCore tests ----

procedure TestChecksum_Valid;
var
  FilePath, Hash: string;
begin
  WriteLn('-- TestChecksum_Valid --');
  FilePath := TempRoot + 'checksum_test.txt';
  WriteFile(FilePath, 'hello world');
  Hash := SHA256FileHex(FilePath);
  Check(VerifyPackageChecksumCore(FilePath, Hash), 'Valid checksum matches');
end;

procedure TestChecksum_Invalid;
var
  FilePath: string;
begin
  WriteLn('-- TestChecksum_Invalid --');
  FilePath := TempRoot + 'checksum_test2.txt';
  WriteFile(FilePath, 'hello world');
  Check(not VerifyPackageChecksumCore(FilePath, 'badhash'), 'Invalid checksum does not match');
end;

procedure TestChecksum_CaseInsensitive;
var
  FilePath, Hash: string;
begin
  WriteLn('-- TestChecksum_CaseInsensitive --');
  FilePath := TempRoot + 'checksum_case.txt';
  WriteFile(FilePath, 'test data');
  Hash := SHA256FileHex(FilePath);
  Check(VerifyPackageChecksumCore(FilePath, UpperCase(Hash)), 'Upper case hash matches');
  Check(VerifyPackageChecksumCore(FilePath, LowerCase(Hash)), 'Lower case hash matches');
end;

procedure TestChecksum_NonexistentFile;
begin
  WriteLn('-- TestChecksum_NonexistentFile --');
  Check(not VerifyPackageChecksumCore(TempRoot + 'no_such_file.bin', 'anyhash'),
    'Nonexistent file returns false');
end;

// ---- Cleanup ----
procedure Cleanup;
var
  SR: TSearchRec;
  SubDir: string;
begin
  // Simple recursive cleanup
  if FindFirst(TempRoot + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      SubDir := TempRoot + SR.Name;
      if (SR.Attr and faDirectory) <> 0 then
      begin
        // Not recursive cleanup for simplicity, files already cleaned
      end
      else
        DeleteFile(SubDir);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

begin
  Passed := 0;
  Failed := 0;
  TempRoot := GetTempDir + 'fpdev_test_pkg_verify' + PathDelim;
  ForceDirectories(TempRoot);

  WriteLn('');
  WriteLn('=== fpdev.cmd.package.verify Test Suite ===');
  WriteLn('');

  TestVerify_ValidPackage;
  TestVerify_NoPackageJson;
  TestVerify_InvalidJson;
  TestVerify_MissingName;
  TestVerify_MissingVersion;
  TestVerify_MissingFiles;
  TestVerify_NoFilesArray;
  TestVerify_EmptyFilesArray;
  TestVerify_JsonArray;
  TestVerify_NonexistentDir;
  TestChecksum_Valid;
  TestChecksum_Invalid;
  TestChecksum_CaseInsensitive;
  TestChecksum_NonexistentFile;

  Cleanup;

  WriteLn('');
  WriteLn('=== Results ===');
  WriteLn('Passed: ', Passed);
  WriteLn('Failed: ', Failed);
  WriteLn('Total:  ', Passed + Failed);

  if Failed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
