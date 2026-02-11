unit fpdev.config.interfaces;

{
配置管理接口定义

将原来的 TFPDevConfigManager 拆分为多个职责单一的管理器接口：
- IToolchainManager: 工具链管理
- ILazarusManager: Lazarus版本管理
- ICrossTargetManager: 交叉编译目标管理
- IRepositoryManager: 仓库管理
- ISettingsManager: 设置管理
- IConfigManager: 总入口，协调各个子管理器
}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson;

type
  { IConfigChangeNotifier - 配置修改通知接口 }
  { 子管理器通过此接口通知父管理器配置已修改 }
  IConfigChangeNotifier = interface
    ['{91A2B3C4-D5E6-789F-0ABC-DEF123456789}']
    procedure NotifyConfigChanged;
  end;

  // 工具链类型
  TToolchainType = (ttRelease, ttDevelopment, ttCustom);

  // 工具链信息
  TToolchainInfo = record
    ToolchainType: TToolchainType;
    Version: string;
    InstallPath: string;
    SourceURL: string;
    Branch: string;
    Installed: Boolean;
    InstallDate: TDateTime;
  end;

  // Lazarus信息
  TLazarusInfo = record
    Version: string;
    FPCVersion: string;
    InstallPath: string;
    SourceURL: string;
    Branch: string;
    Installed: Boolean;
  end;

  // Cross-compilation target
  TCrossTarget = record
    Enabled: Boolean;
    BinutilsPath: string;
    LibrariesPath: string;
    // Extended fields for cross-compilation build engine (optional, backward-compatible)
    CPU: string;               // arm, aarch64, i386, x86_64
    OS: string;                // linux, win32, win64, darwin, android
    SubArch: string;           // armv6, armv7, armv8
    ABI: string;               // eabi, eabihf, musl
    BinutilsPrefix: string;    // arm-linux-gnueabihf-
    CrossOpt: string;          // -CfVFPV3 -CaEABIHF
  end;

  // FPDev设置
  TFPDevSettings = record
    AutoUpdate: Boolean;
    ParallelJobs: Integer;
    KeepSources: Boolean;
    InstallRoot: string;
    DefaultRepo: string;
    // Mirror configuration for fpdev-repo
    Mirror: string;           // 'auto', 'github', 'gitee', or custom URL
    CustomRepoURL: string;    // Custom repository URL (highest priority)
  end;

  { IToolchainManager - 工具链管理接口 }
  IToolchainManager = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
    function RemoveToolchain(const AName: string): Boolean;
    function GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
    function SetDefaultToolchain(const AName: string): Boolean;
    function GetDefaultToolchain: string;
    function ListToolchains: TStringArray;
    
    // 序列化接口
    procedure LoadFromJSON(AToolchains: TJSONObject; const ADefaultToolchain: string);
    procedure SaveToJSON(out AToolchains: TJSONObject; out ADefaultToolchain: string);
    procedure Clear;
  end;

  { ILazarusManager - Lazarus版本管理接口 }
  ILazarusManager = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    function AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;
    function RemoveLazarusVersion(const AName: string): Boolean;
    function GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;
    function SetDefaultLazarusVersion(const AName: string): Boolean;
    function GetDefaultLazarusVersion: string;
    function ListLazarusVersions: TStringArray;
    
    // 序列化接口
    procedure LoadFromJSON(ALazarus: TJSONObject);
    procedure SaveToJSON(out ALazarus: TJSONObject);
    procedure Clear;
  end;

  { ICrossTargetManager - 交叉编译目标管理接口 }
  ICrossTargetManager = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    function AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
    function RemoveCrossTarget(const ATarget: string): Boolean;
    function GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
    function ListCrossTargets: TStringArray;
    
    // 序列化接口
    procedure LoadFromJSON(ACrossTargets: TJSONObject);
    procedure SaveToJSON(out ACrossTargets: TJSONObject);
    procedure Clear;
  end;

  { IRepositoryManager - 仓库管理接口 }
  IRepositoryManager = interface
    ['{D4E5F6A7-B8C9-0123-DEF1-234567890123}']
    function AddRepository(const AName, AURL: string): Boolean;
    function RemoveRepository(const AName: string): Boolean;
    function GetRepository(const AName: string): string;
    function HasRepository(const AName: string): Boolean;
    function GetDefaultRepository: string;
    function ListRepositories: TStringArray;
    
    // 序列化接口
    procedure LoadFromJSON(ARepos: TJSONObject; const ADefaultRepo: string);
    procedure SaveToJSON(out ARepos: TJSONObject; out ADefaultRepo: string);
    procedure Clear;
  end;

  { ISettingsManager - 设置管理接口 }
  ISettingsManager = interface
    ['{E5F6A7B8-C9D0-1234-EF12-345678901234}']
    function GetSettings: TFPDevSettings;
    function SetSettings(const ASettings: TFPDevSettings): Boolean;
    
    // 序列化接口
    procedure LoadFromJSON(ASettings: TJSONObject);
    procedure SaveToJSON(out ASettings: TJSONObject);
  end;

  { IConfigManager - 配置管理总入口接口 }
  IConfigManager = interface
    ['{F6A7B8C9-D0E1-2345-F123-456789012345}']
    // 基础配置操作
    function LoadConfig: Boolean;
    function SaveConfig: Boolean;
    function GetConfigPath: string;
    function CreateDefaultConfig: Boolean;
    
    // 访问子管理器
    function GetToolchainManager: IToolchainManager;
    function GetLazarusManager: ILazarusManager;
    function GetCrossTargetManager: ICrossTargetManager;
    function GetRepositoryManager: IRepositoryManager;
    function GetSettingsManager: ISettingsManager;
    
    // 配置状态
    function IsModified: Boolean;
  end;

implementation

end.
