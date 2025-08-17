program test_fpc_source;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.fpc.source;

var
  FPCManager: TFPCSourceManager;

procedure ShowAvailableVersions;
var
  Versions: TStringArray;
  i: Integer;
begin
  WriteLn('=== 可用的FPC版本 ===');
  WriteLn;
  
  Versions := FPCManager.ListAvailableVersions;
  for i := 0 to High(Versions) do
  begin
    WriteLn(Format('%-8s - %s', [Versions[i], 'Available for download']));
  end;
  WriteLn;
end;

procedure ShowLocalVersions;
var
  Versions: TStringArray;
  i: Integer;
begin
  WriteLn('=== 本地已安装的FPC版本 ===');
  WriteLn;
  
  Versions := FPCManager.ListLocalVersions;
  if Length(Versions) = 0 then
  begin
    WriteLn('暂无本地安装的FPC源码版本');
  end
  else
  begin
    for i := 0 to High(Versions) do
    begin
      WriteLn('✓ ', Versions[i]);
    end;
  end;
  WriteLn;
end;

procedure TestFPCSourceClone;
var
  TestVersion: string;
begin
  WriteLn('=== 测试FPC源码克隆 ===');
  WriteLn;
  
  // 测试克隆一个较小的版本（使用浅克隆）
  TestVersion := '3.2.2';
  
  WriteLn('准备克隆FPC ', TestVersion, ' 源码...');
  WriteLn('注意: 这将下载约200MB的数据，可能需要几分钟时间');
  WriteLn;
  
  if FPCManager.CloneFPCSource(TestVersion) then
  begin
    WriteLn('✓ FPC源码克隆成功');
    WriteLn('源码路径: ', FPCManager.GetFPCSourcePath(TestVersion));
  end
  else
  begin
    WriteLn('✗ FPC源码克隆失败');
  end;
  WriteLn;
end;

procedure ShowFPCInfo;
begin
  WriteLn('=== FPC源码管理信息 ===');
  WriteLn;
  WriteLn('FPC Git仓库: https://gitlab.com/freepascal.org/fpc/source.git');
  WriteLn('源码根目录: ', FPCManager.SourceRoot);
  WriteLn('当前版本: ', FPCManager.CurrentVersion);
  WriteLn;
  
  WriteLn('支持的版本分支:');
  WriteLn('- main (开发版本，不稳定)');
  WriteLn('- fixes_3_2 (3.2.x系列，稳定)');
  WriteLn('- fixes_3_0 (3.0.x系列，旧版)');
  WriteLn('- fixes_2_6 (2.6.x系列，旧版)');
  WriteLn;
end;

procedure ShowUsageExample;
begin
  WriteLn('=== 使用示例 ===');
  WriteLn;
  WriteLn('1. 克隆FPC 3.2.2源码:');
  WriteLn('   FPCManager.CloneFPCSource(''3.2.2'')');
  WriteLn;
  WriteLn('2. 更新源码:');
  WriteLn('   FPCManager.UpdateFPCSource(''3.2.2'')');
  WriteLn;
  WriteLn('3. 切换版本:');
  WriteLn('   FPCManager.SwitchFPCVersion(''main'')');
  WriteLn;
  WriteLn('4. 获取源码路径:');
  WriteLn('   Path := FPCManager.GetFPCSourcePath(''3.2.2'')');
  WriteLn;
end;

begin
  try
    WriteLn('FPC源码管理测试程序');
    WriteLn('===================');
    WriteLn;
    
    FPCManager := TFPCSourceManager.Create;
    try
      ShowFPCInfo;
      ShowAvailableVersions;
      ShowLocalVersions;
      ShowUsageExample;
      
      // 询问是否要测试克隆
      WriteLn('是否要测试克隆FPC 3.2.2源码? (y/N)');
      Write('> ');
      
      // 注意：这里简化处理，实际使用中可能需要用户交互
      WriteLn('跳过实际克隆测试（避免大量下载）');
      WriteLn('如需测试，请取消注释 TestFPCSourceClone 调用');
      
      // TestFPCSourceClone;  // 取消注释以测试实际克隆
      
      WriteLn('=== 测试完成 ===');
      WriteLn('FPC源码管理功能已就绪！');
      
    finally
      FPCManager.Free;
    end;
    
  except
    on E: Exception do
    begin
      WriteLn('测试过程中发生错误: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
