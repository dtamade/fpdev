unit fpdev.cmd.default;

{
  fpdev default 命令

  设置全局默认工具链版本，类似 rustup default 和 nvm alias default

  用法:
    fpdev default                    # 显示当前默认版本
    fpdev default fpc 3.2.2          # 设置 FPC 默认版本
    fpdev default lazarus 3.8        # 设置 Lazarus 默认版本
    fpdev default --unset fpc        # 清除 FPC 默认版本
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf,
  fpdev.command.registry;

type
  { TDefaultCommand - 设置全局默认版本 }
  TDefaultCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function DefaultCommandFactory: ICommand;

implementation

uses
  fpdev.i18n,
  fpdev.config.interfaces,
  fpdev.config.project,
  fpdev.constants;

const
  HELP_DEFAULT = 'Usage: fpdev default [<tool> <version>]' + LineEnding +
                 '' + LineEnding +
                 'Set or show global default toolchain versions.' + LineEnding +
                 '' + LineEnding +
                 'Examples:' + LineEnding +
                 '  fpdev default                    Show current defaults' + LineEnding +
                 '  fpdev default fpc 3.2.2          Set FPC default to 3.2.2' + LineEnding +
                 '  fpdev default lazarus 3.8        Set Lazarus default to 3.8' + LineEnding +
                 '  fpdev default fpc stable         Set FPC default to stable channel' + LineEnding +
                 '  fpdev default --unset fpc        Clear FPC default' + LineEnding +
                 '' + LineEnding +
                 'Options:' + LineEnding +
                 '  --unset <tool>    Clear the default for the specified tool' + LineEnding +
                 '  -h, --help        Show this help message' + LineEnding +
                 '' + LineEnding +
                 'Version aliases:' + LineEnding +
                 '  stable    Latest stable version (currently ' + DEFAULT_FPC_VERSION + ')' + LineEnding +
                 '  lts       Long-term support version (currently ' + FALLBACK_FPC_VERSION + ')' + LineEnding +
                 '  trunk     Development version (main branch)';

function DefaultCommandFactory: ICommand;
begin
  Result := TDefaultCommand.Create;
end;

{ TDefaultCommand }

function TDefaultCommand.Name: string;
begin
  Result := 'default';
end;

function TDefaultCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TDefaultCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function TDefaultCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LTool, LVersion: string;
  LToolchainMgr: IToolchainManager;
  LLazarusMgr: ILazarusManager;
  LResolver: TProjectConfigResolver;
  LCurrentFPC, LCurrentLazarus: string;
  LUnset: Boolean;
  I: Integer;
begin
  Result := 0;

  // 检查帮助标志
  for I := 0 to High(AParams) do
  begin
    if (AParams[I] = '-h') or (AParams[I] = '--help') then
    begin
      Ctx.Out.WriteLn(HELP_DEFAULT);
      Exit(0);
    end;
  end;

  // 检查 --unset 标志
  LUnset := False;
  for I := 0 to High(AParams) do
  begin
    if AParams[I] = '--unset' then
    begin
      LUnset := True;
      Break;
    end;
  end;

  // 获取管理器
  LToolchainMgr := Ctx.Config.GetToolchainManager;
  LLazarusMgr := Ctx.Config.GetLazarusManager;

  // 无参数: 显示当前默认值
  if Length(AParams) = 0 then
  begin
    LCurrentFPC := LToolchainMgr.GetDefaultToolchain;
    LCurrentLazarus := LLazarusMgr.GetDefaultLazarusVersion;

    Ctx.Out.WriteLn('Global defaults:');
    Ctx.Out.WriteLn('');

    if LCurrentFPC <> '' then
      Ctx.Out.WriteLn('  FPC:     ' + LCurrentFPC)
    else
      Ctx.Out.WriteLn('  FPC:     (not set)');

    if LCurrentLazarus <> '' then
      Ctx.Out.WriteLn('  Lazarus: ' + LCurrentLazarus)
    else
      Ctx.Out.WriteLn('  Lazarus: (not set)');

    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Use "fpdev default <tool> <version>" to set a default.');
    Exit(0);
  end;

  // --unset 模式
  if LUnset then
  begin
    // 找到 --unset 后面的工具名
    LTool := '';
    for I := 0 to High(AParams) do
    begin
      if (AParams[I] <> '--unset') and (AParams[I][1] <> '-') then
      begin
        LTool := LowerCase(AParams[I]);
        Break;
      end;
    end;

    if LTool = '' then
    begin
      Ctx.Err.WriteLn('Error: --unset requires a tool name (fpc or lazarus)');
      Exit(1);
    end;

    case LTool of
      'fpc':
        begin
          LToolchainMgr.SetDefaultToolchain('');
          Ctx.Config.SaveConfig;
          Ctx.Out.WriteLn('Cleared FPC default.');
        end;
      'lazarus':
        begin
          LLazarusMgr.SetDefaultLazarusVersion('');
          Ctx.Config.SaveConfig;
          Ctx.Out.WriteLn('Cleared Lazarus default.');
        end;
    else
      Ctx.Err.WriteLn('Error: Unknown tool "' + LTool + '". Use "fpc" or "lazarus".');
      Exit(1);
    end;

    Exit(0);
  end;

  // 设置默认值: fpdev default <tool> <version>
  if Length(AParams) < 2 then
  begin
    Ctx.Err.WriteLn('Error: Missing version. Usage: fpdev default <tool> <version>');
    Exit(1);
  end;

  LTool := LowerCase(AParams[0]);
  LVersion := AParams[1];

  // 解析版本别名
  LResolver := TProjectConfigResolver.Create;
  try
    LVersion := LResolver.ResolveVersionAlias(LVersion);
  finally
    LResolver.Free;
  end;

  case LTool of
    'fpc':
      begin
        // 设置默认工具链名称 (格式: fpc-<version>)
        LToolchainMgr.SetDefaultToolchain('fpc-' + LVersion);
        if Ctx.Config.SaveConfig then
        begin
          Ctx.Out.WriteLn('');
          Ctx.Out.WriteLn('Default FPC version set to: ' + LVersion);
          Ctx.Out.WriteLn('');
          Ctx.Out.WriteLn('This will be used when no project config (.fpdevrc) is present.');
        end
        else
        begin
          Ctx.Err.WriteLn('Error: Failed to save configuration.');
          Exit(1);
        end;
      end;
    'lazarus':
      begin
        LLazarusMgr.SetDefaultLazarusVersion('lazarus-' + LVersion);
        if Ctx.Config.SaveConfig then
        begin
          Ctx.Out.WriteLn('');
          Ctx.Out.WriteLn('Default Lazarus version set to: ' + LVersion);
          Ctx.Out.WriteLn('');
          Ctx.Out.WriteLn('This will be used when no project config (.fpdevrc) is present.');
        end
        else
        begin
          Ctx.Err.WriteLn('Error: Failed to save configuration.');
          Exit(1);
        end;
      end;
  else
    Ctx.Err.WriteLn('Error: Unknown tool "' + LTool + '". Use "fpc" or "lazarus".');
    Exit(1);
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['default'], @DefaultCommandFactory, []);

end.
