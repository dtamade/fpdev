unit fpdev.build.cache.types;

{
================================================================================
  fpdev.build.cache.types - Build Cache Type Definitions
================================================================================

  Contains core type definitions for the build cache system:
  - TBuildStep: Build stage state machine enum
  - TBuildCacheEntry: Build cache entry record
  - TArtifactInfo: Cached artifact metadata
  - TCacheIndexStats: Basic cache statistics
  - TCacheDetailedStats: Detailed cache statistics with access tracking

  Extracted from fpdev.build.cache.pas for better modularity and reuse.

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  { TBuildStep - Build stage state machine }
  TBuildStep = (
    bsIdle,             // 0 - Idle
    bsPreflight,        // 1 - Preflight check
    bsCompiler,         // 2 - Compiler build
    bsCompilerInstall,  // 3 - Compiler install
    bsRTL,              // 4 - RTL build
    bsRTLInstall,       // 5 - RTL install
    bsPackages,         // 6 - Packages build
    bsPackagesInstall,  // 7 - Packages install
    bsVerify,           // 8 - Verify
    bsComplete          // 9 - Complete
  );

  { TBuildCacheEntry - Build cache entry record }
  TBuildCacheEntry = record
    Version: string;          // FPC version
    Revision: string;         // Git commit hash
    BuildTime: TDateTime;     // Build timestamp
    CPU: string;              // Target CPU
    OS: string;               // Target OS
    CompilerHash: string;     // Compiler SHA256
    SourceHash: string;       // Source key files SHA256
    Status: TBuildStep;       // Build stage reached
  end;

  { TArtifactInfo - Cached artifact metadata }
  TArtifactInfo = record
    Version: string;          // FPC version
    CPU: string;              // Target CPU
    OS: string;               // Target OS
    ArchivePath: string;      // Path to .tar.gz archive
    ArchiveSize: Int64;       // Archive size in bytes
    CreatedAt: TDateTime;     // When cached
    SourcePath: string;       // Original install path
    SourceType: string;       // 'binary' | 'source'
    SHA256: string;           // File checksum
    DownloadURL: string;      // Original download URL
    FileExt: string;          // File extension (.tar or .tar.gz)
    AccessCount: Integer;     // Access count for statistics
    LastAccessed: TDateTime;  // Last access time for LRU
  end;

  { TCacheIndexStats - Cache index statistics }
  TCacheIndexStats = record
    TotalEntries: Integer;    // Number of cached versions
    TotalSize: Int64;         // Total cache size in bytes
    OldestVersion: string;    // Oldest cached version
    NewestVersion: string;    // Newest cached version
    OldestDate: TDateTime;    // Oldest entry date
    NewestDate: TDateTime;    // Newest entry date
  end;

  { TCacheDetailedStats - Detailed cache statistics }
  TCacheDetailedStats = record
    TotalEntries: Integer;       // Number of cached versions
    TotalSize: Int64;            // Total cache size in bytes
    TotalAccesses: Integer;      // Total access count across all entries
    AverageEntrySize: Int64;     // Average entry size in bytes
    MostAccessedVersion: string; // Version with most accesses
    MostAccessedCount: Integer;  // Access count of most accessed version
    LeastAccessedVersion: string;// Version with least accesses
    LeastAccessedCount: Integer; // Access count of least accessed version
  end;

  { Helper functions }
  function BuildStepToString(AStep: TBuildStep): string;
  function StringToBuildStep(const AStr: string): TBuildStep;
  function EmptyBuildCacheEntry: TBuildCacheEntry;
  function EmptyArtifactInfo: TArtifactInfo;
  function EmptyCacheIndexStats: TCacheIndexStats;
  function EmptyCacheDetailedStats: TCacheDetailedStats;

implementation

function BuildStepToString(AStep: TBuildStep): string;
begin
  case AStep of
    bsIdle:            Result := 'idle';
    bsPreflight:       Result := 'preflight';
    bsCompiler:        Result := 'compiler';
    bsCompilerInstall: Result := 'compiler_install';
    bsRTL:             Result := 'rtl';
    bsRTLInstall:      Result := 'rtl_install';
    bsPackages:        Result := 'packages';
    bsPackagesInstall: Result := 'packages_install';
    bsVerify:          Result := 'verify';
    bsComplete:        Result := 'complete';
  else
    Result := 'unknown';
  end;
end;

function StringToBuildStep(const AStr: string): TBuildStep;
var
  LStr: string;
begin
  LStr := LowerCase(AStr);
  if LStr = 'idle' then Result := bsIdle
  else if LStr = 'preflight' then Result := bsPreflight
  else if LStr = 'compiler' then Result := bsCompiler
  else if LStr = 'compiler_install' then Result := bsCompilerInstall
  else if LStr = 'rtl' then Result := bsRTL
  else if LStr = 'rtl_install' then Result := bsRTLInstall
  else if LStr = 'packages' then Result := bsPackages
  else if LStr = 'packages_install' then Result := bsPackagesInstall
  else if LStr = 'verify' then Result := bsVerify
  else if LStr = 'complete' then Result := bsComplete
  else Result := bsIdle;
end;

function EmptyBuildCacheEntry: TBuildCacheEntry;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Version := '';
  Result.Revision := '';
  Result.BuildTime := 0;
  Result.CPU := '';
  Result.OS := '';
  Result.CompilerHash := '';
  Result.SourceHash := '';
  Result.Status := bsIdle;
end;

function EmptyArtifactInfo: TArtifactInfo;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Version := '';
  Result.CPU := '';
  Result.OS := '';
  Result.ArchivePath := '';
  Result.ArchiveSize := 0;
  Result.CreatedAt := 0;
  Result.SourcePath := '';
  Result.SourceType := '';
  Result.SHA256 := '';
  Result.DownloadURL := '';
  Result.FileExt := '';
  Result.AccessCount := 0;
  Result.LastAccessed := 0;
end;

function EmptyCacheIndexStats: TCacheIndexStats;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.TotalEntries := 0;
  Result.TotalSize := 0;
  Result.OldestVersion := '';
  Result.NewestVersion := '';
  Result.OldestDate := 0;
  Result.NewestDate := 0;
end;

function EmptyCacheDetailedStats: TCacheDetailedStats;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.TotalEntries := 0;
  Result.TotalSize := 0;
  Result.TotalAccesses := 0;
  Result.AverageEntrySize := 0;
  Result.MostAccessedVersion := '';
  Result.MostAccessedCount := 0;
  Result.LeastAccessedVersion := '';
  Result.LeastAccessedCount := 0;
end;

end.
