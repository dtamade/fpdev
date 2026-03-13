unit fpdev.config.managers;

{
================================================================================
  fpdev.config.managers - Configuration Manager Implementations
================================================================================

  This unit provides the concrete implementations of the configuration
  management system for FPDev. It splits the original TFPDevConfigManager
  into multiple single-responsibility managers following the SOLID principles.

  Sub-managers:
    - TToolchainManager: FPC toolchain version management
    - TLazarusManager: Lazarus IDE version management
    - TCrossTargetManager: Cross-compilation target management
    - TRepositoryManager: Git repository URL management
    - TSettingsManager: Application settings management
    - TConfigManager: Central coordinator for all sub-managers

  Usage:
    Config := TConfigManager.Create(GetConfigPath);
    Config.LoadConfig;
    ToolchainMgr := Config.GetToolchainManager;
    // No need to Free - interface reference counting handles cleanup

  Author: fafafaStudio
  Email: dtamade@gmail.com
  QQ Group: 685403987  QQ: 179033731
================================================================================
}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  fpdev.config.core,
  fpdev.config.repositories,
  fpdev.config.settings,
  fpdev.config.toolchains,
  fpdev.config.crosstargets,
  fpdev.config.lazarus;

function GetDefaultConfigPathOverride: string;
procedure SetDefaultConfigPathOverride(const AConfigPath: string);
procedure ClearDefaultConfigPathOverride;

type
  TConfigChangeNotifier = fpdev.config.core.TConfigChangeNotifier;

  TRepositoryManager = fpdev.config.repositories.TRepositoryManager;

  TSettingsManager = fpdev.config.settings.TSettingsManager;

  TToolchainManager = fpdev.config.toolchains.TToolchainManager;

  TLazarusManager = fpdev.config.lazarus.TLazarusManager;

  TCrossTargetManager = fpdev.config.crosstargets.TCrossTargetManager;

  TConfigManager = fpdev.config.core.TConfigManager;

implementation

function GetDefaultConfigPathOverride: string;
begin
  Result := fpdev.config.core.GetDefaultConfigPathOverride;
end;

procedure SetDefaultConfigPathOverride(const AConfigPath: string);
begin
  fpdev.config.core.SetDefaultConfigPathOverride(AConfigPath);
end;

procedure ClearDefaultConfigPathOverride;
begin
  fpdev.config.core.ClearDefaultConfigPathOverride;
end;

end.
