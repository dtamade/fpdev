program test_cross_verifyflow;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  BaseUnix,
{$ENDIF}
  SysUtils, Classes, fpjson,
  fpdev.cross.downloader.downloadflow,
  fpdev.cross.verifyflow,
  test_temp_paths;

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

function CreateVersionScript(const ADir, ABaseName, AFirstLine, ASecondLine: string): string;
var
  Script: TextFile;
begin
  {$IFDEF WINDOWS}
  Result := IncludeTrailingPathDelimiter(ADir) + ABaseName + '.cmd';
  AssignFile(Script, Result);
  Rewrite(Script);
  try
    WriteLn(Script, '@echo off');
    WriteLn(Script, 'echo ', AFirstLine);
    if ASecondLine <> '' then
      WriteLn(Script, 'echo ', ASecondLine);
  finally
    CloseFile(Script);
  end;
  {$ELSE}
  Result := IncludeTrailingPathDelimiter(ADir) + ABaseName;
  AssignFile(Script, Result);
  Rewrite(Script);
  try
    WriteLn(Script, '#!/bin/sh');
    WriteLn(Script, 'echo "', AFirstLine, '"');
    if ASecondLine <> '' then
      WriteLn(Script, 'echo "', ASecondLine, '"');
  finally
    CloseFile(Script);
  end;
  fpchmod(Result, &755);
  {$ENDIF}
end;

procedure TestVerifyCrossBinutilsInstallationCoreCollectsMissingBinaries;
var
  TempRoot: string;
  VerifyResult: TCrossVerificationResult;
begin
  TempRoot := CreateUniqueTempDir('test_cross_verifyflow_missing');
  VerifyResult.MissingBinaries := nil;
  try
    VerifyResult := VerifyCrossBinutilsInstallationCore(TempRoot, 'win64', '1.0.0', 'sha256');
    try
      Check('verifyflow reports missing binaries as failure',
        not VerifyResult.Success,
        'expected verification failure');
      Check('verifyflow collects all missing binaries',
        VerifyResult.MissingBinaries.CommaText = 'x86_64-w64-mingw32-ld,x86_64-w64-mingw32-as,x86_64-w64-mingw32-ar',
        'missing=' + VerifyResult.MissingBinaries.CommaText);
    finally
      VerifyResult.MissingBinaries.Free;
    end;
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestExecuteCrossVersionCheckCoreReturnsFirstLine;
var
  TempRoot: string;
  ScriptPath: string;
begin
  TempRoot := CreateUniqueTempDir('test_cross_verifyflow_version');
  try
    ScriptPath := CreateVersionScript(TempRoot, 'mock-ld', 'GNU ld 2.40', 'secondary line');
    Check('verifyflow version check returns first line only',
      ExecuteCrossVersionCheckCore(ScriptPath) = 'GNU ld 2.40',
      'version=' + ExecuteCrossVersionCheckCore(ScriptPath));
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestUpdateCrossVerificationMetadataCoreCreatesNewMetadata;
var
  TempRoot: string;
  MetaJSON: TJSONObject;
  MetaPath: string;
begin
  TempRoot := CreateUniqueTempDir('test_cross_verifyflow_metadata_new');
  try
    UpdateCrossVerificationMetadataCore(TempRoot, 'win64', '1.0.0', 'abc123', True);
    MetaPath := IncludeTrailingPathDelimiter(TempRoot) + '.fpdev-cross-meta.json';
    Check('verifyflow writes metadata file',
      FileExists(MetaPath),
      'missing ' + MetaPath);

    MetaJSON := LoadCrossMetadataJSONCore(MetaPath);
    try
      Check('verifyflow writes target field',
        MetaJSON.Get('target', '') = 'win64',
        'target=' + MetaJSON.Get('target', ''));
      Check('verifyflow writes verified flag',
        MetaJSON.Objects['binutils'].Booleans['verified'],
        'expected verified=true');
      Check('verifyflow writes verifiedAt field',
        MetaJSON.Objects['binutils'].IndexOfName('verifiedAt') >= 0,
        'missing verifiedAt');
    finally
      MetaJSON.Free;
    end;
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestUpdateCrossVerificationMetadataCoreRecoversFromInvalidJSON;
var
  TempRoot: string;
  MetaPath: string;
  MetaFile: TextFile;
  MetaJSON: TJSONObject;
begin
  TempRoot := CreateUniqueTempDir('test_cross_verifyflow_metadata_invalid');
  try
    MetaPath := IncludeTrailingPathDelimiter(TempRoot) + '.fpdev-cross-meta.json';
    AssignFile(MetaFile, MetaPath);
    Rewrite(MetaFile);
    try
      Write(MetaFile, 'not json');
    finally
      CloseFile(MetaFile);
    end;

    UpdateCrossVerificationMetadataCore(TempRoot, 'linux64', '2.0.0', 'def456', True);
    MetaJSON := LoadCrossMetadataJSONCore(MetaPath);
    try
      Check('verifyflow recreates valid json after invalid metadata',
        MetaJSON.Get('target', '') = 'linux64',
        'target=' + MetaJSON.Get('target', ''));
      Check('verifyflow rewrites binutils version after invalid metadata',
        MetaJSON.Objects['binutils'].Get('version', '') = '2.0.0',
        'version=' + MetaJSON.Objects['binutils'].Get('version', ''));
    finally
      MetaJSON.Free;
    end;
  finally
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestVerifyCrossBinutilsInstallationCoreCollectsMissingBinaries;
  TestExecuteCrossVersionCheckCoreReturnsFirstLine;
  TestUpdateCrossVerificationMetadataCoreCreatesNewMetadata;
  TestUpdateCrossVerificationMetadataCoreRecoversFromInvalidJSON;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
