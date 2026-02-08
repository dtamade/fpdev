unit fpdev.cmd.fpc.use;

{
  fpdev fpc use 命令

  增强功能:
  - 智能安装: 版本未安装时提示用户或自动安装
  - 项目配置支持: 读取 .fpdevrc 中的 auto_install 设置
  - 版本别名支持: stable, lts, trunk
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.config.interfaces, fpdev.cmd.fpc, fpdev.fpc.activation,
  fpdev.i18n, fpdev.i18n.strings, fpdev.paths, fpdev.exitcodes;

type
  { TFPCUseCommand }
  TFPCUseCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation
uses fpdev.command.registry, fpdev.cmd.utils, fpdev.config.project;

function TFPCUseCommand.Name: string; begin Result := 'use'; end;

function TFPCUseCommand.Aliases: TStringArray;
begin
  Result := nil;
  SetLength(Result, 1);
  Result[0] := 'default';
end;

function TFPCUseCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;


function FPCUseFactory: ICommand;
begin
  Result := TFPCUseCommand.Create;
end;

function GuessInstalled(const AVer: string; const Ctx: IContext): Boolean;
var
  LInfo: TToolchainInfo;
  LExe: string;
begin
  // First check if registered in config
  if Ctx.Config.GetToolchainManager.GetToolchain('fpc-' + AVer, LInfo) then Exit(True);

  // Use GetToolchainsDir() for consistent path with installer
  // Path: ~/.fpdev/toolchains/fpc/<version>/bin/fpc
  {$IFDEF MSWINDOWS}
  LExe := GetToolchainsDir + PathDelim + 'fpc' + PathDelim + AVer + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  LExe := GetToolchainsDir + PathDelim + 'fpc' + PathDelim + AVer + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
  Result := FileExists(LExe);
end;


function TFPCUseCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer: string;
  LMgr: TFPCManager;
  LResult: TActivationResult;
  LResolver: TProjectConfigResolver;
  LResolved: TResolvedConfig;
  LAutoInstall, LEnsure: Boolean;
  LGlobalFPC: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_USE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_USE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_USE_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_FPC_USE_OPT_ENSURE));
    Ctx.Out.WriteLn(_(HELP_FPC_USE_OPT_HELP));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Version aliases:');
    Ctx.Out.WriteLn('  stable    Latest stable version');
    Ctx.Out.WriteLn('  lts       Long-term support version');
    Ctx.Out.WriteLn('  trunk     Development version (main branch)');
    Exit(EXIT_OK);
  end;

  // 获取全局默认值
  LGlobalFPC := '';
  if Ctx.Config <> nil then
  begin
    LGlobalFPC := Ctx.Config.GetToolchainManager.GetDefaultToolchain;
    if Pos('fpc-', LGlobalFPC) = 1 then
      LGlobalFPC := Copy(LGlobalFPC, 5, Length(LGlobalFPC));
  end;

  // 创建配置解析器
  LResolver := TProjectConfigResolver.Create(LGlobalFPC, '');
  try
    // 无参数时: 使用项目配置或全局默认
    if Length(AParams) < 1 then
    begin
      LResolved := LResolver.ResolveConfig(GetCurrentDir);
      LVer := LResolved.FPCVersion;

      if LVer = '' then
      begin
        Ctx.Err.WriteLn('Error: No version specified and no default configured.');
        Ctx.Err.WriteLn('');
        Ctx.Err.WriteLn('Usage: fpdev fpc use <version>');
        Ctx.Err.WriteLn('');
        Ctx.Err.WriteLn('Or set a default: fpdev default fpc <version>');
        Ctx.Err.WriteLn('Or create a .fpdevrc file in your project.');
        Exit(EXIT_USAGE_ERROR);
      end;

      Ctx.Out.WriteLn('Using version from ' + ConfigSourceToString(LResolved.FPCSource) + ': ' + LVer);
      LAutoInstall := LResolved.AutoInstall;
    end
    else
    begin
      LVer := AParams[0];
      // 解析版本别名
      LVer := LResolver.ResolveVersionAlias(LVer);

      // 检查项目配置中的 auto_install 设置
      LResolved := LResolver.ResolveConfig(GetCurrentDir);
      LAutoInstall := LResolved.AutoInstall;
    end;
  finally
    LResolver.Free;
  end;

  LEnsure := HasFlag(AParams, 'ensure');

  // 检查版本是否已安装
  if not GuessInstalled(LVer, Ctx) then
  begin
    // 如果有 --ensure 标志或项目配置了 auto_install，则自动安装
    if LEnsure or LAutoInstall then
    begin
      LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
      try
        Ctx.Out.WriteLn('');
        Ctx.Out.WriteLn('FPC ' + LVer + ' is not installed. Installing...');
        Ctx.Out.WriteLn('');
        if not LMgr.InstallVersion(LVer, True {from source}, '' {prefix}, True {ensure}) then
        begin
          Ctx.Err.WriteLn('Error: Failed to install FPC ' + LVer);
          Exit(EXIT_ERROR);
        end;
      finally
        LMgr.Free;
      end;
    end
    else
    begin
      // 提示用户安装
      Ctx.Err.WriteLn('');
      Ctx.Err.WriteLn('Error: FPC ' + LVer + ' is not installed.');
      Ctx.Err.WriteLn('');
      Ctx.Err.WriteLn('To install it, run:');
      Ctx.Err.WriteLn('  fpdev fpc install ' + LVer);
      Ctx.Err.WriteLn('');
      Ctx.Err.WriteLn('Or use --ensure to auto-install:');
      Ctx.Err.WriteLn('  fpdev fpc use ' + LVer + ' --ensure');
      Ctx.Err.WriteLn('');
      Ctx.Err.WriteLn('Or enable auto_install in your .fpdevrc:');
      Ctx.Err.WriteLn('  [settings]');
      Ctx.Err.WriteLn('  auto_install = true');
      Exit(EXIT_ERROR);
    end;
  end;

  LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
  try
    // Use ActivateVersion to generate activation scripts
    LResult := LMgr.ActivateVersion(LVer);
    if LResult.Success then
    begin
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn(_Fmt(CMD_FPC_USE_ACTIVATED, [LVer]));
      Ctx.Out.WriteLn('');
      if LResult.ActivationScript <> '' then
      begin
        Ctx.Out.WriteLn(_Fmt(CMD_FPC_USE_SCRIPT_CREATED, [LResult.ActivationScript]));
        Ctx.Out.WriteLn('');
        Ctx.Out.WriteLn(_(CMD_FPC_USE_SCRIPT_RUN));
        Ctx.Out.WriteLn('  ' + LResult.ShellCommand);
      end;
      if LResult.VSCodeSettings <> '' then
        Ctx.Out.WriteLn(_Fmt(CMD_FPC_USE_VSCODE_UPDATED, [LResult.VSCodeSettings]));
      Exit(EXIT_OK);
    end
    else
    begin
      Ctx.Err.WriteLn(_(MSG_ERROR) + ': ' + LResult.ErrorMessage);
      Result := EXIT_ERROR;
    end;
  finally
    LMgr.Free;
  end;
end;


initialization
  GlobalCommandRegistry.RegisterPath(['fpc','use'], @FPCUseFactory, ['default']);

end.

