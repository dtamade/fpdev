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
  fpdev.command.intf, fpdev.config.interfaces, fpdev.fpc.manager,
  fpdev.i18n.strings;

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
uses
  fpdev.command.registry,
  fpdev.fpc.usecommandflow;

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
  LPlan: TFPCUseCommandPlan;
  LMgr: TFPCManager;
  LGlobalFPC: string;
  LShouldExit: Boolean;
  LInstalled: Boolean;
begin
  Result := 0;

  // Get global default value
  LGlobalFPC := '';
  if Ctx.Config <> nil then
  begin
    LGlobalFPC := Ctx.Config.GetToolchainManager.GetDefaultToolchain;
    if Pos('fpc-', LGlobalFPC) = 1 then
      LGlobalFPC := Copy(LGlobalFPC, 5, Length(LGlobalFPC));
  end;

  Result := PrepareFPCUseCommandPlanCore(
    AParams,
    LGlobalFPC,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  LInstalled := GuessInstalled(LPlan.Version, Ctx);

  LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
  try
    Result := ExecuteFPCUseCommandPlanCore(
      LPlan,
      Ctx,
      LInstalled,
      @LMgr.InstallVersion,
      @LMgr.ActivateVersion
    );
  finally
    LMgr.Free;
  end;
end;


initialization
  GlobalCommandRegistry.RegisterPath(['fpc','use'], @FPCUseFactory, []);

end.
