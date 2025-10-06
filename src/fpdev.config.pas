unit fpdev.config;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.config

JSON配置管理系统 - 向后兼容层

本单元保留旧的 TFPDevConfigManager API 以实现向后兼容。
新代码请使用 fpdev.config.interfaces 和 fpdev.config.managers 中的新架构。

## 声明

转发或者用于自己项目请保留本项目的版权声明,谢谢.

fafafaStudio
Email:dtamade@gmail.com
QQ群:685403987  QQ:179033731

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config.interfaces,
  fpdev.config.managers;

type
  // 重新导出类型定义以保持向后兼容
  TToolchainType = fpdev.config.interfaces.TToolchainType;
  TToolchainInfo = fpdev.config.interfaces.TToolchainInfo;
  TLazarusInfo = fpdev.config.interfaces.TLazarusInfo;
  TCrossTarget = fpdev.config.interfaces.TCrossTarget;
  TFPDevSettings = fpdev.config.interfaces.TFPDevSettings;

const
  // 向后兼容常量
  ttRelease = fpdev.config.interfaces.ttRelease;
  ttDevelopment = fpdev.config.interfaces.ttDevelopment;
  ttCustom = fpdev.config.interfaces.ttCustom;

type
  { TFPDevConfigManager - 向后兼容包装类 }
  { 已废弃：请使用 TConfigManager 和相关接口 }
  TFPDevConfigManager = class
  private
    FConfigManager: IConfigManager;  // 使用接口引用，自动管理生命周期
    function GetModified: Boolean;
    function GetConfigPath: string;

  public
    constructor Create(const AConfigPath: string = '');
    destructor Destroy; override;

    function LoadConfig: Boolean;
    function SaveConfig: Boolean;
    function GetDefaultConfigPath: string;
    function CreateDefaultConfig: Boolean;

    // 工具链管理
    function AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
    function RemoveToolchain(const AName: string): Boolean;
    function GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
    function SetDefaultToolchain(const AName: string): Boolean;
    function GetDefaultToolchain: string;
    function ListToolchains: TStringArray;

    // Lazarus管理
    function AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;
    function RemoveLazarusVersion(const AName: string): Boolean;
    function GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;
    function SetDefaultLazarusVersion(const AName: string): Boolean;
    function GetDefaultLazarusVersion: string;
    function ListLazarusVersions: TStringArray;

    // 交叉编译目标管理
    function AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
    function RemoveCrossTarget(const ATarget: string): Boolean;
    function GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
    function ListCrossTargets: TStringArray;

    // 仓库管理
    function AddRepository(const AName, AURL: string): Boolean;
    function RemoveRepository(const AName: string): Boolean;
    function GetRepository(const AName: string): string;
    function HasRepository(const AName: string): Boolean;
    function GetDefaultRepository: string;
    function ListRepositories: TStringArray;

    // 设置管理
    function GetSettings: TFPDevSettings;
    function SetSettings(const ASettings: TFPDevSettings): Boolean;

    // 属性
    property ConfigPath: string read GetConfigPath;
    property Modified: Boolean read GetModified;
  end;

implementation

{ TFPDevConfigManager }

constructor TFPDevConfigManager.Create(const AConfigPath: string);
begin
  inherited Create;
  FConfigManager := TConfigManager.Create(AConfigPath) as IConfigManager;
end;

destructor TFPDevConfigManager.Destroy;
begin
  // 显式清空接口引用，触发引用计数清理
  FConfigManager := nil;
  inherited Destroy;
end;

function TFPDevConfigManager.GetModified: Boolean;
begin
  Result := FConfigManager.IsModified;
end;

function TFPDevConfigManager.GetConfigPath: string;
begin
  Result := FConfigManager.GetConfigPath;
end;

function TFPDevConfigManager.GetDefaultConfigPath: string;
begin
  Result := FConfigManager.GetConfigPath;
end;

function TFPDevConfigManager.LoadConfig: Boolean;
begin
  Result := FConfigManager.LoadConfig;
end;

function TFPDevConfigManager.SaveConfig: Boolean;
begin
  Result := FConfigManager.SaveConfig;
end;

function TFPDevConfigManager.CreateDefaultConfig: Boolean;
begin
  Result := FConfigManager.CreateDefaultConfig;
end;

// 工具链管理方法
function TFPDevConfigManager.AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.AddToolchain(AName, AInfo);
end;

function TFPDevConfigManager.RemoveToolchain(const AName: string): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.RemoveToolchain(AName);
end;

function TFPDevConfigManager.GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.GetToolchain(AName, AInfo);
end;

function TFPDevConfigManager.SetDefaultToolchain(const AName: string): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.SetDefaultToolchain(AName);
end;

function TFPDevConfigManager.GetDefaultToolchain: string;
begin
  Result := FConfigManager.GetToolchainManager.GetDefaultToolchain;
end;

function TFPDevConfigManager.ListToolchains: TStringArray;
begin
  Result := FConfigManager.GetToolchainManager.ListToolchains;
end;

// Lazarus管理方法
function TFPDevConfigManager.AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;
begin
  Result := FConfigManager.GetLazarusManager.AddLazarusVersion(AName, AInfo);
end;

function TFPDevConfigManager.RemoveLazarusVersion(const AName: string): Boolean;
begin
  Result := FConfigManager.GetLazarusManager.RemoveLazarusVersion(AName);
end;

function TFPDevConfigManager.GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;
begin
  Result := FConfigManager.GetLazarusManager.GetLazarusVersion(AName, AInfo);
end;

function TFPDevConfigManager.SetDefaultLazarusVersion(const AName: string): Boolean;
begin
  Result := FConfigManager.GetLazarusManager.SetDefaultLazarusVersion(AName);
end;

function TFPDevConfigManager.GetDefaultLazarusVersion: string;
begin
  Result := FConfigManager.GetLazarusManager.GetDefaultLazarusVersion;
end;

function TFPDevConfigManager.ListLazarusVersions: TStringArray;
begin
  Result := FConfigManager.GetLazarusManager.ListLazarusVersions;
end;

// 交叉编译目标管理方法
function TFPDevConfigManager.AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
begin
  Result := FConfigManager.GetCrossTargetManager.AddCrossTarget(ATarget, AInfo);
end;

function TFPDevConfigManager.RemoveCrossTarget(const ATarget: string): Boolean;
begin
  Result := FConfigManager.GetCrossTargetManager.RemoveCrossTarget(ATarget);
end;

function TFPDevConfigManager.GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
begin
  Result := FConfigManager.GetCrossTargetManager.GetCrossTarget(ATarget, AInfo);
end;

function TFPDevConfigManager.ListCrossTargets: TStringArray;
begin
  Result := FConfigManager.GetCrossTargetManager.ListCrossTargets;
end;

// 仓库管理方法
function TFPDevConfigManager.AddRepository(const AName, AURL: string): Boolean;
begin
  Result := FConfigManager.GetRepositoryManager.AddRepository(AName, AURL);
end;

function TFPDevConfigManager.RemoveRepository(const AName: string): Boolean;
begin
  Result := FConfigManager.GetRepositoryManager.RemoveRepository(AName);
end;

function TFPDevConfigManager.GetRepository(const AName: string): string;
begin
  Result := FConfigManager.GetRepositoryManager.GetRepository(AName);
end;

function TFPDevConfigManager.HasRepository(const AName: string): Boolean;
begin
  Result := FConfigManager.GetRepositoryManager.HasRepository(AName);
end;

function TFPDevConfigManager.GetDefaultRepository: string;
begin
  Result := FConfigManager.GetRepositoryManager.GetDefaultRepository;
end;

function TFPDevConfigManager.ListRepositories: TStringArray;
begin
  Result := FConfigManager.GetRepositoryManager.ListRepositories;
end;

// 设置管理方法
function TFPDevConfigManager.GetSettings: TFPDevSettings;
begin
  Result := FConfigManager.GetSettingsManager.GetSettings;
end;

function TFPDevConfigManager.SetSettings(const ASettings: TFPDevSettings): Boolean;
begin
  Result := FConfigManager.GetSettingsManager.SetSettings(ASettings);
end;

end.
