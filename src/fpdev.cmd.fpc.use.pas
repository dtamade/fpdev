unit fpdev.cmd.fpc.use;

{
  fpdev fpc use command

  Enhanced features:
  - Smart installation: Prompt user or auto-install when version is not installed
  - Project config support: Read auto_install setting from .fpdevrc
  - Version alias support: stable, lts, trunk
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.config.interfaces, fpdev.fpc.manager, fpdev.fpc.activation,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

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
uses fpdev.command.registry, fpdev.command.utils, fpdev.config.project;

function TFPCUseCommand.Name: string; begin Result := 'use'; end;

function TFPCUseCommand.Aliases: TStringArray;
begin
  Result := nil;
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
  LMgr: TFPCManager;
  InstallPath: string;
  LExe: string;
begin
  // First check if registered in config
  if Ctx.Config.GetToolchainManager.GetToolchain('fpc-' + AVer, LInfo) then Exit(True);

  // Fallback: check resolved install path (respects project scope + install_root)
  LMgr := TFPCManager.Create(Ctx.Config);
  try
    InstallPath := LMgr.GetVersionInstallPath(AVer);
    {$IFDEF MSWINDOWS}
    LExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
    {$ELSE}
    LExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
    {$ENDIF}
    Result := FileExists(LExe);
  finally
    LMgr.Free;
  end;
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

  // Get global default value
  LGlobalFPC := '';
  if Ctx.Config <> nil then
  begin
    LGlobalFPC := Ctx.Config.GetToolchainManager.GetDefaultToolchain;
    if Pos('fpc-', LGlobalFPC) = 1 then
      LGlobalFPC := Copy(LGlobalFPC, 5, Length(LGlobalFPC));
  end;

  // Create config resolver
  LResolver := TProjectConfigResolver.Create(LGlobalFPC, '');
  try
    // No arguments: use project config or global default
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
        Ctx.Err.WriteLn('Or set a global fallback with: fpdev fpc use <version>');
        Ctx.Err.WriteLn('Or create a .fpdevrc file in your project.');
        Exit(EXIT_USAGE_ERROR);
      end;

      Ctx.Out.WriteLn('Using version from ' + ConfigSourceToString(LResolved.FPCSource) + ': ' + LVer);
      LAutoInstall := LResolved.AutoInstall;
    end
    else
    begin
      LVer := AParams[0];
      // Resolve version alias
      LVer := LResolver.ResolveVersionAlias(LVer);

      // Check auto_install setting in project config
      LResolved := LResolver.ResolveConfig(GetCurrentDir);
      LAutoInstall := LResolved.AutoInstall;
    end;
  finally
    LResolver.Free;
  end;

  LEnsure := HasFlag(AParams, 'ensure');

  // Check if version is installed
  if not GuessInstalled(LVer, Ctx) then
  begin
    // If --ensure flag or project auto_install is set, install automatically
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
      // Prompt user to install
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
  GlobalCommandRegistry.RegisterPath(['fpc','use'], @FPCUseFactory, []);

end.

