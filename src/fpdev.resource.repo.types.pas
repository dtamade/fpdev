unit fpdev.resource.repo.types;

{
================================================================================
  fpdev.resource.repo.types - Resource Repository Type Definitions
================================================================================

  Contains core type definitions for the resource repository system:
  - TMirrorInfo: Mirror information record
  - TResourceRepoConfig: Repository configuration
  - TPlatformInfo: Platform-specific download information
  - TCrossToolchainInfo: Cross-compilation toolchain metadata
  - TPackageInfo: Package metadata (resource repo specific)

  Extracted from fpdev.resource.repo.pas for better modularity.

  Note: This TPackageInfo is different from fpdev.package.types.TPackageInfo
  as it represents resource repository package metadata, not installed packages.

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  { TMirrorInfo - Mirror information }
  TMirrorInfo = record
    Name: string;             // Mirror name
    URL: string;              // Mirror URL
    Region: string;           // Region (china, europe, us)
    Priority: Integer;        // Priority (lower = higher priority)
  end;

  TMirrorArray = array of TMirrorInfo;

  { TResourceRepoConfig - Repository configuration }
  TResourceRepoConfig = record
    URL: string;              // Main repository URL
    Mirrors: array of string; // Mirror URL list (simple format, backward compatible)
    MirrorInfos: TMirrorArray; // Detailed mirror information
    LocalPath: string;        // Local clone path
    Branch: string;           // Branch to use (default: main)
    AutoUpdate: Boolean;      // Auto-update enabled
    UpdateIntervalHours: Integer;  // Update interval in hours
  end;

  { TPlatformInfo - Platform-specific download info (manifest v2.0) }
  TPlatformInfo = record
    // v2.0 fields (recommended)
    URL: string;              // Main download URL (full HTTP/HTTPS URL)
    Mirrors: array of string; // Backup mirror URLs (failover)
    // v1.0 fields (backward compatible)
    Path: string;             // Resource path in repository (when URL is empty)
    // Common fields
    Executable: string;       // Executable relative path (bootstrap only)
    SHA256: string;           // Checksum
    Size: Int64;              // Size in bytes
    Tested: Boolean;          // Whether tested
  end;

  { TCrossToolchainInfo - Cross-compilation toolchain info }
  TCrossToolchainInfo = record
    TargetName: string;       // Target name (e.g., win32, linux-arm)
    DisplayName: string;      // Display name
    CPU: string;              // Target CPU
    OS: string;               // Target OS
    BinutilsPrefix: string;   // Binutils prefix
    BinutilsArchive: string;  // Binutils archive path
    LibsArchive: string;      // Libraries archive path
    BinutilsSHA256: string;   // Binutils checksum
    LibsSHA256: string;       // Libraries checksum
  end;

  { TRepoPackageInfo - Package info from resource repository
    Named differently to avoid confusion with fpdev.package.types.TPackageInfo }
  TRepoPackageInfo = record
    Name: string;             // Package name
    Version: string;          // Version
    Description: string;      // Description
    Category: string;         // Category
    Archive: string;          // Archive path
    SHA256: string;           // Checksum
    Dependencies: array of string;  // Dependencies
    FPCMinVersion: string;    // Minimum FPC version
  end;

  { Helper functions }
  function EmptyMirrorInfo: TMirrorInfo;
  function EmptyResourceRepoConfig: TResourceRepoConfig;
  function EmptyPlatformInfo: TPlatformInfo;
  function EmptyCrossToolchainInfo: TCrossToolchainInfo;
  function EmptyRepoPackageInfo: TRepoPackageInfo;

  function MirrorInfoToString(const AInfo: TMirrorInfo): string;
  function PlatformInfoToString(const AInfo: TPlatformInfo): string;

implementation

function EmptyMirrorInfo: TMirrorInfo;
begin
  Result := Default(TMirrorInfo);
end;

function EmptyResourceRepoConfig: TResourceRepoConfig;
begin
  Result := Default(TResourceRepoConfig);
  Result.Branch := 'main';
  Result.AutoUpdate := True;
  Result.UpdateIntervalHours := 24;
end;

function EmptyPlatformInfo: TPlatformInfo;
begin
  Result := Default(TPlatformInfo);
end;

function EmptyCrossToolchainInfo: TCrossToolchainInfo;
begin
  Result := Default(TCrossToolchainInfo);
end;

function EmptyRepoPackageInfo: TRepoPackageInfo;
begin
  Result := Default(TRepoPackageInfo);
end;

function MirrorInfoToString(const AInfo: TMirrorInfo): string;
begin
  Result := Format('%s (%s) [%s] priority=%d',
    [AInfo.Name, AInfo.URL, AInfo.Region, AInfo.Priority]);
end;

function PlatformInfoToString(const AInfo: TPlatformInfo): string;
begin
  if AInfo.URL <> '' then
    Result := Format('URL: %s, Size: %d', [AInfo.URL, AInfo.Size])
  else
    Result := Format('Path: %s, Size: %d', [AInfo.Path, AInfo.Size]);
end;

end.
