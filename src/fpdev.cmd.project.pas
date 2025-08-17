unit fpdev.cmd.project;

{$codepage utf8}

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cmd.project

FreePascal 项目管理和模板系统


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
  SysUtils, Classes, Process,
  fpdev.config, fpdev.utils, fpdev.terminal,
  git2.api, git2.impl;

type
  { TProjectType }
  TProjectType = (
    ptConsole, ptGUI, ptLibrary, ptPackage, ptWebApp, ptService, ptGame, ptCustom
  );

  { TProjectTemplate }
  TProjectTemplate = record
    Name: string;
    DisplayName: string;
    Description: string;
    ProjectType: TProjectType;
    Available: Boolean;
  end;

  TProjectTemplateArray = array of TProjectTemplate;

  { TProjectManager }
  TProjectManager = class
  private
    FConfigManager: TFPDevConfigManager;
    FTemplatesRoot: string;

    function GetAvailableTemplates: TProjectTemplateArray;
    function CreateFromTemplate(const ATemplateName, AProjectName, ATargetDir: string): Boolean;
    function GenerateProjectFiles(const ATemplate: TProjectTemplate; const AProjectName, ATargetDir: string): Boolean;
    function ValidateProjectName(const AProjectName: string): Boolean;
    function GetTemplateInfo(const ATemplateName: string): TProjectTemplate;
    function SetupProjectEnvironment(const AProjectDir: string): Boolean;

  public
    constructor Create(AConfigManager: TFPDevConfigManager);
    destructor Destroy; override;

    // 项目创建
    function CreateProject(const ATemplateName, AProjectName, ATargetDir: string): Boolean;
    function ListTemplates: Boolean;
    function ShowTemplateInfo(const ATemplateName: string): Boolean;

    // 项目管理
    function BuildProject(const AProjectDir: string; const ATarget: string = ''): Boolean;
    function CleanProject(const AProjectDir: string): Boolean;
    function TestProject(const AProjectDir: string): Boolean;
    function RunProject(const AProjectDir: string; const AArgs: string = ''): Boolean;

    // 模板管理
    function InstallTemplate(const ATemplatePath: string): Boolean;
    function RemoveTemplate(const ATemplateName: string): Boolean;
    function UpdateTemplates: Boolean;
  end;

// 主要执行函数
procedure execute(const aParams: array of string);

implementation

const
  // 内置项目模板
  BUILTIN_TEMPLATES: array[0..6] of TProjectTemplate = (
    (Name: 'console'; DisplayName: 'Console Application'; Description: 'Simple console application'; ProjectType: ptConsole; Available: True),
    (Name: 'gui'; DisplayName: 'GUI Application'; Description: 'Lazarus GUI application'; ProjectType: ptGUI; Available: True),
    (Name: 'library'; DisplayName: 'Dynamic Library'; Description: 'Shared library project'; ProjectType: ptLibrary; Available: True),
    (Name: 'package'; DisplayName: 'Lazarus Package'; Description: 'Lazarus package project'; ProjectType: ptPackage; Available: True),
    (Name: 'webapp'; DisplayName: 'Web Application'; Description: 'Pascal web application'; ProjectType: ptWebApp; Available: True),
    (Name: 'service'; DisplayName: 'System Service'; Description: 'Background service application'; ProjectType: ptService; Available: True),
    (Name: 'game'; DisplayName: 'Game Project'; Description: 'Simple game project template'; ProjectType: ptGame; Available: True)
  );

{ TProjectManager }

constructor TProjectManager.Create(AConfigManager: TFPDevConfigManager);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;

  Settings := FConfigManager.GetSettings;
  FTemplatesRoot := Settings.InstallRoot + PathDelim + 'templates';

  // 确保模板目录存在
  if not DirectoryExists(FTemplatesRoot) then
    ForceDirectories(FTemplatesRoot);
end;

destructor TProjectManager.Destroy;
begin
  inherited Destroy;
end;

function TProjectManager.ValidateProjectName(const AProjectName: string): Boolean;
begin
  Result := (AProjectName <> '') and
            (Pos(' ', AProjectName) = 0) and
            (Pos('/', AProjectName) = 0) and
            (Pos('\', AProjectName) = 0);
end;

function TProjectManager.GetTemplateInfo(const ATemplateName: string): TProjectTemplate;
var
  i: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);

  for i := 0 to High(BUILTIN_TEMPLATES) do
  begin
    if SameText(BUILTIN_TEMPLATES[i].Name, ATemplateName) then
    begin
      Result := BUILTIN_TEMPLATES[i];
      Break;
    end;
  end;
end;

function TProjectManager.GetAvailableTemplates: TProjectTemplateArray;
var
  i: Integer;
begin
  SetLength(Result, Length(BUILTIN_TEMPLATES));
  for i := 0 to High(BUILTIN_TEMPLATES) do
    Result[i] := BUILTIN_TEMPLATES[i];
end;

function TProjectManager.GenerateProjectFiles(const ATemplate: TProjectTemplate; const AProjectName, ATargetDir: string): Boolean;
var
  MainFile: TextFile;
  ProjectFile: TextFile;
  MainFileName, ProjectFileName: string;
begin
  Result := False;

  try
    case ATemplate.ProjectType of
      ptConsole:
      begin
        // 创建主程序文件
        MainFileName := ATargetDir + PathDelim + AProjectName + '.lpr';
        AssignFile(MainFile, MainFileName);
        Rewrite(MainFile);
        WriteLn(MainFile, 'program ', AProjectName, ';');
        WriteLn(MainFile, '');
        WriteLn(MainFile, '{$mode objfpc}{$H+}');
        WriteLn(MainFile, '');
        WriteLn(MainFile, 'uses');
        WriteLn(MainFile, '  SysUtils;');
        WriteLn(MainFile, '');
        WriteLn(MainFile, 'begin');
        WriteLn(MainFile, '  WriteLn(''Hello from ', AProjectName, '!'');');
        WriteLn(MainFile, 'end.');
        CloseFile(MainFile);
      end;

      ptGUI:
      begin
        // 创建Lazarus项目文件
        ProjectFileName := ATargetDir + PathDelim + AProjectName + '.lpi';
        AssignFile(ProjectFile, ProjectFileName);
        Rewrite(ProjectFile);
        WriteLn(ProjectFile, '<?xml version="1.0" encoding="UTF-8"?>');
        WriteLn(ProjectFile, '<CONFIG>');
        WriteLn(ProjectFile, '  <ProjectOptions>');
        WriteLn(ProjectFile, '    <Version Value="12"/>');
        WriteLn(ProjectFile, '    <General>');
        WriteLn(ProjectFile, '      <Title Value="', AProjectName, '"/>');
        WriteLn(ProjectFile, '    </General>');
        WriteLn(ProjectFile, '  </ProjectOptions>');
        WriteLn(ProjectFile, '</CONFIG>');
        CloseFile(ProjectFile);

        // 创建主程序文件
        MainFileName := ATargetDir + PathDelim + AProjectName + '.lpr';
        AssignFile(MainFile, MainFileName);
        Rewrite(MainFile);
        WriteLn(MainFile, 'program ', AProjectName, ';');
        WriteLn(MainFile, '');
        WriteLn(MainFile, '{$mode objfpc}{$H+}');
        WriteLn(MainFile, '');
        WriteLn(MainFile, 'uses');
        WriteLn(MainFile, '  {$IFDEF UNIX}');
        WriteLn(MainFile, '  cthreads,');
        WriteLn(MainFile, '  {$ENDIF}');
        WriteLn(MainFile, '  Interfaces, Forms;');
        WriteLn(MainFile, '');
        WriteLn(MainFile, 'begin');
        WriteLn(MainFile, '  RequireDerivedFormResource := True;');
        WriteLn(MainFile, '  Application.Initialize;');
        WriteLn(MainFile, '  Application.Run;');
        WriteLn(MainFile, 'end.');
        CloseFile(MainFile);
      end;

    else
      // 默认控制台应用
      MainFileName := ATargetDir + PathDelim + AProjectName + '.lpr';
      AssignFile(MainFile, MainFileName);
      Rewrite(MainFile);
      WriteLn(MainFile, 'program ', AProjectName, ';');
      WriteLn(MainFile, '');
      WriteLn(MainFile, '{$mode objfpc}{$H+}');
      WriteLn(MainFile, '');
      WriteLn(MainFile, 'begin');
      WriteLn(MainFile, '  WriteLn(''Hello from ', AProjectName, '!'');');
      WriteLn(MainFile, 'end.');
      CloseFile(MainFile);
    end;

    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('错误: 生成项目文件时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TProjectManager.CreateFromTemplate(const ATemplateName, AProjectName, ATargetDir: string): Boolean;
var
  Template: TProjectTemplate;
begin
  Result := False;

  Template := GetTemplateInfo(ATemplateName);
  if Template.Name = '' then
  begin
    WriteLn('错误: 未找到模板: ', ATemplateName);
    Exit;
  end;

  try
    // 确保目标目录存在
    if not DirectoryExists(ATargetDir) then
      ForceDirectories(ATargetDir);

    // 生成项目文件
    Result := GenerateProjectFiles(Template, AProjectName, ATargetDir);

  except
    on E: Exception do
    begin
      WriteLn('错误: 从模板创建项目时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TProjectManager.SetupProjectEnvironment(const AProjectDir: string): Boolean;
begin
  Result := True;
  // TODO: 设置项目环境（如创建构建脚本等）
  WriteLn('项目环境设置完成');
end;

function TProjectManager.CreateProject(const ATemplateName, AProjectName, ATargetDir: string): Boolean;
begin
  Result := False;

  if not ValidateProjectName(AProjectName) then
  begin
    WriteLn('错误: 无效的项目名称: ', AProjectName);
    Exit;
  end;

  try
    WriteLn('创建项目 ', AProjectName, ' 使用模板 ', ATemplateName);
    WriteLn('目标目录: ', ATargetDir);

    // 从模板创建项目
    if not CreateFromTemplate(ATemplateName, AProjectName, ATargetDir) then
    begin
      WriteLn('错误: 从模板创建项目失败');
      Exit;
    end;

    // 设置项目环境
    if not SetupProjectEnvironment(ATargetDir) then
    begin
      WriteLn('警告: 项目环境设置失败');
    end;

    WriteLn('✓ 项目 ', AProjectName, ' 创建成功');
    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('错误: 创建项目时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TProjectManager.ListTemplates: Boolean;
var
  Templates: TProjectTemplateArray;
  i: Integer;
begin
  Result := True;

  try
    Templates := GetAvailableTemplates;

    WriteLn('可用的项目模板:');
    WriteLn('');
    WriteLn('模板名      类型        描述');
    WriteLn('----------------------------------------');

    for i := 0 to High(Templates) do
    begin
      Write(Format('%-10s  ', [Templates[i].Name]));

      case Templates[i].ProjectType of
        ptConsole: Write('控制台      ');
        ptGUI: Write('GUI应用     ');
        ptLibrary: Write('动态库      ');
        ptPackage: Write('包项目      ');
        ptWebApp: Write('Web应用     ');
        ptService: Write('系统服务    ');
        ptGame: Write('游戏项目    ');
      else
        Write('自定义      ');
      end;

      WriteLn(Templates[i].Description);
    end;

    WriteLn('');
    WriteLn('总计: ', Length(Templates), ' 个模板');

  except
    on E: Exception do
    begin
      WriteLn('错误: 列出模板时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TProjectManager.ShowTemplateInfo(const ATemplateName: string): Boolean;
var
  Template: TProjectTemplate;
begin
  Result := False;

  try
    Template := GetTemplateInfo(ATemplateName);

    if Template.Name = '' then
    begin
      WriteLn('错误: 未找到模板: ', ATemplateName);
      Exit;
    end;

    WriteLn('模板信息: ', ATemplateName);
    WriteLn('');
    WriteLn('名称: ', Template.Name);
    WriteLn('显示名称: ', Template.DisplayName);
    WriteLn('描述: ', Template.Description);

    Write('类型: ');
    case Template.ProjectType of
      ptConsole: WriteLn('控制台应用程序');
      ptGUI: WriteLn('GUI应用程序');
      ptLibrary: WriteLn('动态库');
      ptPackage: WriteLn('Lazarus包');
      ptWebApp: WriteLn('Web应用程序');
      ptService: WriteLn('系统服务');
      ptGame: WriteLn('游戏项目');
    else
      WriteLn('自定义');
    end;

    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('错误: 显示模板信息时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TProjectManager.BuildProject(const AProjectDir: string; const ATarget: string): Boolean;
var
  Process: TProcess;
  FoundLPI, FoundLPR: string;
  SR: TSearchRec;
begin
  Result := False;

  if not DirectoryExists(AProjectDir) then
  begin
    WriteLn('错误: 项目目录不存在: ', AProjectDir);
    Exit;
  end;

  try
    WriteLn('构建项目: ', AProjectDir);

    // 优先查找首个 .lpi 项目文件
    FoundLPI := '';
    if FindFirst(AProjectDir + PathDelim + '*.lpi', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Attr and faDirectory) = 0 then
        begin
          FoundLPI := AProjectDir + PathDelim + SR.Name;
          Break;
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    if FoundLPI <> '' then
    begin
      // 使用 lazbuild 构建 Lazarus 项目
      Process := TProcess.Create(nil);
      try
        Process.Executable := 'lazbuild';
        Process.Parameters.Add(FoundLPI);
        if ATarget <> '' then
          Process.Parameters.Add('--cpu=' + ATarget);
        Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
        Process.CurrentDirectory := AProjectDir;

        Process.Execute;
        Result := Process.ExitStatus = 0;
      finally
        Process.Free;
      end;
    end
    else
    begin
      // 查找首个 .lpr（FPC 项目）
      FoundLPR := '';
      if FindFirst(AProjectDir + PathDelim + '*.lpr', faAnyFile, SR) = 0 then
      begin
        repeat
          if (SR.Attr and faDirectory) = 0 then
          begin
            FoundLPR := AProjectDir + PathDelim + SR.Name;
            Break;
          end;
        until FindNext(SR) <> 0;
        FindClose(SR);
      end;

      if FoundLPR <> '' then
      begin
        // 使用 fpc 构建 .lpr（仅用于项目，不用于本地测试/示例）
        Process := TProcess.Create(nil);
        try
          Process.Executable := 'fpc';
          Process.Parameters.Add(ExtractFileName(FoundLPR));
          Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
          Process.CurrentDirectory := AProjectDir;

          Process.Execute;
          Result := Process.ExitStatus = 0;
        finally
          Process.Free;
        end;
      end
      else if FileExists(AProjectDir + PathDelim + 'Makefile') then
      begin
        // 回退使用 make（如果提供 Makefile）
        Process := TProcess.Create(nil);
        try
          Process.Executable := 'make';
          Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
          Process.CurrentDirectory := AProjectDir;

          Process.Execute;
          Result := Process.ExitStatus = 0;
        finally
          Process.Free;
        end;
      end
      else
      begin
        WriteLn('错误: 未找到可构建的项目文件（.lpi/.lpr/Makefile）');
        Exit;
      end;
    end;

    if Result then
      WriteLn('✓ 项目构建成功')
    else
      WriteLn('✗ 项目构建失败');

  except
    on E: Exception do
    begin
      WriteLn('错误: 构建项目时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TProjectManager.CleanProject(const AProjectDir: string): Boolean;
begin
  Result := False;
  WriteLn('清理项目功能暂未实现');
  // TODO: 实现项目清理功能
end;

function TProjectManager.TestProject(const AProjectDir: string): Boolean;
begin
  Result := False;
  WriteLn('测试项目功能暂未实现');
  // TODO: 实现项目测试功能
end;

function TProjectManager.RunProject(const AProjectDir: string; const AArgs: string): Boolean;
begin
  Result := False;
  WriteLn('运行项目功能暂未实现');
  // TODO: 实现项目运行功能
end;

function TProjectManager.InstallTemplate(const ATemplatePath: string): Boolean;
begin
  Result := False;
  WriteLn('安装模板功能暂未实现');
  // TODO: 实现模板安装功能
end;

function TProjectManager.RemoveTemplate(const ATemplateName: string): Boolean;
begin
  Result := False;
  WriteLn('删除模板功能暂未实现');
  // TODO: 实现模板删除功能
end;

function TProjectManager.UpdateTemplates: Boolean;
begin
  Result := False;
  WriteLn('更新模板功能暂未实现');
  {$IFDEF FPDEV_DEPRECATED_GIT_CMD}
  // Deprecated block (will be removed in next milestone)
  // Original inline git command handler (moved out of user-facing scope per fpdev.md)
  // Intentionally disabled by default.
  // ...
  {$ENDIF}
  // TODO: 实现模板更新功能
end;

// 主要执行函数
procedure execute(const aParams: array of string);
var
  ConfigManager: TFPDevConfigManager;
  ProjectManager: TProjectManager;
  Command: string;
  TemplateName, ProjectName, TargetDir: string;
begin
  if Length(aParams) = 0 then
  begin
    WriteLn('FreePascal 项目管理系统');
    WriteLn('');
    WriteLn('用法:');
    WriteLn('  fpdev project new <template> <name> [dir]    创建新项目');
    WriteLn('  fpdev project list                           列出可用模板');
    WriteLn('  fpdev project info <template>                显示模板信息');
    WriteLn('  fpdev project build [dir] [target]           构建项目');
    WriteLn('  fpdev project clean [dir]                    清理项目');
    WriteLn('  fpdev project test [dir]                     测试项目');
    WriteLn('  fpdev project run [dir] [args]               运行项目');
    WriteLn('  fpdev project template install <path>        安装模板');
    WriteLn('  fpdev project template remove <name>         删除模板');
    WriteLn('  fpdev project template update                更新模板');
    {$IFDEF FPDEV_DEPRECATED_GIT_CMD}
    WriteLn('  fpdev project git ...                        [Deprecated] 内部保留，不对用户开放');
    {$ENDIF}
    WriteLn('');
    WriteLn('可用模板:');
    WriteLn('  console    - 控制台应用程序');
    WriteLn('  gui        - Lazarus GUI应用程序');
    WriteLn('  library    - 动态库项目');
    WriteLn('  package    - Lazarus包项目');
    WriteLn('  webapp     - Web应用程序');
    WriteLn('  service    - 系统服务');
    WriteLn('  game       - 游戏项目');
    WriteLn('');
    WriteLn('示例:');
    WriteLn('  fpdev project new console myapp              创建控制台应用');
    WriteLn('  fpdev project new gui myapp ./projects       创建GUI应用到指定目录');
    WriteLn('  fpdev project build ./myapp                  构建项目');
    Exit;
  end;

  ConfigManager := TFPDevConfigManager.Create;
  try
    if not ConfigManager.LoadConfig then
      ConfigManager.CreateDefaultConfig;

    ProjectManager := TProjectManager.Create(ConfigManager);
    try
      Command := LowerCase(aParams[0]);

      case Command of
        'new':
        begin
          if Length(aParams) < 3 then
          begin
            WriteLn('错误: 请指定模板名和项目名');
            WriteLn('用法: fpdev project new <template> <name> [dir]');
            Exit;
          end;

          TemplateName := aParams[1];
          ProjectName := aParams[2];

          if Length(aParams) > 3 then
            TargetDir := aParams[3] + PathDelim + ProjectName
          else
            TargetDir := '.' + PathDelim + ProjectName;

          ProjectManager.CreateProject(TemplateName, ProjectName, TargetDir);
        end;

        'list':
        begin
          ProjectManager.ListTemplates;
        end;

        'info':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定模板名');
            WriteLn('用法: fpdev project info <template>');
            Exit;
          end;

          TemplateName := aParams[1];
          ProjectManager.ShowTemplateInfo(TemplateName);
        end;

        'build':
        begin
          if Length(aParams) > 1 then
            TargetDir := aParams[1]
          else
            TargetDir := '.';

          if Length(aParams) > 2 then
            ProjectManager.BuildProject(TargetDir, aParams[2])
          else
            ProjectManager.BuildProject(TargetDir, '');
        end;

        'clean':
        begin
          if Length(aParams) > 1 then
            TargetDir := aParams[1]
          else
            TargetDir := '.';

          ProjectManager.CleanProject(TargetDir);
        end;

        'test':
        begin
          if Length(aParams) > 1 then
            TargetDir := aParams[1]
          else
            TargetDir := '.';

          ProjectManager.TestProject(TargetDir);
        end;

        'run':
        begin
          if Length(aParams) > 1 then
            TargetDir := aParams[1]
          else
            TargetDir := '.';

          if Length(aParams) > 2 then
            ProjectManager.RunProject(TargetDir, aParams[2])
          else
            ProjectManager.RunProject(TargetDir, '');
        end;

        'template':
        begin
          if Length(aParams) < 2 then
          begin
            WriteLn('错误: 请指定模板操作');
            WriteLn('用法: fpdev project template <install|remove|update> [args]');
            Exit;
          end;

          case LowerCase(aParams[1]) of
            'install':
            begin
              if Length(aParams) < 3 then
              begin
                WriteLn('错误: 请指定模板路径');
                WriteLn('用法: fpdev project template install <path>');
                Exit;
              end;
              ProjectManager.InstallTemplate(aParams[2]);
            end;

            'remove':
            begin
              if Length(aParams) < 3 then
              begin
                WriteLn('错误: 请指定要删除的模板名');
                WriteLn('用法: fpdev project template remove <name>');
                Exit;
              end;
              ProjectManager.RemoveTemplate(aParams[2]);
            end;

            'update':
              ProjectManager.UpdateTemplates;

          else
            WriteLn('错误: 未知的模板操作: ', aParams[1]);
          end;
        end;

      else
        WriteLn('错误: 未知的命令: ', Command);
        WriteLn('使用 "fpdev project" 查看帮助信息');
      end;

    finally
      ProjectManager.Free;
    end;

    ConfigManager.SaveConfig;

  finally
    ConfigManager.Free;
  end;
end;

end.
