unit fpdev.cmd.lazarus.install;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config.interfaces, fpdev.lazarus.manager,
  fpdev.i18n.strings;

type
  { TLazInstallCommand }
  TLazInstallCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.lazarus.installcommandflow;

function TLazInstallCommand.Name: string; begin Result := 'install'; end;
function TLazInstallCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazInstallCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazInstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LSettings: TFPDevSettings;
  LPlan: TLazarusInstallCommandPlan;
  LShouldExit: Boolean;
  LSettingsModified: Boolean;
  LMgr: TLazarusManager;
begin
  LSettings := Ctx.Config.GetSettingsManager.GetSettings;
  Result := PrepareLazarusInstallCommandPlanCore(
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

  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    Result := ExecuteLazarusInstallCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.InstallVersion
    );
  finally
    LMgr.Free;
  end;
end;

function LazInstallFactory: ICommand;
begin
  Result := TLazInstallCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','install'], @LazInstallFactory, []);

end.
