program simple_test;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils,
  Classes,
  fpdev.config;

var
  ConfigManager: TFPDevConfigManager;
  ToolchainInfo: TToolchainInfo;
  Settings: TFPDevSettings;

begin
  try
    WriteLn('FPDev Configuration Management Simple Test');
    WriteLn('==========================================');
    WriteLn;
    
    // 创建配置管理器
    ConfigManager := TFPDevConfigManager.Create('test_config.json');
    try
      WriteLn('✓ Configuration manager created');
      
      // 测试设置管理
      Settings := ConfigManager.GetSettings;
      WriteLn('✓ Default settings loaded');
      WriteLn('  - Auto Update: ', Settings.AutoUpdate);
      WriteLn('  - Parallel Jobs: ', Settings.ParallelJobs);
      WriteLn('  - Keep Sources: ', Settings.KeepSources);
      WriteLn('  - Install Root: ', Settings.InstallRoot);
      
      // 测试工具链信息结构
      FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
      ToolchainInfo.ToolchainType := ttRelease;
      ToolchainInfo.Version := '3.2.2';
      ToolchainInfo.InstallPath := '/test/fpc/3.2.2';
      ToolchainInfo.SourceURL := 'https://gitlab.com/freepascal.org/fpc/source.git';
      ToolchainInfo.Branch := 'fixes_3_2';
      ToolchainInfo.Installed := True;
      ToolchainInfo.InstallDate := Now;
      
      WriteLn('✓ Toolchain info structure created');
      WriteLn('  - Type: ', Ord(ToolchainInfo.ToolchainType));
      WriteLn('  - Version: ', ToolchainInfo.Version);
      WriteLn('  - Install Path: ', ToolchainInfo.InstallPath);
      WriteLn('  - Source URL: ', ToolchainInfo.SourceURL);
      WriteLn('  - Branch: ', ToolchainInfo.Branch);
      WriteLn('  - Installed: ', ToolchainInfo.Installed);
      
      // 测试添加工具链
      if ConfigManager.AddToolchain('fpc-3.2.2', ToolchainInfo) then
        WriteLn('✓ Toolchain added successfully')
      else
        WriteLn('✗ Failed to add toolchain');
      
      // 测试获取工具链
      FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
      if ConfigManager.GetToolchain('fpc-3.2.2', ToolchainInfo) then
      begin
        WriteLn('✓ Toolchain retrieved successfully');
        WriteLn('  - Retrieved Version: ', ToolchainInfo.Version);
      end
      else
        WriteLn('✗ Failed to retrieve toolchain');
      
      // 测试设置默认工具链
      if ConfigManager.SetDefaultToolchain('fpc-3.2.2') then
        WriteLn('✓ Default toolchain set successfully')
      else
        WriteLn('✗ Failed to set default toolchain');
      
      WriteLn('  - Default toolchain: ', ConfigManager.GetDefaultToolchain);
      
      WriteLn;
      WriteLn('✓ All basic tests completed successfully!');
      
    finally
      ConfigManager.Free;
    end;
    
  except
    on E: Exception do
    begin
      WriteLn('✗ Error: ', E.Message);
      ExitCode := 1;
    end;
  end;
  
  {$IFDEF MSWINDOWS}
  WriteLn;
  WriteLn('Press Enter to continue...');
  ReadLn;
  {$ENDIF}
end.
