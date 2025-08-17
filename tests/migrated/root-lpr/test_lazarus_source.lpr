program test_lazarus_source;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.lazarus.source;

var
  LazarusManager: TLazarusSourceManager;

procedure ShowAvailableVersions;
var
  Versions: TStringArray;
  i: Integer;
begin
  WriteLn('=== 可用的Lazarus版本 ===');
  WriteLn;
  
  Versions := LazarusManager.ListAvailableVersions;
  for i := 0 to High(Versions) do
  begin
    WriteLn(Format('%-8s - %s', [Versions[i], LazarusManager.GetLazarusVersion(Versions[i])]));
  end;
  WriteLn;
end;

procedure ShowLocalVersions;
var
  Versions: TStringArray;
  i: Integer;
begin
  WriteLn('=== 本地已安装的Lazarus版本 ===');
  WriteLn;
  
  Versions := LazarusManager.ListLocalVersions;
  if Length(Versions) = 0 then
  begin
    WriteLn('暂无本地安装的Lazarus源码版本');
  end
  else
  begin
    for i := 0 to High(Versions) do
    begin
      WriteLn('✓ Lazarus ', Versions[i]);
      WriteLn('  源码路径: ', LazarusManager.GetLazarusSourcePath(Versions[i]));
      WriteLn('  可执行文件: ', LazarusManager.GetLazarusExecutablePath(Versions[i]));
    end;
  end;
  WriteLn;
end;

procedure TestLazarusSourceClone;
var
  TestVersion: string;
  Input: string;
begin
  WriteLn('=== 测试Lazarus源码克隆 ===');
  WriteLn;
  
  // 测试克隆一个较新的稳定版本
  TestVersion := '3.0';
  
  WriteLn('准备克隆Lazarus ', TestVersion, ' 源码...');
  WriteLn('注意: 这将下载约500MB的数据，可能需要10-20分钟时间');
  WriteLn('建议在网络状况良好时进行');
  WriteLn;
  
  WriteLn('是否继续? (输入 y 继续，其他键跳过)');
  ReadLn(Input);
  
  if SameText(Input, 'y') or SameText(Input, 'yes') then
  begin
    if LazarusManager.CloneLazarusSource(TestVersion) then
    begin
      WriteLn('✓ Lazarus源码克隆成功');
      WriteLn('源码路径: ', LazarusManager.GetLazarusSourcePath(TestVersion));
      
      WriteLn;
      WriteLn('是否尝试构建Lazarus? (输入 y 继续，其他键跳过)');
      ReadLn(Input);
      
      if SameText(Input, 'y') or SameText(Input, 'yes') then
      begin
        WriteLn('开始构建Lazarus...');
        if LazarusManager.BuildLazarus(TestVersion) then
        begin
          WriteLn('✓ Lazarus构建成功');
          WriteLn('可执行文件: ', LazarusManager.GetLazarusExecutablePath(TestVersion));
        end
        else
        begin
          WriteLn('✗ Lazarus构建失败');
          WriteLn('请检查FPC编译器是否正确安装');
        end;
      end;
    end
    else
    begin
      WriteLn('✗ Lazarus源码克隆失败');
    end;
  end
  else
  begin
    WriteLn('跳过实际克隆测试');
  end;
  
  WriteLn;
end;

procedure ShowLazarusInfo;
begin
  WriteLn('=== Lazarus源码管理信息 ===');
  WriteLn;
  WriteLn('Lazarus Git仓库: https://gitlab.com/freepascal.org/lazarus/lazarus.git');
  WriteLn('源码根目录: ', LazarusManager.SourceRoot);
  WriteLn('当前版本: ', LazarusManager.CurrentVersion);
  WriteLn;
  
  WriteLn('支持的版本分支:');
  WriteLn('- main (开发版本，不稳定)');
  WriteLn('- lazarus_3_0 (3.0系列，推荐)');
  WriteLn('- lazarus_2_2 (2.2系列，稳定)');
  WriteLn('- lazarus_2_0 (2.0系列，旧版)');
  WriteLn('- lazarus_1_8 (1.8系列，旧版)');
  WriteLn;
  
  WriteLn('版本与FPC对应关系:');
  WriteLn('- Lazarus 3.0   -> FPC 3.2.2');
  WriteLn('- Lazarus 2.2.x -> FPC 3.2.2');
  WriteLn('- Lazarus 2.0.x -> FPC 3.2.0');
  WriteLn('- Lazarus 1.8.x -> FPC 3.0.4');
  WriteLn;
end;

procedure ShowUsageExample;
begin
  WriteLn('=== 使用示例 ===');
  WriteLn;
  WriteLn('1. 克隆Lazarus 3.0源码:');
  WriteLn('   LazarusManager.CloneLazarusSource(''3.0'')');
  WriteLn;
  WriteLn('2. 更新源码:');
  WriteLn('   LazarusManager.UpdateLazarusSource(''3.0'')');
  WriteLn;
  WriteLn('3. 构建Lazarus:');
  WriteLn('   LazarusManager.BuildLazarus(''3.0'')');
  WriteLn;
  WriteLn('4. 启动Lazarus:');
  WriteLn('   LazarusManager.LaunchLazarus(''3.0'')');
  WriteLn;
  WriteLn('5. 获取源码路径:');
  WriteLn('   Path := LazarusManager.GetLazarusSourcePath(''3.0'')');
  WriteLn;
  
  WriteLn('命令行使用:');
  WriteLn('  fpdev source lazarus 3.0    - 克隆Lazarus 3.0');
  WriteLn('  fpdev source list            - 列出本地版本');
  WriteLn('  fpdev source available       - 列出可用版本');
  WriteLn;
end;

procedure TestVersionManagement;
begin
  WriteLn('=== 测试版本管理功能 ===');
  WriteLn;
  
  WriteLn('版本检查测试:');
  WriteLn('- 3.0版本可用: ', LazarusManager.IsVersionAvailable('3.0'));
  WriteLn('- main版本可用: ', LazarusManager.IsVersionAvailable('main'));
  WriteLn('- 无效版本: ', LazarusManager.IsVersionAvailable('invalid'));
  WriteLn;
  
  WriteLn('路径生成测试:');
  WriteLn('- 3.0源码路径: ', LazarusManager.GetLazarusSourcePath('3.0'));
  WriteLn('- 3.0构建路径: ', LazarusManager.GetLazarusBuildPath('3.0'));
  WriteLn('- 3.0可执行文件: ', LazarusManager.GetLazarusExecutablePath('3.0'));
  WriteLn;
  
  WriteLn('版本信息测试:');
  WriteLn('- 3.0版本描述: ', LazarusManager.GetLazarusVersion('3.0'));
  WriteLn('- main版本描述: ', LazarusManager.GetLazarusVersion('main'));
  WriteLn;
end;

begin
  try
    WriteLn('Lazarus源码管理测试程序');
    WriteLn('========================');
    WriteLn;
    
    LazarusManager := TLazarusSourceManager.Create;
    try
      ShowLazarusInfo;
      ShowAvailableVersions;
      ShowLocalVersions;
      TestVersionManagement;
      ShowUsageExample;
      TestLazarusSourceClone;
      
      WriteLn('=== 测试完成 ===');
      WriteLn('Lazarus源码管理功能已就绪！');
      WriteLn;
      WriteLn('下一步建议:');
      WriteLn('1. 集成到主FPDev程序');
      WriteLn('2. 添加构建和启动功能');
      WriteLn('3. 实现版本切换管理');
      WriteLn('4. 添加依赖检查功能');
      
    finally
      LazarusManager.Free;
    end;
    
  except
    on E: Exception do
    begin
      WriteLn('测试过程中发生错误: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
  
  WriteLn;
  WriteLn('按Enter键退出...');
  ReadLn;
end.
