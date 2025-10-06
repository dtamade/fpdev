unit fpdev.config.managers;

{
配置管理器具体实现

将原来的 TFPDevConfigManager 拆分为多个职责单一的管理器：
- TToolchainManager: 工具链管理
- TLazarusManager: Lazarus版本管理  
- TCrossTargetManager: 交叉编译目标管理
- TRepositoryManager: 仓库管理
- TSettingsManager: 设置管理
- TConfigManager: 总入口，协调各个子管理器
}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.config.interfaces, fpdev.utils;

type
  // 前向声明
  TConfigManager = class;

  { TRepositoryManager - 仓库管理实现 }
  TRepositoryManager = class(TInterfacedObject, IRepositoryManager)
  private
    FOwner: TConfigManager;
    FRepositories: TStringList;
    FDefaultRepo: string;
  public
    constructor Create(AOwner: TConfigManager);
    destructor Destroy; override;
    
    // IRepositoryManager 实现
    function AddRepository(const AName, AURL: string): Boolean;
    function RemoveRepository(const AName: string): Boolean;
    function GetRepository(const AName: string): string;
    function HasRepository(const AName: string): Boolean;
    function GetDefaultRepository: string;
    function ListRepositories: TStringArray;
    
    // 内部方法
    procedure Clear;
    procedure LoadFromJSON(ARepos: TJSONObject; const ADefaultRepo: string);
    procedure SaveToJSON(out ARepos: TJSONObject; out ADefaultRepo: string);
  end;

  { TSettingsManager - 设置管理实现 }
  TSettingsManager = class(TInterfacedObject, ISettingsManager)
  private
    FOwner: TConfigManager;
    FSettings: TFPDevSettings;
  public
    constructor Create(AOwner: TConfigManager);
    
    // ISettingsManager 实现
    function GetSettings: TFPDevSettings;
    function SetSettings(const ASettings: TFPDevSettings): Boolean;
    
    // 内部方法
    procedure LoadFromJSON(ASettings: TJSONObject);
    procedure SaveToJSON(out ASettings: TJSONObject);
  end;

  { TToolchainManager - 工具链管理实现 }
  TToolchainManager = class(TInterfacedObject, IToolchainManager)
  private
    FOwner: TConfigManager;
    FToolchains: TStringList;
    FDefaultToolchain: string;
    
    function ToolchainTypeToString(AType: TToolchainType): string;
    function StringToToolchainType(const AStr: string): TToolchainType;
    function ToolchainInfoToJSON(const AInfo: TToolchainInfo): TJSONObject;
    function JSONToToolchainInfo(AJSON: TJSONObject): TToolchainInfo;
  public
    constructor Create(AOwner: TConfigManager);
    destructor Destroy; override;
    
    // IToolchainManager 实现
    function AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
    function RemoveToolchain(const AName: string): Boolean;
    function GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
    function SetDefaultToolchain(const AName: string): Boolean;
    function GetDefaultToolchain: string;
    function ListToolchains: TStringArray;
    
    // 内部方法
    procedure Clear;
    procedure LoadFromJSON(AToolchains: TJSONObject; const ADefaultToolchain: string);
    procedure SaveToJSON(out AToolchains: TJSONObject; out ADefaultToolchain: string);
  end;

  { TLazarusManager - Lazarus版本管理实现 }
  TLazarusManager = class(TInterfacedObject, ILazarusManager)
  private
    FOwner: TConfigManager;
    FVersions: TStringList;
    FDefaultVersion: string;
    
    function LazarusInfoToJSON(const AInfo: TLazarusInfo): TJSONObject;
    function JSONToLazarusInfo(AJSON: TJSONObject): TLazarusInfo;
  public
    constructor Create(AOwner: TConfigManager);
    destructor Destroy; override;
    
    // ILazarusManager 实现
    function AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;
    function RemoveLazarusVersion(const AName: string): Boolean;
    function GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;
    function SetDefaultLazarusVersion(const AName: string): Boolean;
    function GetDefaultLazarusVersion: string;
    function ListLazarusVersions: TStringArray;
    
    // 内部方法
    procedure Clear;
    procedure LoadFromJSON(ALazarus: TJSONObject);
    procedure SaveToJSON(out ALazarus: TJSONObject);
  end;

  { TCrossTargetManager - 交叉编译目标管理实现 }
  TCrossTargetManager = class(TInterfacedObject, ICrossTargetManager)
  private
    FOwner: TConfigManager;
    FCrossTargets: TStringList;
    
    function CrossTargetToJSON(const ATarget: TCrossTarget): TJSONObject;
    function JSONToCrossTarget(AJSON: TJSONObject): TCrossTarget;
  public
    constructor Create(AOwner: TConfigManager);
    destructor Destroy; override;
    
    // ICrossTargetManager 实现
    function AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
    function RemoveCrossTarget(const ATarget: string): Boolean;
    function GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
    function ListCrossTargets: TStringArray;
    
    // 内部方法
    procedure Clear;
    procedure LoadFromJSON(ACrossTargets: TJSONObject);
    procedure SaveToJSON(out ACrossTargets: TJSONObject);
  end;

  { TConfigManager - 配置管理总入口 }
  TConfigManager = class(TInterfacedObject, IConfigManager)
  private
    FConfigPath: string;
    FModified: Boolean;
    FVersion: string;
    
    // 子管理器
    FToolchainManager: TToolchainManager;
    FLazarusManager: TLazarusManager;
    FCrossTargetManager: TCrossTargetManager;
    FRepositoryManager: TRepositoryManager;
    FSettingsManager: TSettingsManager;
    
    function GetDefaultConfigPath: string;
  public
    constructor Create(const AConfigPath: string = '');
    destructor Destroy; override;
    
    // IConfigManager 实现
    function LoadConfig: Boolean;
    function SaveConfig: Boolean;
    function GetConfigPath: string;
    function CreateDefaultConfig: Boolean;
    function GetToolchainManager: IToolchainManager;
    function GetLazarusManager: ILazarusManager;
    function GetCrossTargetManager: ICrossTargetManager;
    function GetRepositoryManager: IRepositoryManager;
    function GetSettingsManager: ISettingsManager;
    function IsModified: Boolean;
    
    // 内部方法 - 供子管理器调用
    procedure SetModified;
  end;

const
  CONFIG_VERSION = '1.0';
  DEFAULT_PARALLEL_JOBS = 4;
  DEFAULT_FPC_REPO = 'https://gitlab.com/freepascal.org/fpc/source.git';
  DEFAULT_LAZARUS_REPO = 'https://gitlab.com/freepascal.org/lazarus.git';

implementation

{ TRepositoryManager }

constructor TRepositoryManager.Create(AOwner: TConfigManager);
begin
  inherited Create;
  FOwner := AOwner;
  FRepositories := TStringList.Create;
  FDefaultRepo := '';
end;

destructor TRepositoryManager.Destroy;
begin
  FRepositories.Free;
  inherited;
end;

function TRepositoryManager.AddRepository(const AName, AURL: string): Boolean;
begin
  Result := False;
  try
    FRepositories.Values[AName] := AURL;
    FOwner.SetModified;
    Result := True;
  except
    on E: Exception do
      WriteLn('Error adding repository: ', E.Message);
  end;
end;

function TRepositoryManager.RemoveRepository(const AName: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  try
    Index := FRepositories.IndexOfName(AName);
    if Index >= 0 then
    begin
      FRepositories.Delete(Index);
      FOwner.SetModified;
      Result := True;
    end;
  except
    on E: Exception do
      WriteLn('Error removing repository: ', E.Message);
  end;
end;

function TRepositoryManager.GetRepository(const AName: string): string;
begin
  Result := FRepositories.Values[AName];
end;

function TRepositoryManager.HasRepository(const AName: string): Boolean;
begin
  Result := FRepositories.IndexOfName(AName) >= 0;
end;

function TRepositoryManager.GetDefaultRepository: string;
begin
  Result := FDefaultRepo;
end;

function TRepositoryManager.ListRepositories: TStringArray;
var
  i: Integer;
begin
  SetLength(Result, FRepositories.Count);
  for i := 0 to FRepositories.Count - 1 do
    Result[i] := FRepositories.Names[i];
end;

procedure TRepositoryManager.Clear;
begin
  FRepositories.Clear;
  FDefaultRepo := '';
end;

procedure TRepositoryManager.LoadFromJSON(ARepos: TJSONObject; const ADefaultRepo: string);
var
  i: Integer;
  Key: string;
begin
  Clear;
  FDefaultRepo := ADefaultRepo;
  
  if Assigned(ARepos) then
  begin
    for i := 0 to ARepos.Count - 1 do
    begin
      Key := ARepos.Names[i];
      FRepositories.Values[Key] := ARepos.Strings[Key];
    end;
  end;
end;

procedure TRepositoryManager.SaveToJSON(out ARepos: TJSONObject; out ADefaultRepo: string);
var
  i: Integer;
  Key, Value: string;
begin
  ARepos := TJSONObject.Create;
  for i := 0 to FRepositories.Count - 1 do
  begin
    Key := FRepositories.Names[i];
    Value := FRepositories.ValueFromIndex[i];
    ARepos.Add(Key, Value);
  end;
  ADefaultRepo := FDefaultRepo;
end;

{ TSettingsManager }

constructor TSettingsManager.Create(AOwner: TConfigManager);
begin
  inherited Create;
  FOwner := AOwner;
  
  // 设置默认值
  FSettings.AutoUpdate := False;
  FSettings.ParallelJobs := DEFAULT_PARALLEL_JOBS;
  FSettings.KeepSources := True;
  FSettings.InstallRoot := '';
  FSettings.DefaultRepo := '';
end;

function TSettingsManager.GetSettings: TFPDevSettings;
begin
  Result := FSettings;
end;

function TSettingsManager.SetSettings(const ASettings: TFPDevSettings): Boolean;
begin
  Result := False;
  try
    FSettings := ASettings;
    FOwner.SetModified;
    Result := True;
  except
    on E: Exception do
      WriteLn('Error setting configuration: ', E.Message);
  end;
end;

procedure TSettingsManager.LoadFromJSON(ASettings: TJSONObject);
begin
  if Assigned(ASettings) then
  begin
    FSettings.AutoUpdate := ASettings.Get('auto_update', False);
    FSettings.ParallelJobs := ASettings.Get('parallel_jobs', DEFAULT_PARALLEL_JOBS);
    FSettings.KeepSources := ASettings.Get('keep_sources', True);
    FSettings.InstallRoot := ASettings.Get('install_root', '');
    FSettings.DefaultRepo := ASettings.Get('default_repo', '');
  end;
end;

procedure TSettingsManager.SaveToJSON(out ASettings: TJSONObject);
begin
  ASettings := TJSONObject.Create;
  ASettings.Add('auto_update', FSettings.AutoUpdate);
  ASettings.Add('parallel_jobs', FSettings.ParallelJobs);
  ASettings.Add('keep_sources', FSettings.KeepSources);
  ASettings.Add('install_root', FSettings.InstallRoot);
  ASettings.Add('default_repo', FSettings.DefaultRepo);
end;

{ TToolchainManager }

constructor TToolchainManager.Create(AOwner: TConfigManager);
begin
  inherited Create;
  FOwner := AOwner;
  FToolchains := TStringList.Create;
  FDefaultToolchain := '';
end;

destructor TToolchainManager.Destroy;
begin
  FToolchains.Free;
  inherited;
end;

function TToolchainManager.ToolchainTypeToString(AType: TToolchainType): string;
begin
  case AType of
    ttRelease: Result := 'release';
    ttDevelopment: Result := 'development';
    ttCustom: Result := 'custom';
  else
    Result := 'release';
  end;
end;

function TToolchainManager.StringToToolchainType(const AStr: string): TToolchainType;
begin
  if SameText(AStr, 'development') then
    Result := ttDevelopment
  else if SameText(AStr, 'custom') then
    Result := ttCustom
  else
    Result := ttRelease;
end;

function TToolchainManager.ToolchainInfoToJSON(const AInfo: TToolchainInfo): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('type', ToolchainTypeToString(AInfo.ToolchainType));
    Result.Add('version', AInfo.Version);
    Result.Add('install_path', AInfo.InstallPath);
    Result.Add('source_url', AInfo.SourceURL);
    Result.Add('branch', AInfo.Branch);
    Result.Add('installed', AInfo.Installed);
    if AInfo.InstallDate > 0 then
      Result.Add('install_date', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', AInfo.InstallDate));
  except
    Result.Free;
    raise;
  end;
end;

function TToolchainManager.JSONToToolchainInfo(AJSON: TJSONObject): TToolchainInfo;
var
  DateStr: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  Result.ToolchainType := StringToToolchainType(AJSON.Get('type', 'release'));
  Result.Version := AJSON.Get('version', '');
  Result.InstallPath := AJSON.Get('install_path', '');
  Result.SourceURL := AJSON.Get('source_url', '');
  Result.Branch := AJSON.Get('branch', '');
  Result.Installed := AJSON.Get('installed', False);
  
  DateStr := AJSON.Get('install_date', '');
  if DateStr <> '' then
  begin
    try
      Result.InstallDate := StrToDateTime(StringReplace(DateStr, 'T', ' ', [rfReplaceAll]));
    except
      Result.InstallDate := 0;
    end;
  end;
end;

function TToolchainManager.AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
var
  JSONObj: TJSONObject;
begin
  Result := False;
  try
    JSONObj := ToolchainInfoToJSON(AInfo);
    try
      FToolchains.Values[AName] := JSONObj.AsJSON;
      FOwner.SetModified;
      Result := True;
    finally
      JSONObj.Free;
    end;
  except
    on E: Exception do
      WriteLn('Error adding toolchain: ', E.Message);
  end;
end;

function TToolchainManager.RemoveToolchain(const AName: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  try
    Index := FToolchains.IndexOfName(AName);
    if Index >= 0 then
    begin
      FToolchains.Delete(Index);
      FOwner.SetModified;
      Result := True;
    end;
  except
    on E: Exception do
      WriteLn('Error removing toolchain: ', E.Message);
  end;
end;

function TToolchainManager.GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
var
  JSONStr: string;
  JSONData: TJSONData;
begin
  Result := False;
  FillChar(AInfo, SizeOf(AInfo), 0);
  
  try
    JSONStr := FToolchains.Values[AName];
    if JSONStr <> '' then
    begin
      JSONData := GetJSON(JSONStr);
      try
        if JSONData is TJSONObject then
        begin
          AInfo := JSONToToolchainInfo(TJSONObject(JSONData));
          Result := True;
        end;
      finally
        JSONData.Free;
      end;
    end;
  except
    on E: Exception do
      WriteLn('Error getting toolchain: ', E.Message);
  end;
end;

function TToolchainManager.SetDefaultToolchain(const AName: string): Boolean;
begin
  Result := False;
  try
    if FToolchains.IndexOfName(AName) >= 0 then
    begin
      FDefaultToolchain := AName;
      FOwner.SetModified;
      Result := True;
    end;
  except
    on E: Exception do
      WriteLn('Error setting default toolchain: ', E.Message);
  end;
end;

function TToolchainManager.GetDefaultToolchain: string;
begin
  Result := FDefaultToolchain;
end;

function TToolchainManager.ListToolchains: TStringArray;
var
  i: Integer;
begin
  SetLength(Result, FToolchains.Count);
  for i := 0 to FToolchains.Count - 1 do
    Result[i] := FToolchains.Names[i];
end;

procedure TToolchainManager.Clear;
begin
  FToolchains.Clear;
  FDefaultToolchain := '';
end;

procedure TToolchainManager.LoadFromJSON(AToolchains: TJSONObject; const ADefaultToolchain: string);
var
  i: Integer;
  Key: string;
begin
  Clear;
  FDefaultToolchain := ADefaultToolchain;
  
  if Assigned(AToolchains) then
  begin
    for i := 0 to AToolchains.Count - 1 do
    begin
      Key := AToolchains.Names[i];
      FToolchains.Values[Key] := AToolchains.Items[i].AsJSON;
    end;
  end;
end;

procedure TToolchainManager.SaveToJSON(out AToolchains: TJSONObject; out ADefaultToolchain: string);
var
  i: Integer;
  Key, Value: string;
  JSONData: TJSONData;
begin
  AToolchains := TJSONObject.Create;
  for i := 0 to FToolchains.Count - 1 do
  begin
    Key := FToolchains.Names[i];
    Value := FToolchains.ValueFromIndex[i];
    if Value <> '' then
    begin
      JSONData := GetJSON(Value);
      AToolchains.Add(Key, JSONData);
    end;
  end;
  ADefaultToolchain := FDefaultToolchain;
end;

{ TLazarusManager }

constructor TLazarusManager.Create(AOwner: TConfigManager);
begin
  inherited Create;
  FOwner := AOwner;
  FVersions := TStringList.Create;
  FDefaultVersion := '';
end;

destructor TLazarusManager.Destroy;
begin
  FVersions.Free;
  inherited;
end;

function TLazarusManager.LazarusInfoToJSON(const AInfo: TLazarusInfo): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('version', AInfo.Version);
    Result.Add('fpc_version', AInfo.FPCVersion);
    Result.Add('install_path', AInfo.InstallPath);
    Result.Add('source_url', AInfo.SourceURL);
    Result.Add('branch', AInfo.Branch);
    Result.Add('installed', AInfo.Installed);
  except
    Result.Free;
    raise;
  end;
end;

function TLazarusManager.JSONToLazarusInfo(AJSON: TJSONObject): TLazarusInfo;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  Result.Version := AJSON.Get('version', '');
  Result.FPCVersion := AJSON.Get('fpc_version', '');
  Result.InstallPath := AJSON.Get('install_path', '');
  Result.SourceURL := AJSON.Get('source_url', '');
  Result.Branch := AJSON.Get('branch', '');
  Result.Installed := AJSON.Get('installed', False);
end;

function TLazarusManager.AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;
var
  JSONObj: TJSONObject;
begin
  Result := False;
  try
    JSONObj := LazarusInfoToJSON(AInfo);
    try
      FVersions.Values[AName] := JSONObj.AsJSON;
      FOwner.SetModified;
      Result := True;
    finally
      JSONObj.Free;
    end;
  except
    on E: Exception do
      WriteLn('Error adding Lazarus version: ', E.Message);
  end;
end;

function TLazarusManager.RemoveLazarusVersion(const AName: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  try
    Index := FVersions.IndexOfName(AName);
    if Index >= 0 then
    begin
      FVersions.Delete(Index);
      FOwner.SetModified;
      Result := True;
    end;
  except
    on E: Exception do
      WriteLn('Error removing Lazarus version: ', E.Message);
  end;
end;

function TLazarusManager.GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;
var
  JSONStr: string;
  JSONData: TJSONData;
begin
  Result := False;
  FillChar(AInfo, SizeOf(AInfo), 0);
  
  try
    JSONStr := FVersions.Values[AName];
    if JSONStr <> '' then
    begin
      JSONData := GetJSON(JSONStr);
      try
        if JSONData is TJSONObject then
        begin
          AInfo := JSONToLazarusInfo(TJSONObject(JSONData));
          Result := True;
        end;
      finally
        JSONData.Free;
      end;
    end;
  except
    on E: Exception do
      WriteLn('Error getting Lazarus version: ', E.Message);
  end;
end;

function TLazarusManager.SetDefaultLazarusVersion(const AName: string): Boolean;
begin
  Result := False;
  try
    if FVersions.IndexOfName(AName) >= 0 then
    begin
      FDefaultVersion := AName;
      FOwner.SetModified;
      Result := True;
    end;
  except
    on E: Exception do
      WriteLn('Error setting default Lazarus version: ', E.Message);
  end;
end;

function TLazarusManager.GetDefaultLazarusVersion: string;
begin
  Result := FDefaultVersion;
end;

function TLazarusManager.ListLazarusVersions: TStringArray;
var
  i: Integer;
begin
  SetLength(Result, FVersions.Count);
  for i := 0 to FVersions.Count - 1 do
    Result[i] := FVersions.Names[i];
end;

procedure TLazarusManager.Clear;
begin
  FVersions.Clear;
  FDefaultVersion := '';
end;

procedure TLazarusManager.LoadFromJSON(ALazarus: TJSONObject);
var
  VersionsJSON: TJSONObject;
  i: Integer;
  Key: string;
begin
  Clear;
  
  if Assigned(ALazarus) then
  begin
    FDefaultVersion := ALazarus.Get('default_version', '');
    VersionsJSON := ALazarus.Objects['versions'];
    if Assigned(VersionsJSON) then
    begin
      for i := 0 to VersionsJSON.Count - 1 do
      begin
        Key := VersionsJSON.Names[i];
        FVersions.Values[Key] := VersionsJSON.Items[i].AsJSON;
      end;
    end;
  end;
end;

procedure TLazarusManager.SaveToJSON(out ALazarus: TJSONObject);
var
  VersionsJSON: TJSONObject;
  i: Integer;
  Key, Value: string;
  JSONData: TJSONData;
begin
  ALazarus := TJSONObject.Create;
  ALazarus.Add('default_version', FDefaultVersion);
  
  VersionsJSON := TJSONObject.Create;
  for i := 0 to FVersions.Count - 1 do
  begin
    Key := FVersions.Names[i];
    Value := FVersions.ValueFromIndex[i];
    if Value <> '' then
    begin
      JSONData := GetJSON(Value);
      VersionsJSON.Add(Key, JSONData);
    end;
  end;
  ALazarus.Add('versions', VersionsJSON);
end;

{ TCrossTargetManager }

constructor TCrossTargetManager.Create(AOwner: TConfigManager);
begin
  inherited Create;
  FOwner := AOwner;
  FCrossTargets := TStringList.Create;
end;

destructor TCrossTargetManager.Destroy;
begin
  FCrossTargets.Free;
  inherited;
end;

function TCrossTargetManager.CrossTargetToJSON(const ATarget: TCrossTarget): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('enabled', ATarget.Enabled);
    Result.Add('binutils_path', ATarget.BinutilsPath);
    Result.Add('libraries_path', ATarget.LibrariesPath);
  except
    Result.Free;
    raise;
  end;
end;

function TCrossTargetManager.JSONToCrossTarget(AJSON: TJSONObject): TCrossTarget;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  Result.Enabled := AJSON.Get('enabled', False);
  Result.BinutilsPath := AJSON.Get('binutils_path', '');
  Result.LibrariesPath := AJSON.Get('libraries_path', '');
end;

function TCrossTargetManager.AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
var
  JSONObj: TJSONObject;
begin
  Result := False;
  try
    JSONObj := CrossTargetToJSON(AInfo);
    try
      FCrossTargets.Values[ATarget] := JSONObj.AsJSON;
      FOwner.SetModified;
      Result := True;
    finally
      JSONObj.Free;
    end;
  except
    on E: Exception do
      WriteLn('Error adding cross target: ', E.Message);
  end;
end;

function TCrossTargetManager.RemoveCrossTarget(const ATarget: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  try
    Index := FCrossTargets.IndexOfName(ATarget);
    if Index >= 0 then
    begin
      FCrossTargets.Delete(Index);
      FOwner.SetModified;
      Result := True;
    end;
  except
    on E: Exception do
      WriteLn('Error removing cross target: ', E.Message);
  end;
end;

function TCrossTargetManager.GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
var
  JSONStr: string;
  JSONData: TJSONData;
begin
  Result := False;
  FillChar(AInfo, SizeOf(AInfo), 0);
  
  try
    JSONStr := FCrossTargets.Values[ATarget];
    if JSONStr <> '' then
    begin
      JSONData := GetJSON(JSONStr);
      try
        if JSONData is TJSONObject then
        begin
          AInfo := JSONToCrossTarget(TJSONObject(JSONData));
          Result := True;
        end;
      finally
        JSONData.Free;
      end;
    end;
  except
    on E: Exception do
      WriteLn('Error getting cross target: ', E.Message);
  end;
end;

function TCrossTargetManager.ListCrossTargets: TStringArray;
var
  i: Integer;
begin
  SetLength(Result, FCrossTargets.Count);
  for i := 0 to FCrossTargets.Count - 1 do
    Result[i] := FCrossTargets.Names[i];
end;

procedure TCrossTargetManager.Clear;
begin
  FCrossTargets.Clear;
end;

procedure TCrossTargetManager.LoadFromJSON(ACrossTargets: TJSONObject);
var
  i: Integer;
  Key: string;
begin
  Clear;
  
  if Assigned(ACrossTargets) then
  begin
    for i := 0 to ACrossTargets.Count - 1 do
    begin
      Key := ACrossTargets.Names[i];
      FCrossTargets.Values[Key] := ACrossTargets.Items[i].AsJSON;
    end;
  end;
end;

procedure TCrossTargetManager.SaveToJSON(out ACrossTargets: TJSONObject);
var
  i: Integer;
  Key, Value: string;
  JSONData: TJSONData;
begin
  ACrossTargets := TJSONObject.Create;
  for i := 0 to FCrossTargets.Count - 1 do
  begin
    Key := FCrossTargets.Names[i];
    Value := FCrossTargets.ValueFromIndex[i];
    if Value <> '' then
    begin
      JSONData := GetJSON(Value);
      ACrossTargets.Add(Key, JSONData);
    end;
  end;
end;

{ TConfigManager }

constructor TConfigManager.Create(const AConfigPath: string);
begin
  inherited Create;
  
  if AConfigPath = '' then
    FConfigPath := GetDefaultConfigPath
  else
    FConfigPath := AConfigPath;
    
  FModified := False;
  FVersion := CONFIG_VERSION;
  
  // 创建子管理器
  FToolchainManager := TToolchainManager.Create(Self);
  FLazarusManager := TLazarusManager.Create(Self);
  FCrossTargetManager := TCrossTargetManager.Create(Self);
  FRepositoryManager := TRepositoryManager.Create(Self);
  FSettingsManager := TSettingsManager.Create(Self);
end;

destructor TConfigManager.Destroy;
begin
  FToolchainManager.Free;
  FLazarusManager.Free;
  FCrossTargetManager.Free;
  FRepositoryManager.Free;
  FSettingsManager.Free;
  inherited;
end;

function TConfigManager.GetDefaultConfigPath: string;
var
  Root: string;
begin
  // 统一使用系统规范数据根目录（支持 FPDEV_DATA_ROOT 覆盖），与 fpdev.paths 对齐
  Root := GetEnvironmentVariable('FPDEV_DATA_ROOT');
  if Root = '' then
  begin
    {$IFDEF MSWINDOWS}
    Root := GetEnvironmentVariable('APPDATA');
    if Root <> '' then 
      Root := IncludeTrailingPathDelimiter(Root) + 'fpdev' 
    else 
      Root := '.fpdev';
    {$ELSE}
    Root := GetEnvironmentVariable('XDG_DATA_HOME');
    if Root = '' then
    begin
      Root := GetEnvironmentVariable('HOME');
      if Root <> '' then 
        Root := IncludeTrailingPathDelimiter(Root) + '.fpdev' 
      else 
        Root := '.fpdev';
    end
    else
      Root := IncludeTrailingPathDelimiter(Root) + 'fpdev';
    {$ENDIF}
  end;
  Result := IncludeTrailingPathDelimiter(Root) + 'config.json';
end;

function TConfigManager.CreateDefaultConfig: Boolean;
var
  ConfigDir: string;
  Settings: TFPDevSettings;
begin
  Result := False;
  try
    // 创建配置目录
    ConfigDir := ExtractFileDir(FConfigPath);
    if (ConfigDir <> '') and not DirectoryExists(ConfigDir) then
      ForceDirectories(ConfigDir);
      
    // 设置默认仓库
    FRepositoryManager.AddRepository('official_fpc', DEFAULT_FPC_REPO);
    FRepositoryManager.AddRepository('official_lazarus', DEFAULT_LAZARUS_REPO);
    
    // 设置默认安装根目录
    Settings := FSettingsManager.GetSettings;
    if Settings.InstallRoot = '' then
    begin
      Settings.InstallRoot := IncludeTrailingPathDelimiter(ExtractFileDir(FConfigPath));
      FSettingsManager.SetSettings(Settings);
    end;
    
    FModified := True;
    Result := SaveConfig;
  except
    on E: Exception do
    begin
      WriteLn('Error creating default config: ', E.Message);
      Result := False;
    end;
  end;
end;

function TConfigManager.LoadConfig: Boolean;
var
  JSONStr: string;
  JSONData: TJSONData;
  ConfigJSON: TJSONObject;
begin
  Result := False;
  
  if not FileExists(FConfigPath) then
  begin
    // 创建默认配置
    Result := CreateDefaultConfig;
    Exit;
  end;
  
  try
    // 读取配置文件
    with TStringList.Create do
    try
      LoadFromFile(FConfigPath);
      JSONStr := Text;
    finally
      Free;
    end;
    
    // 解析JSON
    JSONData := GetJSON(JSONStr);
    try
      if not (JSONData is TJSONObject) then
        Exit;
        
      ConfigJSON := TJSONObject(JSONData);
      
      // 读取版本
      FVersion := ConfigJSON.Get('version', CONFIG_VERSION);
      
      // 加载各子管理器数据
      FToolchainManager.LoadFromJSON(
        ConfigJSON.Objects['toolchains'],
        ConfigJSON.Get('default_toolchain', '')
      );
      
      FLazarusManager.LoadFromJSON(ConfigJSON.Objects['lazarus']);
      
      FCrossTargetManager.LoadFromJSON(ConfigJSON.Objects['cross_targets']);
      
      FRepositoryManager.LoadFromJSON(
        ConfigJSON.Objects['repositories'],
        ConfigJSON.Get('default_repo', '')
      );
      
      FSettingsManager.LoadFromJSON(ConfigJSON.Objects['settings']);
      
      FModified := False;
      Result := True;
      
    finally
      JSONData.Free;
    end;
    
  except
    on E: Exception do
    begin
      WriteLn('Error loading config: ', E.Message);
      Result := False;
    end;
  end;
end;

function TConfigManager.SaveConfig: Boolean;
var
  ConfigJSON: TJSONObject;
  ToolchainsJSON, LazarusJSON, CrossTargetsJSON, ReposJSON, SettingsJSON: TJSONObject;
  DefaultToolchain, DefaultRepo: string;
begin
  Result := False;
  
  try
    ConfigJSON := TJSONObject.Create;
    try
      // 基本信息
      ConfigJSON.Add('version', FVersion);
      
      // 保存各子管理器数据
      FToolchainManager.SaveToJSON(ToolchainsJSON, DefaultToolchain);
      ConfigJSON.Add('default_toolchain', DefaultToolchain);
      ConfigJSON.Add('toolchains', ToolchainsJSON);
      
      FLazarusManager.SaveToJSON(LazarusJSON);
      ConfigJSON.Add('lazarus', LazarusJSON);
      
      FCrossTargetManager.SaveToJSON(CrossTargetsJSON);
      ConfigJSON.Add('cross_targets', CrossTargetsJSON);
      
      FRepositoryManager.SaveToJSON(ReposJSON, DefaultRepo);
      ConfigJSON.Add('repositories', ReposJSON);
      
      FSettingsManager.SaveToJSON(SettingsJSON);
      ConfigJSON.Add('settings', SettingsJSON);
      
      // 保存到文件
      with TStringList.Create do
      try
        Text := ConfigJSON.FormatJSON;
        SaveToFile(FConfigPath);
        FModified := False;
        Result := True;
      finally
        Free;
      end;
      
    finally
      ConfigJSON.Free;
    end;
    
  except
    on E: Exception do
    begin
      WriteLn('Error saving config: ', E.Message);
      Result := False;
    end;
  end;
end;

function TConfigManager.GetConfigPath: string;
begin
  Result := FConfigPath;
end;

function TConfigManager.GetToolchainManager: IToolchainManager;
begin
  Result := FToolchainManager;
end;

function TConfigManager.GetLazarusManager: ILazarusManager;
begin
  Result := FLazarusManager;
end;

function TConfigManager.GetCrossTargetManager: ICrossTargetManager;
begin
  Result := FCrossTargetManager;
end;

function TConfigManager.GetRepositoryManager: IRepositoryManager;
begin
  Result := FRepositoryManager;
end;

function TConfigManager.GetSettingsManager: ISettingsManager;
begin
  Result := FSettingsManager;
end;

function TConfigManager.IsModified: Boolean;
begin
  Result := FModified;
end;

procedure TConfigManager.SetModified;
begin
  FModified := True;
end;

end.
