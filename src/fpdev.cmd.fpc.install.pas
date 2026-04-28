unit fpdev.cmd.fpc.install;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.config.interfaces, fpdev.fpc.manager,
  fpdev.fpc.installcommandflow, fpdev.utils;

type
  { TFPCInstallCommand }
  TFPCInstallCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.registry;

function TFPCInstallCommand.Name: string; begin Result := 'install'; end;

function TFPCInstallCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCInstallCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function FPCInstallFactory: ICommand;
begin
  Result := TFPCInstallCommand.Create;
end;



function TFPCInstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LPlan: TFPCInstallCommandPlan;
  LSettings: TFPDevSettings;
  LMgr: TFPCManager;
  LShouldExit: Boolean;
  LSettingsModified: Boolean;
begin
  LSettings := Ctx.Config.GetSettingsManager.GetSettings;
  Result := PrepareFPCInstallCommandPlanCore(
    AParams,
    LSettings,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit,
    LSettingsModified
  );

  if LSettingsModified then
    Ctx.Config.GetSettingsManager.SetSettings(LSettings);

  if LShouldExit then
    Exit(Result);

  LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
  try
    Result := ExecuteFPCInstallCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      get_env('FPDEV_SKIP_NETWORK_TESTS') = '1',
      @LMgr.InstallVersion
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','install'], @FPCInstallFactory, []);

end.

