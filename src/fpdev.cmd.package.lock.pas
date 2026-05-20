unit fpdev.cmd.package.lock;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager;

type
  TPackageLockCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.command.utils,
  fpdev.package.types,
  fpdev.package.lockfile,
  fpdev.i18n, fpdev.i18n.strings;

function TPackageLockCommand.Name: string; begin Result := 'lock'; end;
function TPackageLockCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageLockCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageLockFactory: ICommand;
begin
  Result := TPackageLockCommand.Create;
end;

function TPackageLockCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  Installed: TPackageArray;
  LockFile: TPackageLockFile;
  I: Integer;
  DepMap: TStringList;
  J: Integer;
begin
  Result := 0;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Ctx.Out <> nil then
    begin
      Ctx.Out.WriteLn('Usage: fpdev package lock');
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Generate fpdev-lock.json from installed packages.');
    end;
    Exit(0);
  end;

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    Installed := LMgr.GetInstalledPackageList;

    if Length(Installed) = 0 then
    begin
      if Ctx.Out <> nil then
        Ctx.Out.WriteLn(_(MSG_PKG_NOT_INSTALLED_ANY));
      Exit(0);
    end;

    LockFile := TPackageLockFile.Create(
      IncludeTrailingPathDelimiter(GetCurrentDir) + LOCKFILE_NAME);
    try
      LockFile.SetProjectInfo(
        ExtractFileName(ExcludeTrailingPathDelimiter(GetCurrentDir)), '1.0.0');

      for I := 0 to High(Installed) do
      begin
        DepMap := TStringList.Create;
        try
          for J := 0 to High(Installed[I].Dependencies) do
            DepMap.Values[Installed[I].Dependencies[J]] := '>=0.0.0';

          LockFile.AddPackage(
            Installed[I].Name,
            Installed[I].Version,
            Installed[I].InstallPath,
            Installed[I].Sha256,
            DepMap
          );
        finally
          DepMap.Free;
        end;
      end;

      if LockFile.Save then
      begin
        if Ctx.Out <> nil then
          Ctx.Out.WriteLn(_Fmt(MSG_PKG_LOCK_GENERATED, [LOCKFILE_NAME]));
      end
      else
      begin
        if Ctx.Err <> nil then
          Ctx.Err.WriteLn(_(MSG_ERROR) + ': failed to write ' + LOCKFILE_NAME);
        Result := 1;
      end;
    finally
      LockFile.Free;
    end;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','lock'], @PackageLockFactory, []);

end.
