unit fpdev.fpc.utils;

{$mode objfpc}{$H+}

{
  FPC Utils
  
  共享工具函数模块，提供项目根目录查找、安装作用域检测、
  归档文件解压、校验和验证等通用功能。
  
  此模块是消除代码重复的关键，所有模块应使用此处的函数
  而不是各自实现。
}

interface

uses
  SysUtils, Classes, fpdev.types, fpdev.fpc.types;

type
  { TArchiveFormat - 归档文件格式 }
  TArchiveFormat = (
    afUnknown,   // 未知格式
    afZip,       // ZIP 格式
    afTarGz,     // TAR.GZ 格式
    afTar        // TAR 格式
  );

{ 项目根目录查找 - 向上遍历查找 .fpdev 目录 }
function FindProjectRoot(const AStartDir: string): string;

{ 安装作用域检测 - 根据当前目录判断是项目级还是用户级 }
function DetectInstallScope(const ACurrentDir: string): TInstallScope;

{ 归档格式检测 - 根据文件扩展名判断格式 }
function DetectArchiveFormat(const AFilePath: string): TArchiveFormat;

{ 归档文件解压 - 支持 ZIP 和 TAR.GZ 格式 }
function ExtractArchive(const AArchivePath, ADestPath: string): TOperationResult;

{ ZIP 文件解压 }
function ExtractZip(const AArchivePath, ADestPath: string): TOperationResult;

{ TAR.GZ 文件解压 }
function ExtractTarGz(const AArchivePath, ADestPath: string): TOperationResult;

{ 校验和计算 - 计算文件的 SHA256 }
function CalculateFileSHA256(const AFilePath: string): string;

{ 校验和验证 - 验证文件的 SHA256 是否匹配 }
function VerifyFileSHA256(const AFilePath, AExpectedHash: string): Boolean;

implementation

uses
  Process, zipper, fpdev.hash;

{ FindProjectRoot - 向上遍历查找 .fpdev 目录 }
function FindProjectRoot(const AStartDir: string): string;
var
  Dir, PrevDir: string;
  UserConfigDir: string;
  Candidate: string;
begin
  Result := '';
  Dir := ExcludeTrailingPathDelimiter(ExpandFileName(AStartDir));

  // Avoid mistaking user-level ~/.fpdev as a project marker when scanning upward.
  {$IFDEF MSWINDOWS}
  UserConfigDir := GetEnvironmentVariable('APPDATA');
  if UserConfigDir <> '' then
    UserConfigDir := ExcludeTrailingPathDelimiter(ExpandFileName(UserConfigDir + PathDelim + '.fpdev'))
  else
    UserConfigDir := ExcludeTrailingPathDelimiter(ExpandFileName(GetEnvironmentVariable('USERPROFILE') + PathDelim + '.fpdev'));
  {$ELSE}
  UserConfigDir := ExcludeTrailingPathDelimiter(ExpandFileName(GetEnvironmentVariable('HOME') + PathDelim + '.fpdev'));
  {$ENDIF}

  while Dir <> '' do
  begin
    Candidate := ExcludeTrailingPathDelimiter(ExpandFileName(Dir + PathDelim + '.fpdev'));
    if DirectoryExists(Candidate) then
    begin
      if (UserConfigDir = '') or (not SameText(Candidate, UserConfigDir)) then
      begin
        Result := ExcludeTrailingPathDelimiter(Dir);
        Exit;
      end;
    end;

    PrevDir := Dir;
    Dir := ExtractFileDir(Dir);

    // 防止无限循环（到达根目录）
    if Dir = PrevDir then
      Break;
  end;
end;

{ DetectInstallScope - 检测安装作用域 }
function DetectInstallScope(const ACurrentDir: string): TInstallScope;
var
  ProjectRoot: string;
begin
  Result := isUser;
  
  ProjectRoot := FindProjectRoot(ACurrentDir);
  if ProjectRoot <> '' then
    Result := isProject;
end;

{ DetectArchiveFormat - 检测归档格式 }
function DetectArchiveFormat(const AFilePath: string): TArchiveFormat;
var
  Ext, LowerPath: string;
begin
  Result := afUnknown;
  LowerPath := LowerCase(AFilePath);
  
  // 检查 .tar.gz 或 .tgz
  if (Pos('.tar.gz', LowerPath) > 0) or (Pos('.tgz', LowerPath) > 0) then
  begin
    Result := afTarGz;
    Exit;
  end;
  
  // 检查扩展名
  Ext := LowerCase(ExtractFileExt(AFilePath));
  
  if Ext = '.zip' then
    Result := afZip
  else if Ext = '.tar' then
    Result := afTar
  else if Ext = '.gz' then
  begin
    // 可能是 .tar.gz，再检查一次
    if Pos('.tar', LowerPath) > 0 then
      Result := afTarGz;
  end;
end;

{ ExtractZip - 解压 ZIP 文件 }
function ExtractZip(const AArchivePath, ADestPath: string): TOperationResult;
var
  Unzipper: TUnZipper;
begin
  Result := OperationSuccess;
  
  if not FileExists(AArchivePath) then
  begin
    Result := OperationError(ecFileSystemError, '归档文件不存在: ' + AArchivePath);
    Exit;
  end;
  
  try
    if not DirectoryExists(ADestPath) then
      ForceDirectories(ADestPath);
    
    Unzipper := TUnZipper.Create;
    try
      Unzipper.FileName := AArchivePath;
      Unzipper.OutputPath := ADestPath;
      Unzipper.Examine;
      Unzipper.UnZipAllFiles;
    finally
      Unzipper.Free;
    end;
  except
    on E: Exception do
      Result := OperationError(ecExtractionFailed, 'ZIP 解压失败: ' + E.Message);
  end;
end;

{ ExtractTarGz - 解压 TAR.GZ 文件 }
function ExtractTarGz(const AArchivePath, ADestPath: string): TOperationResult;
var
  Process: TProcess;
  ExitCode: Integer;
begin
  Result := OperationSuccess;
  
  if not FileExists(AArchivePath) then
  begin
    Result := OperationError(ecFileSystemError, '归档文件不存在: ' + AArchivePath);
    Exit;
  end;
  
  try
    if not DirectoryExists(ADestPath) then
      ForceDirectories(ADestPath);
    
    Process := TProcess.Create(nil);
    try
      {$IFDEF MSWINDOWS}
      // Windows: 使用 PowerShell 或 tar（Windows 10+ 内置）
      Process.Executable := 'tar';
      Process.Parameters.Add('-xzf');
      Process.Parameters.Add(AArchivePath);
      Process.Parameters.Add('-C');
      Process.Parameters.Add(ADestPath);
      {$ELSE}
      // Linux/macOS: 使用系统 tar
      Process.Executable := 'tar';
      Process.Parameters.Add('-xzf');
      Process.Parameters.Add(AArchivePath);
      Process.Parameters.Add('-C');
      Process.Parameters.Add(ADestPath);
      {$ENDIF}
      
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
      Process.Execute;
      
      ExitCode := Process.ExitStatus;
      if ExitCode <> 0 then
        Result := OperationError(ecExtractionFailed, 
          'TAR.GZ 解压失败，退出码: ' + IntToStr(ExitCode));
    finally
      Process.Free;
    end;
  except
    on E: Exception do
      Result := OperationError(ecExtractionFailed, 'TAR.GZ 解压异常: ' + E.Message);
  end;
end;

{ ExtractArchive - 统一的归档解压函数 }
function ExtractArchive(const AArchivePath, ADestPath: string): TOperationResult;
var
  Format: TArchiveFormat;
begin
  Format := DetectArchiveFormat(AArchivePath);
  
  case Format of
    afZip:
      Result := ExtractZip(AArchivePath, ADestPath);
    afTarGz:
      Result := ExtractTarGz(AArchivePath, ADestPath);
    afTar:
      begin
        // TAR format not yet supported, can be extended
        Result := OperationError(ecExtractionFailed, 'Pure TAR format not supported, please use TAR.GZ');
      end;
  else
    Result := OperationError(ecExtractionFailed,
      'Unsupported archive format: ' + ExtractFileExt(AArchivePath));
  end;
end;

{ CalculateFileSHA256 - 计算文件 SHA256 }
function CalculateFileSHA256(const AFilePath: string): string;
begin
  Result := '';
  
  if not FileExists(AFilePath) then
    Exit;
  
  try
    // 使用现有的 fpdev.hash 模块
    Result := SHA256FileHex(AFilePath);
  except
    on E: Exception do
      Result := '';
  end;
end;

{ VerifyFileSHA256 - 验证文件 SHA256 }
function VerifyFileSHA256(const AFilePath, AExpectedHash: string): Boolean;
var
  ActualHash: string;
begin
  Result := False;
  
  if AExpectedHash = '' then
    Exit;
  
  ActualHash := CalculateFileSHA256(AFilePath);
  if ActualHash = '' then
    Exit;
  
  // 不区分大小写比较
  Result := SameText(ActualHash, AExpectedHash);
end;

end.
