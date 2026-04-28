unit fpdev.cmd.package.install_local;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager;

type
  TPackageInstallLocalCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.package.lifecyclecommandflow;

function TPackageInstallLocalCommand.Name: string; begin Result := 'install-local'; end;
function TPackageInstallLocalCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageInstallLocalCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function PackageInstallLocalFactory: ICommand;
begin
  Result := TPackageInstallLocalCommand.Create;
end;

function TPackageInstallLocalCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  LPlan: TPackageInstallLocalCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageInstallLocalCommandPlanCore(
    AParams,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    Result := ExecutePackageInstallLocalCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.InstallFromLocal
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','install-local'], @PackageInstallLocalFactory, []);

end.
