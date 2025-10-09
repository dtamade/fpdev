unit fpdev.cmd.package;

{$codepage utf8}

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cmd.package

FreePascal 包管理系统


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
  SysUtils, Classes, Process, fpjson, jsonparser, StrUtils,
  fpdev.config, fpdev.utils, fpdev.terminal,
  fpdev.toolchain.fetcher, fpdev.toolchain.extract, fpdev.paths;

type
  { TPackageInfo }
  TPackageInfo = record
    Name: string;
    Version: string;
    Description: string;
    Author: string;
    License: string;
    Homepage: string;
    Repository: string;
    Dependencies: TStringArray;
    URLs: TStringArray;   // 下载地址（可空）
    Sha256: string;       // 期望校验（可空）
    SourcePath: string;   // 本地源码/包路径（可空）
    Installed: Boolean;
    InstallPath: string;
    InstallDate: TDateTime;
  end;

  TPackageArray = array of TPackageInfo;

  { TPackageManager }
  TPackageManager = class
  private
    FConfigManager: TFPDevConfigManager;
    FInstallRoot: string;
    FPackageRegistry: string;
    FLastBuildTool: string;
    FLastBuildLog: string;
    FKeepArtifacts: Boolean;

    function GetAvailablePackages: TPackageArray;
    function GetInstalledPackages: TPackageArray;
    function DownloadPackage(const APackageName, AVersion: string): Boolean;
    function InstallPackageFromSource(const APackageName, ASourcePath: string): Boolean;
    function ValidatePackage(const APackageName: string): Boolean;
    function GetPackageInstallPath(const APackageName: string): string;
    function IsPackageInstalled(const APackageName: string): Boolean;
    function GetPackageInfo(const APackageName: string): TPackageInfo;
    function ResolveDependencies(const APackageName: string): TStringArray;
    function BuildPackage(const ASourcePath: string): Boolean;
    function RemoveDirRecursive(const Dir: string): Boolean;

    function WritePackageMetadata(const AInstallPath: string; const Info: TPackageInfo): Boolean;

  public
    constructor Create(AConfigManager: TFPDevConfigManager);
    destructor Destroy; override;

    // 设置
    procedure SetKeepBuildArtifacts(const AValue: Boolean);

    // 查询（供测试和上层使用）
    function GetAvailablePackageList: TPackageArray;

    // 清理
    function Clean(const Scope: string): Boolean; // 'sandbox' | 'cache' | 'all'

    // 包管理
    function InstallPackage(const APackageName: string; const AVersion: string = ''): Boolean;
    function UninstallPackage(const APackageName: string): Boolean;
    function UpdatePackage(const APackageName: string): Boolean;
    function ListPackages(const AShowAll: Boolean = False): Boolean;
    function SearchPackages(const AQuery: string): Boolean;

    // 包信息
    function ShowPackageInfo(const APackageName: string): Boolean;
    function ShowPackageDependencies(const APackageName: string): Boolean;
    function VerifyPackage(const APackageName: string): Boolean;

    // 仓库管理
    function AddRepository(const AName, AURL: string): Boolean;
    function RemoveRepository(const AName: string): Boolean;
    function UpdateRepositories: Boolean;
    function ListRepositories: Boolean;

    // 本地包管理
    function InstallFromLocal(const APackagePath: string): Boolean;
    function CreatePackage(const APackageName, APath: string): Boolean;
    function PublishPackage(const APackageName: string): Boolean;
  end;

// 主要执行函数
procedure execute(const aParams: array of string);

implementation

const
  // 默认包仓库
  DEFAULT_REPOSITORIES: array[0..2] of record
    Name: string;
    URL: string;
  end = (
    (Name: 'official'; URL: 'https://packages.freepascal.org/'),
    (Name: 'lazarus'; URL: 'https://packages.lazarus-ide.org/'),
    (Name: 'community'; URL: 'https://github.com/freepascal-packages/')
  );

{ TPackageManager }

constructor TPackageManager.Create(AConfigManager: TFPDevConfigManager);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;

  Settings := FConfigManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
  begin
    {$IFDEF MSWINDOWS}
    FInstallRoot := GetEnvironmentVariable('USERPROFILE') + '\.fpdev';
    {$ELSE}
    FInstallRoot := GetEnvironmentVariable('HOME') + '/.fpdev';
    {$ENDIF}

    Settings.InstallRoot := FInstallRoot;
    FConfigManager.SetSettings(Settings);
  end;

  FPackageRegistry := FInstallRoot + PathDelim + 'packages';
  FLastBuildTool := '';
  FKeepArtifacts := False;
  FLastBuildLog := '';

  // 确保包目录存在
  if not DirectoryExists(FPackageRegistry) then
    ForceDirectories(FPackageRegistry);
end;

procedure TPackageManager.SetKeepBuildArtifacts(const AValue: Boolean);
begin
  FKeepArtifacts := AValue;
end;

function TPackageManager.Clean(const Scope: string): Boolean;
var
  S: string;
  Ok: Boolean;
  Path: string;
begin
  Result := True;
  S := LowerCase(Trim(Scope));
  Ok := True;
  if (S='sandbox') or (S='all') then
  begin
    Path := GetSandboxDir;
    if DirectoryExists(Path) then
      Ok := RemoveDirRecursive(Path) and Ok
    else
      Ok := True and Ok;
  end;
  if (S='cache') or (S='all') then
  begin
    Path := IncludeTrailingPathDelimiter(GetCacheDir) + 'packages';
    if DirectoryExists(Path) then
      Ok := RemoveDirRecursive(Path) and Ok
    else
      Ok := True and Ok;
  end;
  Result := Ok;
end;


destructor TPackageManager.Destroy;
begin
  inherited Destroy;
end;

function TPackageManager.GetPackageInstallPath(const APackageName: string): string;
begin
  Result := FPackageRegistry + PathDelim + APackageName;
end;

function TPackageManager.IsPackageInstalled(const APackageName: string): Boolean;
var
  InstallPath: string;
begin
  InstallPath := GetPackageInstallPath(APackageName);
  Result := DirectoryExists(InstallPath);
end;

function TPackageManager.ValidatePackage(const APackageName: string): Boolean;
begin
  // 简单的包名验证
  Result := (APackageName <> '') and (Pos(' ', APackageName) = 0) and (Pos('/', APackageName) = 0);
end;

function TPackageManager.GetPackageInfo(const APackageName: string): TPackageInfo;
var
  MetaPath: string;
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
begin
  // 初始化包信息
  FillChar(Result, SizeOf(Result), 0);
  Result.Name := APackageName;
  Result.Installed := IsPackageInstalled(APackageName);

  if Result.Installed then
  begin
    Result.InstallPath := GetPackageInstallPath(APackageName);
    // 尝试读取元数据
    MetaPath := IncludeTrailingPathDelimiter(Result.InstallPath) + 'package.json';
    if FileExists(MetaPath) then
    begin
      SL := TStringList.Create;
      try
        SL.LoadFromFile(MetaPath);
        J := GetJSON(SL.Text);
        try
          if J.JSONType=jtObject then
          begin
            O := TJSONObject(J);
            Result.Name := O.Get('name', APackageName);
            Result.Version := O.Get('version', '');
            Result.Description := O.Get('description', '');
            Result.Homepage := O.Get('homepage', '');
            Result.License := O.Get('license', '');
            Result.Repository := O.Get('repository', '');
            Result.SourcePath := O.Get('source_path', '');
          end;
        finally
          J.Free;
        end;
      finally
        SL.Free;
      end;
    end
    else
    begin
      Result.Version := '';
      Result.Description := 'Installed package';
    end;
  end;
end;

function TPackageManager.GetAvailablePackages: TPackageArray;
var
  IndexPath: string;
  JSONData: TJSONData = nil;
  Arr: TJSONArray;
  i, j, Count: Integer;
  Pkg: TPackageInfo;
  Names: TStringList;

// 占位，避免在嵌套函数区域出现不合法定义（真正实现位于文件末尾）
// function TPackageManager.GetAvailablePackageList: TPackageArray; forward;

  function TryGetArray(AData: TJSONData): TJSONArray;
  begin
    Result := nil;
    if AData=nil then Exit(nil);
    if AData.JSONType=jtArray then Exit(TJSONArray(AData));
    if (AData.JSONType=jtObject) and Assigned(TJSONObject(AData).Arrays['packages']) then
      Exit(TJSONObject(AData).Arrays['packages']);
  end;

  function ParseVersionParts(const S: string; out A, B, C: Integer): Boolean;
  var parts: TStringArray;
  begin
    A := 0; B := 0; C := 0;
    Result := False;
    if S='' then Exit;
    parts := S.Split(['.']);
    if Length(parts) >= 1 then Val(parts[0], A);
    if Length(parts) >= 2 then Val(parts[1], B);
    if Length(parts) >= 3 then Val(parts[2], C);
    Result := True;
  end;

  function IsHigherVersion(const V1, V2: string): Boolean;
  var a1,b1,c1,a2,b2,c2: Integer;
  begin
    ParseVersionParts(V1,a1,b1,c1);
    ParseVersionParts(V2,a2,b2,c2);
    if a1<>a2 then Exit(a1>a2);
    if b1<>b2 then Exit(b1>b2);
    Exit(c1>c2);
  end;

  procedure MaybeReadURLsAndSha(const O: TJSONObject; var P: TPackageInfo);
  var U: TJSONData; K: Integer;
  begin
    P.Sha256 := O.Get('sha256','');
    SetLength(P.URLs, 0);
    U := O.Find('url');
    if Assigned(U) then
    begin
      if U.JSONType=jtString then
      begin
        SetLength(P.URLs, 1);
        P.URLs[0] := U.AsString;
      end
      else if U.JSONType=jtArray then
      begin
        SetLength(P.URLs, TJSONArray(U).Count);
        for K := 0 to TJSONArray(U).Count-1 do
          P.URLs[K] := TJSONArray(U).Items[K].AsString;
      end;
    end;
  end;

begin
  SetLength(Result, 0);
  IndexPath := FPackageRegistry + PathDelim + 'index.json';
  if not FileExists(IndexPath) then
  begin
  // WriteLn('提示: 未找到仓库索引，请先运行: fpdev package repo update');  // 调试代码已注释
    Exit;
  end;
  try
    with TStringList.Create do
    try
      LoadFromFile(IndexPath);
      JSONData := GetJSON(Text);
    finally
      Free;
    end;

    Arr := TryGetArray(JSONData);
    if Arr=nil then Exit;

    // 过滤无效条目：必须有 name、version、url（字符串或数组非空）
    // 去重：按 name 选择最高版本
    Names := TStringList.Create;
    try
      Names.Sorted := True; Names.Duplicates := dupIgnore; Names.CaseSensitive := False;
      for i := 0 to Arr.Count-1 do
      begin
        if (Arr.Items[i].JSONType<>jtObject) then Continue;
        if TJSONObject(Arr.Items[i]).Get('name','')='' then Continue;
        if TJSONObject(Arr.Items[i]).Get('version','')='' then Continue;
        // url 校验：字符串非空或数组长度>0
        if Assigned(TJSONObject(Arr.Items[i]).Find('url')) then
        begin
          if (TJSONObject(Arr.Items[i]).Find('url').JSONType=jtString) and (TJSONObject(Arr.Items[i]).Get('url','')='') then Continue;
          if (TJSONObject(Arr.Items[i]).Find('url').JSONType=jtArray) and (TJSONArray(TJSONObject(Arr.Items[i]).Find('url')).Count=0) then Continue;
        end
        else
          Continue;
        Names.Add(TJSONObject(Arr.Items[i]).Get('name',''));
      end;

      Count := 0;
      SetLength(Result, Names.Count);
      for i := 0 to Names.Count-1 do
      begin
        FillChar(Pkg, SizeOf(Pkg), 0);
        for j := 0 to Arr.Count-1 do
        begin
          if Arr.Items[j].JSONType<>jtObject then Continue;
          if not SameText(TJSONObject(Arr.Items[j]).Get('name',''), Names[i]) then Continue;
          // 二次校验（防御）
          if (TJSONObject(Arr.Items[j]).Get('version','')='') then Continue;
          if Assigned(TJSONObject(Arr.Items[j]).Find('url')) then
          begin
            if (TJSONObject(Arr.Items[j]).Find('url').JSONType=jtString) and (TJSONObject(Arr.Items[j]).Get('url','')='') then Continue;
            if (TJSONObject(Arr.Items[j]).Find('url').JSONType=jtArray) and (TJSONArray(TJSONObject(Arr.Items[j]).Find('url')).Count=0) then Continue;
          end
          else Continue;

          // 选择最高版本
          if (Pkg.Name='') or IsHigherVersion(TJSONObject(Arr.Items[j]).Get('version',''), Pkg.Version) then
          begin
            Pkg.Name := TJSONObject(Arr.Items[j]).Get('name','');
            Pkg.Version := TJSONObject(Arr.Items[j]).Get('version','');
            Pkg.Description := TJSONObject(Arr.Items[j]).Get('description','');
            Pkg.Homepage := TJSONObject(Arr.Items[j]).Get('homepage','');
            Pkg.License := TJSONObject(Arr.Items[j]).Get('license','');
            Pkg.Repository := TJSONObject(Arr.Items[j]).Get('repository','');
            MaybeReadURLsAndSha(TJSONObject(Arr.Items[j]), Pkg);
          end;
        end;
        if (Pkg.Name<>'') then
        begin
          Result[Count] := Pkg;
          Inc(Count);
        end;
      end;
      SetLength(Result, Count);
    finally
      Names.Free;
    end;
  finally
    if Assigned(JSONData) then JSONData.Free;
  end;
end;

function TPackageManager.GetInstalledPackages: TPackageArray;
var
  SearchRec: TSearchRec;
  Count: Integer;
begin
  SetLength(Result, 0);
  Count := 0;

  if FindFirst(FPackageRegistry + PathDelim + '*', faDirectory, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory <> 0) and
         (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        SetLength(Result, Count + 1);
        Result[Count] := GetPackageInfo(SearchRec.Name);
        Inc(Count);
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;
end;

function TPackageManager.DownloadPackage(const APackageName, AVersion: string): Boolean;
begin
  Result := False;
  // WriteLn('正在下载包 ', APackageName, ' 版本 ', AVersion, '...');  // 调试代码已注释

  // TODO: 实现实际的下载逻辑
  // WriteLn('注意: 包下载功能暂未实现');  // 调试代码已注释
  // WriteLn('请使用 install-local 命令安装本地包');  // 调试代码已注释

  Result := True; // 暂时返回成功，允许本地安装
end;

function TPackageManager.BuildPackage(const ASourcePath: string): Boolean;
var
  Process: TProcess;
  FoundLPK: string;
  SR: TSearchRec;
  LogPath: string;
  Log: TStringList;
begin
  Result := False;

  if not DirectoryExists(ASourcePath) then
  begin
  // WriteLn('错误: 源码路径不存在: ', ASourcePath);  // 调试代码已注释
    Exit;
  end;

  try
  // WriteLn('正在编译包...');  // 调试代码已注释

    // 查找并编译包
    Process := TProcess.Create(nil);
    try
      Process.CurrentDirectory := ASourcePath;

      // 优先使用 lazbuild 编译 Lazarus 包：查找首个 .lpk
      FoundLPK := '';
      if FindFirst(ASourcePath + PathDelim + '*.lpk', faAnyFile, SR) = 0 then
      begin
        repeat
          if (SR.Attr and faDirectory) = 0 then
          begin
            FoundLPK := ASourcePath + PathDelim + SR.Name;
            Break;
          end;
        until FindNext(SR) <> 0;
        FindClose(SR);
      end;

      if FoundLPK <> '' then
      begin
        Process.Executable := 'lazbuild';
        Process.Parameters.Add(FoundLPK);
        FLastBuildTool := 'lazbuild';
      end
      else if FileExists(ASourcePath + PathDelim + 'Makefile') then
      begin
        // 否则回退使用 make
        Process.Executable := 'make';
        Process.Parameters.Add('install');
        FLastBuildTool := 'make';
      end
      else
      begin
  // WriteLn('警告: 找不到 .lpk 或 Makefile，跳过编译步骤');  // 调试代码已注释
        FLastBuildTool := 'none';
        Exit(True);
      end;

      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];

      // 捕获输出
      Log := TStringList.Create;
      try
  // WriteLn('执行命令: ', Process.Executable, ' ', Process.Parameters.Text);  // 调试代码已注释
        Process.Execute;
        // 读取标准输出与错误
        if Process.Output.NumBytesAvailable > 0 then
          Log.LoadFromStream(Process.Output);
        if Process.Stderr.NumBytesAvailable > 0 then
        begin
          Log.Add('--- STDERR ---');
          Log.LoadFromStream(Process.Stderr);
        end;

        // 写入构建日志到缓存目录
        LogPath := IncludeTrailingPathDelimiter(GetLogsDir) + 'build_' + IntToStr(GetTickCount64) + '.log';
        ForceDirectories(ExtractFileDir(LogPath));
        Log.SaveToFile(LogPath);
        FLastBuildLog := LogPath;
      finally
        Log.Free;
      end;

      Result := Process.ExitStatus = 0;
      if not Result then
  // WriteLn('错误: 编译失败，退出代码: ', Process.ExitStatus);  // 调试代码已注释

    finally
      Process.Free;
    end;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 编译包时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TPackageManager.RemoveDirRecursive(const Dir: string): Boolean;
var
  SR: TSearchRec;
  P: string;
begin
  Result := True;
  if not DirectoryExists(Dir) then Exit(True);
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name='.') or (SR.Name='..') then Continue;
      P := IncludeTrailingPathDelimiter(Dir) + SR.Name;
      if (SR.Attr and faDirectory)<>0 then
      begin
        if not RemoveDirRecursive(P) then Result := False;
      end
      else
      begin
        if not DeleteFile(P) then Result := False;
      end;
    until FindNext(SR)<>0;
    FindClose(SR);
  end;
  if not RemoveDir(Dir) then Result := False;
end;



function TPackageManager.InstallPackageFromSource(const APackageName, ASourcePath: string): Boolean;
var
  InstallPath: string;
  Info: TPackageInfo;
begin
  Result := False;

  try
    InstallPath := GetPackageInstallPath(APackageName);
  // WriteLn('安装包 ', APackageName, ' 到: ', InstallPath);  // 调试代码已注释

    // 确保安装目录存在
    if not DirectoryExists(InstallPath) then
      ForceDirectories(InstallPath);

    // 复制源码到安装目录（后续实现为递归拷贝；当前保留源路径记录）
    Info := GetPackageInfo(APackageName);
    Info.SourcePath := ASourcePath;

  // WriteLn('步骤 1/2: 编译包');  // 调试代码已注释
    if not BuildPackage(ASourcePath) then
    begin
  // WriteLn('错误: 编译包失败');  // 调试代码已注释
      Exit;
    end;

    // 写入元数据（补充构建工具信息）
    Info := GetPackageInfo(APackageName);
    Info.SourcePath := ASourcePath;
    Info.Version := Info.Version; // 保持占位逻辑
    Info.Description := Info.Description;
    if not WritePackageMetadata(InstallPath, Info) then
  // WriteLn('警告: 写入包元数据失败');  // 调试代码已注释

  // WriteLn('✓ 包 ', APackageName, ' 安装完成');  // 调试代码已注释
    Result := True;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 安装包时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TPackageManager.ResolveDependencies(const APackageName: string): TStringArray;
begin
  // TODO: 实现依赖解析
  SetLength(Result, 0);
  // WriteLn('注意: 依赖解析功能暂未实现');  // 调试代码已注释
end;

function TPackageManager.InstallPackage(const APackageName: string; const AVersion: string): Boolean;
var
  UseVersion: string;
  Avail: TPackageArray;
  i, BestIdx: Integer;
  ZipPath, TmpDir, Err: string;
  Opt: TFetchOptions;
  URLs: array of string;
  InstalledOK: Boolean;

  function IsHigher(const V1, V2: string): Boolean;
  var a1,b1,c1,a2,b2,c2: Integer;
    procedure Parse(const S: string; out A,B,C: Integer);
    var parts: TStringArray;
    begin
      A:=0;B:=0;C:=0;
      parts := S.Split(['.']);
      if Length(parts)>=1 then Val(parts[0],A);
      if Length(parts)>=2 then Val(parts[1],B);
      if Length(parts)>=3 then Val(parts[2],C);
    end;
  begin
    Parse(V1,a1,b1,c1); Parse(V2,a2,b2,c2);
    if a1<>a2 then Exit(a1>a2);
    if b1<>b2 then Exit(b1>b2);
    Exit(c1>c2);
  end;

begin
  Result := False;

  if not ValidatePackage(APackageName) then
  begin
  // WriteLn('错误: 无效的包名: ', APackageName);  // 调试代码已注释
    Exit;
  end;

  if IsPackageInstalled(APackageName) then
  begin
  // WriteLn('包 ', APackageName, ' 已经安装');  // 调试代码已注释
    Exit(True);
  end;

  try
    // 从可用索引选择版本
    Avail := GetAvailablePackages;
    BestIdx := -1;
    for i := 0 to High(Avail) do
    begin
      if SameText(Avail[i].Name, APackageName) then
      begin
        if (AVersion='') then
        begin
          if (BestIdx<0) or IsHigher(Avail[i].Version, Avail[BestIdx].Version) then
            BestIdx := i;
        end
        else if SameText(Avail[i].Version, AVersion) then
          BestIdx := i;
      end;
    end;

    if BestIdx < 0 then
    begin
  // WriteLn('错误: 在索引中未找到包: ', APackageName);  // 调试代码已注释
      Exit;
    end;

    UseVersion := Avail[BestIdx].Version;
  // WriteLn('安装包 ', APackageName, ' 版本 ', UseVersion);  // 调试代码已注释

    if Length(Avail[BestIdx].URLs)=0 then
    begin
  // WriteLn('错误: 索引未提供下载 URL');  // 调试代码已注释
      Exit;
    end;

    // 下载到缓存 zip
    ZipPath := IncludeTrailingPathDelimiter(GetCacheDir) + 'packages' + PathDelim + APackageName + '-' + UseVersion + '.zip';
    ForceDirectories(ExtractFileDir(ZipPath));

    SetLength(URLs, Length(Avail[BestIdx].URLs));
    for i := 0 to High(URLs) do URLs[i] := Avail[BestIdx].URLs[i];

    Opt.DestDir := ExtractFileDir(ZipPath);
    Opt.SHA256 := Avail[BestIdx].Sha256;
    Opt.TimeoutMS := 30000;

    if not EnsureDownloadedCached(URLs, ZipPath, Opt.SHA256, Opt.TimeoutMS, Err) then
    begin
  // WriteLn('错误: 下载失败: ', Err);  // 调试代码已注释
      Exit;
    end;

    // 解压到临时目录
    TmpDir := IncludeTrailingPathDelimiter(GetSandboxDir) + 'pkg-' + APackageName + '-' + UseVersion;
    if DirectoryExists(TmpDir) then
      ; // 可考虑清理

    if not ZipExtract(ZipPath, TmpDir, Err) then
    begin
  // WriteLn('错误: 解压失败: ', Err);  // 调试代码已注释
  // WriteLn('保留临时目录以便排查: ', TmpDir);  // 调试代码已注释
      FLastBuildLog := Err; // 复用 Err 文本为日志路径/信息占位
      Exit;
    end;

    // 编译安装
    InstalledOK := InstallPackageFromSource(APackageName, TmpDir);
    if not InstalledOK then
    begin
  // WriteLn('安装失败，保留临时目录: ', TmpDir);  // 调试代码已注释
      Exit(False);
    end
    else
    begin
      // 安装成功，根据配置清理临时目录
      if not FKeepArtifacts then
      begin
        if DirectoryExists(TmpDir) then
        begin
          try
            if not RemoveDirRecursive(TmpDir) then WriteLn('Warning: Could not clean some temporary files: ', TmpDir);
          except
            on E: Exception do
  // WriteLn('警告: 清理临时目录失败: ', E.Message);  // 调试代码已注释
          end;
        end;
      end
      else
  // WriteLn('按要求保留构建产物: ', TmpDir);  // 调试代码已注释
    end;

    Result := True;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 安装包时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TPackageManager.UninstallPackage(const APackageName: string): Boolean;
var
  InstallPath: string;
begin
  Result := False;

  if not IsPackageInstalled(APackageName) then
  begin
  // WriteLn('包 ', APackageName, ' 未安装');  // 调试代码已注释
    Result := True;
    Exit;
  end;

  try
    InstallPath := GetPackageInstallPath(APackageName);

  // WriteLn('正在卸载包 ', APackageName, '...');  // 调试代码已注释

    // 删除安装目录
    if DirectoryExists(InstallPath) then
    begin
      try
        {$IFDEF MSWINDOWS}
        with TProcess.Create(nil) do
        try
          Executable := 'cmd';
          Parameters.Add('/c');
          Parameters.Add('rmdir');
          Parameters.Add('/s');
          Parameters.Add('/q');
          Parameters.Add(InstallPath);
          Options := Options + [poWaitOnExit];
          Execute;
          if ExitStatus <> 0 then
  // WriteLn('警告: 无法完全删除安装目录: ', InstallPath);  // 调试代码已注释
        finally
          Free;
        end;
        {$ELSE}
        with TProcess.Create(nil) do
        try
          Executable := 'rm';
          Parameters.Add('-rf');
          Parameters.Add(InstallPath);
          Options := Options + [poWaitOnExit];
          Execute;
          if ExitStatus <> 0 then
  // WriteLn('警告: 无法完全删除安装目录: ', InstallPath);  // 调试代码已注释
        finally
          Free;
        end;
        {$ENDIF}
      except
  // WriteLn('警告: 删除安装目录时发生异常: ', InstallPath);  // 调试代码已注释
      end;
    end;

  // WriteLn('✓ 包 ', APackageName, ' 卸载完成');  // 调试代码已注释
    Result := True;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 卸载包时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TPackageManager.UpdatePackage(const APackageName: string): Boolean;
begin
  Result := False;
  // WriteLn('提示: 包更新功能开发中');  // 调试代码已注释
  // 未来：对比已安装版本与索引最新版本；如较低则自动升级
end;

function TPackageManager.ListPackages(const AShowAll: Boolean): Boolean;
var
  Packages: TPackageArray;
  i: Integer;
begin
  Result := True;

  try
    if AShowAll then
      Packages := GetAvailablePackages
    else
      Packages := GetInstalledPackages;

    if AShowAll then
  // WriteLn('可用的包:')  // 调试代码已注释
    else
  // WriteLn('已安装的包:');  // 调试代码已注释

  // WriteLn('');  // 调试代码已注释
  // WriteLn('包名          版本      描述');  // 调试代码已注释
  // WriteLn('----------------------------------------');  // 调试代码已注释

    for i := 0 to High(Packages) do
    begin
      Write(Format('%-12s  ', [Packages[i].Name]));
      Write(Format('%-8s  ', [Packages[i].Version]));
      WriteLn(Packages[i].Description);
    end;

  // WriteLn('');  // 调试代码已注释
  // WriteLn('总计: ', Length(Packages), ' 个包');  // 调试代码已注释

  except
    on E: Exception do
    begin
  // WriteLn('错误: 列出包时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TPackageManager.SearchPackages(const AQuery: string): Boolean;
var
  Packages: TPackageArray;
  i, Matches: Integer;
  Q: string;
begin
  Result := True;
  Matches := 0;
  Q := LowerCase(Trim(AQuery));
  if Q = '' then
  begin
  // WriteLn('错误: 搜索关键词不能为空');  // 调试代码已注释
    Exit(False);
  end;

  try
    // 先在本地已安装包中搜索；远程仓库搜索后续实现
    Packages := GetInstalledPackages;

  // WriteLn('搜索已安装的包，关键词: ', AQuery);  // 调试代码已注释
  // WriteLn('');  // 调试代码已注释
  // WriteLn('包名          版本      描述');  // 调试代码已注释
  // WriteLn('----------------------------------------');  // 调试代码已注释

    for i := 0 to High(Packages) do
    begin
      if (Pos(Q, LowerCase(Packages[i].Name)) > 0) or
         (Pos(Q, LowerCase(Packages[i].Description)) > 0) then
      begin
        Inc(Matches);
        Write(Format('%-12s  ', [Packages[i].Name]));
        Write(Format('%-8s  ', [Packages[i].Version]));
        WriteLn(Packages[i].Description);
      end;
    end;

    if Matches = 0 then
  // WriteLn('未找到匹配的包');  // 调试代码已注释

  // WriteLn('');  // 调试代码已注释
  // WriteLn('匹配结果: ', Matches, ' 个包');  // 调试代码已注释

  except
    on E: Exception do
    begin
  // WriteLn('错误: 搜索包时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TPackageManager.ShowPackageInfo(const APackageName: string): Boolean;
var
  PackageInfo: TPackageInfo;
begin
  Result := False;

  try
    PackageInfo := GetPackageInfo(APackageName);

  // WriteLn('Package info: ', APackageName);  // Debug code commented out
  // WriteLn('');  // Debug code commented out
    WriteLn('Name: ', PackageInfo.Name);
    WriteLn('Version: ', PackageInfo.Version);
    WriteLn('Description: ', PackageInfo.Description);

    if PackageInfo.Installed then
    begin
  // WriteLn('Status: Installed');  // Debug code commented out
      WriteLn('Install Path: ', PackageInfo.InstallPath);
    end else
    begin
  // WriteLn('状态: 未安装');  // 调试代码已注释
    end;

    Result := True;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 显示包信息时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TPackageManager.ShowPackageDependencies(const APackageName: string): Boolean;
var
  Dependencies: TStringArray;
  i: Integer;
begin
  Result := False;

  try
    Dependencies := ResolveDependencies(APackageName);

  // WriteLn('包 ', APackageName, ' 的依赖:');  // 调试代码已注释
  // WriteLn('');  // 调试代码已注释

    if Length(Dependencies) = 0 then
  // WriteLn('无依赖')  // 调试代码已注释
    else
    begin
      for i := 0 to High(Dependencies) do
  // WriteLn('  - ', Dependencies[i]);  // 调试代码已注释
    end;

    Result := True;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 显示包依赖时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TPackageManager.VerifyPackage(const APackageName: string): Boolean;
begin
  Result := False;
  // WriteLn('验证包功能暂未实现');  // 调试代码已注释
  // TODO: 实现包验证功能
end;

function TPackageManager.WritePackageMetadata(const AInstallPath: string; const Info: TPackageInfo): Boolean;
var
  MetaPath: string;
  O: TJSONObject;
  SL: TStringList;
  i: Integer;
begin
  Result := False;
  try
    MetaPath := IncludeTrailingPathDelimiter(AInstallPath) + 'package.json';
    O := TJSONObject.Create;
    try
      O.Add('name', Info.Name);
      O.Add('version', Info.Version);
      O.Add('description', Info.Description);
      O.Add('homepage', Info.Homepage);
      O.Add('license', Info.License);
      O.Add('repository', Info.Repository);
      O.Add('install_path', AInstallPath);
      O.Add('install_date', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now));
      O.Add('source_path', Info.SourcePath);
      if FLastBuildTool<>'' then O.Add('build_tool', FLastBuildTool);
      if FLastBuildLog<>'' then O.Add('build_log', FLastBuildLog);
      if Length(Info.URLs)>0 then
      begin
        begin
          // FPC 不支持局部 var inline 声明，使用临时变量
          // 注意：此处在嵌套 begin..end 内创建并释放数组
          // 改为直接构造数组后添加
          // 为避免生命周期问题，先构造到临时变量再加入对象
          // 但 JSON 对象接管后会拥有其生命周期，这里仍手动释放可能导致双重释放
          // 因此采用：先构造，加入时不释放（由 O 拥有）；无需 finally free
          // 兼容写法：先构造，O.Add 后不要手动 Free
          // 构造
          // 注意：FPC 无匿名块局部变量，改为上层声明（简化实现：直接逐项 Add 到新数组并交给 O 持有）
          // 具体如下：
          // 由于不方便引入上层变量，这里采用直接序列化字符串数组的方式留待改进
          // 简化：不再使用局部变量，直接创建数组并附加
          // create array
          O.Add('url', TJSONArray.Create);
          for i := 0 to High(Info.URLs) do
            TJSONArray(O.Arrays['url']).Add(Info.URLs[i]);
        end;
      end;
      if Info.Sha256<>'' then O.Add('sha256', Info.Sha256);

      SL := TStringList.Create;
      try
        SL.Text := O.FormatJSON;
        ForceDirectories(AInstallPath);
        SL.SaveToFile(MetaPath);
        Result := True;
      finally
        SL.Free;
      end;
    finally
      O.Free;
    end;
  except
    on E: Exception do
    begin
  // WriteLn('警告: 写入包元数据失败: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;






function TPackageManager.AddRepository(const AName, AURL: string): Boolean;
begin
  Result := False;



  try
    Result := FConfigManager.AddRepository(AName, AURL);
    if Result then
    begin
      // WriteLn('✓ 仓库 ', AName, ' 添加成功')  // 调试代码已注释
    end
    else
    begin
      // WriteLn('错误: 添加仓库失败');  // 调试代码已注释
    end;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 添加仓库时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TPackageManager.RemoveRepository(const AName: string): Boolean;
begin
  Result := False;
  try
    if FConfigManager.RemoveRepository(AName) then
    begin
      // WriteLn('✓ 仓库 ', AName, ' 已删除');  // 调试代码已注释
      Result := True;
    end
    else
    begin
      // WriteLn('错误: 找不到仓库或删除失败: ', AName);  // 调试代码已注释
    end;
  except
    on E: Exception do
    begin
  // WriteLn('错误: 删除仓库时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TPackageManager.UpdateRepositories: Boolean;
var
  Names: TStringArray;
  i, j: Integer;
  RepoURL: string;
  Combined: TJSONArray;
  Err: string;
  CacheDir, IndexPath, TmpPath: string;
  SL: TStringList;
  JSONData: TJSONData = nil;
  Arr: TJSONArray;
  Opt: TFetchOptions;
  URLs: array of string;
  IsFileURL: Boolean;
  LocalFile: string;
begin
  Result := False;
  try
    // 目标缓存目录与索引文件
    CacheDir := FPackageRegistry;
    ForceDirectories(CacheDir);
    IndexPath := CacheDir + PathDelim + 'index.json';
    TmpPath := CacheDir + PathDelim + 'index.json.tmp';

    Combined := TJSONArray.Create;
    try
      Names := FConfigManager.ListRepositories;
      if Length(Names)=0 then
      begin
  // WriteLn('提示: 尚未配置任何仓库。使用: fpdev package repo add <name> <url>');  // 调试代码已注释
      end;

      for i := 0 to High(Names) do
      begin
        RepoURL := Trim(FConfigManager.GetRepository(Names[i]));
        if RepoURL='' then Continue;

        // 假设仓库 URL 直接指向 JSON 索引；若为目录/站点，可在末尾补 index.json
        if (RightStr(RepoURL, 5) <> '.json') then
          RepoURL := IncludeTrailingPathDelimiter(RepoURL) + 'index.json';

        // 支持 file:// 本地索引；否则使用 HTTP(S) 下载
        IsFileURL := (LeftStr(LowerCase(RepoURL), 7) = 'file://');
        SL := TStringList.Create;
        try
          if IsFileURL then
          begin
            LocalFile := Copy(RepoURL, 8, MaxInt); // 去掉 file://
            // Windows 可能是 file:///C:/... 开头，去除多余的前导 '/'
            while (Length(LocalFile) > 0) and ((LocalFile[1] = '/') or (LocalFile[1] = '\\')) do
              Delete(LocalFile, 1, 1);
            LocalFile := StringReplace(LocalFile, '/', PathDelim, [rfReplaceAll]);
            if FileExists(LocalFile) then
              SL.LoadFromFile(LocalFile)
            else
            begin
  // WriteLn('警告: 本地索引文件不存在: ', LocalFile);  // 调试代码已注释
              Continue;
            end;
          end
          else
          begin
            // 下载到临时文件
            SetLength(URLs, 1);
            URLs[0] := RepoURL;
            Opt.DestDir := CacheDir; Opt.SHA256 := ''; Opt.TimeoutMS := 15000;
            if not EnsureDownloadedCached(URLs, TmpPath, '', 15000, Err) then
            begin
  // WriteLn('警告: 无法获取仓库索引: ', Names[i], ' (', Err, ')');  // 调试代码已注释
              Continue;
            end;
            SL.LoadFromFile(TmpPath);
          end;

          // 读取并合并 packages 数组
          JSONData := GetJSON(SL.Text);
          Arr := nil;
          if JSONData.JSONType=jtArray then Arr := TJSONArray(JSONData)
          else if (JSONData.JSONType=jtObject) and Assigned(TJSONObject(JSONData).Arrays['packages']) then
            Arr := TJSONObject(JSONData).Arrays['packages'];
          if Arr<>nil then
          begin
            // 合并到 Combined：逐元素克隆加入
            for j := 0 to Arr.Count-1 do
              Combined.Add(Arr.Items[j].Clone as TJSONData);
          end
          else
          begin
            // 如果是对象且没有 packages 数组，尝试将对象当作单包信息
            if JSONData.JSONType=jtObject then
              Combined.Add(JSONData.Clone as TJSONData)
            else
  // WriteLn('警告: 仓库索引格式无法识别: ', Names[i]);  // 调试代码已注释
          end;
        finally
          if Assigned(JSONData) then JSONData.Free;
          SL.Free;
        end;
      end;

      // 将 Combined 写入 index.json
      SL := TStringList.Create;
      try
        SL.Text := Combined.FormatJSON;
        SL.SaveToFile(IndexPath);
      finally
        SL.Free;
      end;

  // WriteLn('✓ 仓库索引已更新: ', IndexPath);  // 调试代码已注释
      Result := True;
    finally
      Combined.Free;
    end;
  except
    on E: Exception do
    begin
  // WriteLn('错误: 更新仓库索引失败: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TPackageManager.ListRepositories: Boolean;
var
  Names: TStringArray;
  i: Integer;
  URL: string;
begin
  Result := True;
  try
    Names := FConfigManager.ListRepositories;

  // WriteLn('已配置的仓库:');  // 调试代码已注释
  // WriteLn('');  // 调试代码已注释
    if Length(Names) = 0 then
    begin
  // WriteLn('  (暂无仓库)');  // 调试代码已注释
      Exit(True);
    end;

    for i := 0 to High(Names) do
    begin
      URL := FConfigManager.GetRepository(Names[i]);
  // WriteLn('  - ', Names[i], ': ', URL);  // 调试代码已注释
    end;
  except
    on E: Exception do
    begin
  // WriteLn('错误: 列出仓库时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TPackageManager.InstallFromLocal(const APackagePath: string): Boolean;
var
  PackageName: string;
begin
  Result := False;

  if not DirectoryExists(APackagePath) then
  begin
  // WriteLn('错误: 包路径不存在: ', APackagePath);  // 调试代码已注释
    Exit;
  end;

  try
    // 从路径提取包名
    PackageName := ExtractFileName(APackagePath);
    if PackageName = '' then
      PackageName := 'local_package';

  // WriteLn('从本地安装包: ', PackageName);  // 调试代码已注释
    Result := InstallPackageFromSource(PackageName, APackagePath);

  except
    on E: Exception do
    begin
  // WriteLn('错误: 从本地安装包时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TPackageManager.CreatePackage(const APackageName, APath: string): Boolean;
begin
  Result := False;
  // WriteLn('创建包功能暂未实现');  // 调试代码已注释
  // TODO: 实现创建包功能
end;

function TPackageManager.PublishPackage(const APackageName: string): Boolean;
begin
  Result := False;
  // WriteLn('发布包功能暂未实现');  // 调试代码已注释
  // TODO: 实现发布包功能
end;

// 主要执行函数
procedure execute(const aParams: array of string);
var
  ConfigManager: TFPDevConfigManager;
  PackageManager: TPackageManager;
  Command: string;
  PackageName: string;
  Version: string;
  ShowAll: Boolean;
begin
  if Length(aParams) = 0 then
  begin
  // WriteLn('FreePascal 包管理系统');  // 调试代码已注释
  // WriteLn('');  // 调试代码已注释
  // WriteLn('用法:');  // 调试代码已注释
  // WriteLn('  fpdev package install <package> [version]       安装包');  // 调试代码已注释
  // WriteLn('  fpdev package install <package> [version] [--keep-build-artifacts]  安装包');  // 调试代码已注释

  // WriteLn('  fpdev package uninstall <package>               卸载包');  // 调试代码已注释
  // WriteLn('  fpdev package update <package>                  更新包');  // 调试代码已注释
  // WriteLn('  fpdev package list [--all]                      列出包');  // 调试代码已注释
  // WriteLn('  fpdev package search <query>                    搜索包');  // 调试代码已注释
    WriteLn('  fpdev package info <package>                    Show package information');
  // WriteLn('  fpdev package deps <package>                    显示包依赖');  // 调试代码已注释
  // WriteLn('  fpdev package verify <package>                  验证包');  // 调试代码已注释
  // WriteLn('  fpdev package install-local <path>              从本地安装包');  // 调试代码已注释
  // WriteLn('  fpdev package create <name> <path>              创建包');  // 调试代码已注释
  // WriteLn('  fpdev package publish <package>                 发布包');  // 调试代码已注释
  // WriteLn('  fpdev package repo add <name> <url>             添加仓库');  // 调试代码已注释
  // WriteLn('  fpdev package repo remove <name>                删除仓库');  // 调试代码已注释
  // WriteLn('  fpdev package repo update                       更新仓库');  // 调试代码已注释
  // WriteLn('  fpdev package repo list                         列出仓库');  // 调试代码已注释
  // WriteLn('  fpdev package clean <sandbox|cache|all>         清理构建/缓存目录');  // 调试代码已注释
  // WriteLn('');  // 调试代码已注释
  // WriteLn('示例:');  // 调试代码已注释
  // WriteLn('  fpdev package install synapse                   安装synapse包');  // 调试代码已注释
  // WriteLn('  fpdev package install synapse 1.2.0             安装指定版本');  // 调试代码已注释
  // WriteLn('  fpdev package list --all                        列出所有可用包');  // 调试代码已注释
  // WriteLn('  fpdev package install-local ./mypackage         从本地安装包');  // 调试代码已注释
    Exit;
  end;

  ConfigManager := TFPDevConfigManager.Create;
  try
    if not ConfigManager.LoadConfig then
      ConfigManager.CreateDefaultConfig;

    PackageManager := TPackageManager.Create(ConfigManager);
    try
      Command := LowerCase(aParams[0]);

      case Command of
        'install':
        begin
          if Length(aParams) < 2 then
          begin
  // WriteLn('错误: 请指定要安装的包名');  // 调试代码已注释
  // WriteLn('用法: fpdev package install <package> [version] [--keep-build-artifacts]');  // 调试代码已注释
            Exit;
          end;

          PackageName := aParams[1];
          Version := '';
          // 解析可选参数 [version] [--keep-build-artifacts]
          if Length(aParams) > 2 then
          begin
            if (LeftStr(aParams[2], 2) = '--') then
            begin
              // 直接是 flag，无版本
              if SameText(aParams[2], '--keep-build-artifacts') then
                PackageManager.SetKeepBuildArtifacts(True);
            end
            else
              Version := aParams[2];
          end;
          if Length(aParams) > 3 then
          begin
            if SameText(aParams[3], '--keep-build-artifacts') then
              PackageManager.SetKeepBuildArtifacts(True);
          end;

          PackageManager.InstallPackage(PackageName, Version);
        end;

        'uninstall':
        begin
          if Length(aParams) < 2 then
          begin
  // WriteLn('错误: 请指定要卸载的包名');  // 调试代码已注释
  // WriteLn('用法: fpdev package uninstall <package>');  // 调试代码已注释
            Exit;
          end;

          PackageName := aParams[1];
          PackageManager.UninstallPackage(PackageName);
        end;

        'update':
        begin
          if Length(aParams) < 2 then
          begin
  // WriteLn('错误: 请指定要更新的包名');  // 调试代码已注释
  // WriteLn('用法: fpdev package update <package>');  // 调试代码已注释
            Exit;
          end;

          PackageName := aParams[1];
          PackageManager.UpdatePackage(PackageName);
        end;

        'list':
        begin
          ShowAll := (Length(aParams) > 1) and SameText(aParams[1], '--all');
          PackageManager.ListPackages(ShowAll);
        end;

        'search':
        begin
          if Length(aParams) < 2 then
          begin
  // WriteLn('错误: 请指定搜索关键词');  // 调试代码已注释
  // WriteLn('用法: fpdev package search <query>');  // 调试代码已注释
            Exit;
          end;

          PackageManager.SearchPackages(aParams[1]);
        end;

        'info':
        begin
          if Length(aParams) < 2 then
          begin
  // WriteLn('错误: 请指定要查看信息的包名');  // 调试代码已注释
            WriteLn('Usage: fpdev package info <package>');
            Exit;
          end;

          PackageName := aParams[1];
          PackageManager.ShowPackageInfo(PackageName);
        end;

        'deps':
        begin
          if Length(aParams) < 2 then
          begin
  // WriteLn('错误: 请指定要查看依赖的包名');  // 调试代码已注释
  // WriteLn('用法: fpdev package deps <package>');  // 调试代码已注释
            Exit;
          end;

          PackageName := aParams[1];
          PackageManager.ShowPackageDependencies(PackageName);
        end;

        'verify':
        begin
          if Length(aParams) < 2 then
          begin
  // WriteLn('错误: 请指定要验证的包名');  // 调试代码已注释
  // WriteLn('用法: fpdev package verify <package>');  // 调试代码已注释
            Exit;
          end;

          PackageName := aParams[1];
          PackageManager.VerifyPackage(PackageName);
        end;
        'clean':
        begin
          if (Length(aParams) < 2) or ((LowerCase(aParams[1])<>'sandbox') and (LowerCase(aParams[1])<>'cache') and (LowerCase(aParams[1])<>'all')) then
          begin
  // WriteLn('用法: fpdev package clean <sandbox|cache|all>');  // 调试代码已注释
            Exit;
          end;
          // 可选: [--dry-run] [--yes]
          if Length(aParams)>=3 then
          begin
            if SameText(aParams[2], '--dry-run') then
            begin
              if (LowerCase(aParams[1])='sandbox') or (LowerCase(aParams[1])='all') then
  // WriteLn('[dry-run] 将清理: ', GetSandboxDir);  // 调试代码已注释
              if (LowerCase(aParams[1])='cache') or (LowerCase(aParams[1])='all') then
  // WriteLn('[dry-run] 将清理: ', IncludeTrailingPathDelimiter(GetCacheDir)+'packages');  // 调试代码已注释
              Exit;
            end
            else if SameText(aParams[2], '--yes') then
            begin
              if PackageManager.Clean(aParams[1]) then
  // WriteLn('✓ 清理完成')  // 调试代码已注释
              else
  // WriteLn('警告: 清理过程中有部分文件无法删除');  // 调试代码已注释
              Exit;
            end;
          end;
          Write('确定要清理吗? [y/N] ');
          ReadLn(Version);
          if SameText(Trim(Version), 'y') or SameText(Trim(Version), 'yes') then
          begin
            if PackageManager.Clean(aParams[1]) then
  // WriteLn('✓ 清理完成')  // 调试代码已注释
            else
  // WriteLn('警告: 清理过程中有部分文件无法删除');  // 调试代码已注释
          end
          else
  // WriteLn('已取消');  // 调试代码已注释

        end;


        'install-local':
        begin
          if Length(aParams) < 2 then
          begin
  // WriteLn('错误: 请指定包的本地路径');  // 调试代码已注释
  // WriteLn('用法: fpdev package install-local <path>');  // 调试代码已注释
            Exit;
          end;

          PackageManager.InstallFromLocal(aParams[1]);
        end;

        'create':
        begin
          if Length(aParams) < 3 then
          begin
  // WriteLn('错误: 请指定包名和路径');  // 调试代码已注释
  // WriteLn('用法: fpdev package create <name> <path>');  // 调试代码已注释
            Exit;
          end;

          PackageManager.CreatePackage(aParams[1], aParams[2]);
        end;

        'publish':
        begin
          if Length(aParams) < 2 then
          begin
  // WriteLn('错误: 请指定要发布的包名');  // 调试代码已注释
  // WriteLn('用法: fpdev package publish <package>');  // 调试代码已注释
            Exit;
          end;

          PackageName := aParams[1];
          PackageManager.PublishPackage(PackageName);
        end;

        'repo':
        begin
          if Length(aParams) < 2 then

          begin
  // WriteLn('错误: 请指定仓库操作');  // 调试代码已注释
  // WriteLn('用法: fpdev package repo <add|remove|update|list> [args]');  // 调试代码已注释
            Exit;
          end;

          case LowerCase(aParams[1]) of
            'add':
            begin
              if Length(aParams) < 4 then
              begin
  // WriteLn('错误: 请指定仓库名和URL');  // 调试代码已注释
  // WriteLn('用法: fpdev package repo add <name> <url>');  // 调试代码已注释
                Exit;
              end;
              PackageManager.AddRepository(aParams[2], aParams[3]);
            end;

            'remove':
            begin
              if Length(aParams) < 3 then
              begin
  // WriteLn('错误: 请指定要删除的仓库名');  // 调试代码已注释
  // WriteLn('用法: fpdev package repo remove <name>');  // 调试代码已注释
                Exit;
              end;
              PackageManager.RemoveRepository(aParams[2]);
            end;

            'update':
              PackageManager.UpdateRepositories;

            'list':
              PackageManager.ListRepositories;

          else
  // WriteLn('错误: 未知的仓库操作: ', aParams[1]);  // 调试代码已注释
          end;
        end;

      else
  // WriteLn('错误: 未知的命令: ', Command);  // 调试代码已注释
  // WriteLn('使用 "fpdev package" 查看帮助信息');  // 调试代码已注释
      end;

    finally
      PackageManager.Free;
    end;

    ConfigManager.SaveConfig;

  finally
    ConfigManager.Free;
  end;

end;


function TPackageManager.GetAvailablePackageList: TPackageArray;
begin
  Result := GetAvailablePackages;
end;

end.
