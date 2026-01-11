unit fpdev.cmd.fpc.use;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.config.interfaces, fpdev.cmd.fpc, fpdev.fpc.activation,
  fpdev.i18n, fpdev.i18n.strings;

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
uses fpdev.command.registry, fpdev.cmd.utils;

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
  LRoot, LExe: string;
begin
  if Ctx.Config.GetToolchainManager.GetToolchain('fpc-' + AVer, LInfo) then Exit(True);
  LRoot := Ctx.Config.GetSettingsManager.GetSettings.InstallRoot;
  if LRoot = '' then LRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'data';
  {$IFDEF MSWINDOWS}
  LExe := IncludeTrailingPathDelimiter(LRoot) + 'fpc' + PathDelim + AVer + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  LExe := IncludeTrailingPathDelimiter(LRoot) + 'fpc' + PathDelim + AVer + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
  Result := FileExists(LExe);
end;


function TFPCUseCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer: string;
  LMgr: TFPCManager;
  LResult: TActivationResult;
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
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    Ctx.Err.WriteLn(_(HELP_FPC_USE_USAGE));
    Exit(2);
  end;
  LVer := AParams[0];

  if HasFlag(AParams, 'ensure') and (not GuessInstalled(LVer, Ctx)) then
  begin
    LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
    try
      Ctx.Out.WriteLn(_Fmt(CMD_FPC_USE_AUTOINSTALL, [LVer]));
      if not LMgr.InstallVersion(LVer, True {from source}, '' {prefix}, True {ensure}) then
      begin
        Ctx.Err.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_USE_AUTOINSTALL_FAILED));
        Exit(3);
      end;
    finally
      LMgr.Free;
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
      Exit(0);
    end
    else
    begin
      Ctx.Err.WriteLn(_(MSG_ERROR) + ': ' + LResult.ErrorMessage);
      Result := 3;
    end;
  finally
    LMgr.Free;
  end;
end;


initialization
  GlobalCommandRegistry.RegisterPath(['fpc','use'], @FPCUseFactory, ['default']);

end.

