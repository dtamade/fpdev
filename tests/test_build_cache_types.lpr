program test_build_cache_types;

{$mode objfpc}{$H+}

{
================================================================================
  test_build_cache_types - Tests for fpdev.build.cache.types
================================================================================

  Tests the extracted build cache type definitions and helper functions:
  - TBuildStep enum and string conversion
  - Empty record initializers
  - Type field defaults

  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, fpdev.build.cache.types;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Test(const AName: string; ACondition: Boolean);
begin
  Inc(GTestCount);
  if ACondition then
  begin
    Inc(GPassCount);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('[FAIL] ', AName);
  end;
end;

{ TBuildStep Tests }

procedure TestBuildStepToString;
begin
  Test('BuildStepToString bsIdle', BuildStepToString(bsIdle) = 'idle');
  Test('BuildStepToString bsPreflight', BuildStepToString(bsPreflight) = 'preflight');
  Test('BuildStepToString bsCompiler', BuildStepToString(bsCompiler) = 'compiler');
  Test('BuildStepToString bsCompilerInstall', BuildStepToString(bsCompilerInstall) = 'compiler_install');
  Test('BuildStepToString bsRTL', BuildStepToString(bsRTL) = 'rtl');
  Test('BuildStepToString bsRTLInstall', BuildStepToString(bsRTLInstall) = 'rtl_install');
  Test('BuildStepToString bsPackages', BuildStepToString(bsPackages) = 'packages');
  Test('BuildStepToString bsPackagesInstall', BuildStepToString(bsPackagesInstall) = 'packages_install');
  Test('BuildStepToString bsVerify', BuildStepToString(bsVerify) = 'verify');
  Test('BuildStepToString bsComplete', BuildStepToString(bsComplete) = 'complete');
end;

procedure TestStringToBuildStep;
begin
  Test('StringToBuildStep idle', StringToBuildStep('idle') = bsIdle);
  Test('StringToBuildStep preflight', StringToBuildStep('preflight') = bsPreflight);
  Test('StringToBuildStep compiler', StringToBuildStep('compiler') = bsCompiler);
  Test('StringToBuildStep compiler_install', StringToBuildStep('compiler_install') = bsCompilerInstall);
  Test('StringToBuildStep rtl', StringToBuildStep('rtl') = bsRTL);
  Test('StringToBuildStep rtl_install', StringToBuildStep('rtl_install') = bsRTLInstall);
  Test('StringToBuildStep packages', StringToBuildStep('packages') = bsPackages);
  Test('StringToBuildStep packages_install', StringToBuildStep('packages_install') = bsPackagesInstall);
  Test('StringToBuildStep verify', StringToBuildStep('verify') = bsVerify);
  Test('StringToBuildStep complete', StringToBuildStep('complete') = bsComplete);
  Test('StringToBuildStep unknown defaults to idle', StringToBuildStep('unknown') = bsIdle);
  Test('StringToBuildStep case insensitive', StringToBuildStep('COMPLETE') = bsComplete);
end;

procedure TestBuildStepRoundTrip;
var
  Step: TBuildStep;
  Str: string;
begin
  for Step := Low(TBuildStep) to High(TBuildStep) do
  begin
    Str := BuildStepToString(Step);
    Test('RoundTrip ' + Str, StringToBuildStep(Str) = Step);
  end;
end;

procedure TestBuildStepEnumValues;
begin
  Test('bsIdle = 0', Ord(bsIdle) = 0);
  Test('bsPreflight = 1', Ord(bsPreflight) = 1);
  Test('bsCompiler = 2', Ord(bsCompiler) = 2);
  Test('bsComplete = 9', Ord(bsComplete) = 9);
end;

{ Empty record tests }

procedure TestEmptyBuildCacheEntry;
var
  Entry: TBuildCacheEntry;
begin
  Entry := EmptyBuildCacheEntry;
  Test('EmptyBuildCacheEntry Version empty', Entry.Version = '');
  Test('EmptyBuildCacheEntry Revision empty', Entry.Revision = '');
  Test('EmptyBuildCacheEntry BuildTime zero', Entry.BuildTime = 0);
  Test('EmptyBuildCacheEntry CPU empty', Entry.CPU = '');
  Test('EmptyBuildCacheEntry OS empty', Entry.OS = '');
  Test('EmptyBuildCacheEntry CompilerHash empty', Entry.CompilerHash = '');
  Test('EmptyBuildCacheEntry SourceHash empty', Entry.SourceHash = '');
  Test('EmptyBuildCacheEntry Status idle', Entry.Status = bsIdle);
end;

procedure TestEmptyArtifactInfo;
var
  Info: TArtifactInfo;
begin
  Info := EmptyArtifactInfo;
  Test('EmptyArtifactInfo Version empty', Info.Version = '');
  Test('EmptyArtifactInfo CPU empty', Info.CPU = '');
  Test('EmptyArtifactInfo OS empty', Info.OS = '');
  Test('EmptyArtifactInfo ArchivePath empty', Info.ArchivePath = '');
  Test('EmptyArtifactInfo ArchiveSize zero', Info.ArchiveSize = 0);
  Test('EmptyArtifactInfo CreatedAt zero', Info.CreatedAt = 0);
  Test('EmptyArtifactInfo SourcePath empty', Info.SourcePath = '');
  Test('EmptyArtifactInfo SourceType empty', Info.SourceType = '');
  Test('EmptyArtifactInfo SHA256 empty', Info.SHA256 = '');
  Test('EmptyArtifactInfo DownloadURL empty', Info.DownloadURL = '');
  Test('EmptyArtifactInfo FileExt empty', Info.FileExt = '');
  Test('EmptyArtifactInfo AccessCount zero', Info.AccessCount = 0);
  Test('EmptyArtifactInfo LastAccessed zero', Info.LastAccessed = 0);
end;

procedure TestEmptyCacheIndexStats;
var
  Stats: TCacheIndexStats;
begin
  Stats := EmptyCacheIndexStats;
  Test('EmptyCacheIndexStats TotalEntries zero', Stats.TotalEntries = 0);
  Test('EmptyCacheIndexStats TotalSize zero', Stats.TotalSize = 0);
  Test('EmptyCacheIndexStats OldestVersion empty', Stats.OldestVersion = '');
  Test('EmptyCacheIndexStats NewestVersion empty', Stats.NewestVersion = '');
  Test('EmptyCacheIndexStats OldestDate zero', Stats.OldestDate = 0);
  Test('EmptyCacheIndexStats NewestDate zero', Stats.NewestDate = 0);
end;

procedure TestEmptyCacheDetailedStats;
var
  Stats: TCacheDetailedStats;
begin
  Stats := EmptyCacheDetailedStats;
  Test('EmptyCacheDetailedStats TotalEntries zero', Stats.TotalEntries = 0);
  Test('EmptyCacheDetailedStats TotalSize zero', Stats.TotalSize = 0);
  Test('EmptyCacheDetailedStats TotalAccesses zero', Stats.TotalAccesses = 0);
  Test('EmptyCacheDetailedStats AverageEntrySize zero', Stats.AverageEntrySize = 0);
  Test('EmptyCacheDetailedStats MostAccessedVersion empty', Stats.MostAccessedVersion = '');
  Test('EmptyCacheDetailedStats MostAccessedCount zero', Stats.MostAccessedCount = 0);
  Test('EmptyCacheDetailedStats LeastAccessedVersion empty', Stats.LeastAccessedVersion = '');
  Test('EmptyCacheDetailedStats LeastAccessedCount zero', Stats.LeastAccessedCount = 0);
end;

begin
  WriteLn('=== fpdev.build.cache.types Tests ===');
  WriteLn;

  // TBuildStep tests
  TestBuildStepToString;
  TestStringToBuildStep;
  TestBuildStepRoundTrip;
  TestBuildStepEnumValues;

  // Empty record tests
  TestEmptyBuildCacheEntry;
  TestEmptyArtifactInfo;
  TestEmptyCacheIndexStats;
  TestEmptyCacheDetailedStats;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Total:  ', GTestCount);
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);

  if GFailCount > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
