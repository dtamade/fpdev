unit fpdev.cmd.package.info;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager,
  fpdev.package.types,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TPackageInfoCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TPackageInfoCommand.Name: string; begin Result := 'info'; end;
function TPackageInfoCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageInfoCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageInfoFactory: ICommand;
begin
  Result := TPackageInfoCommand.Create;
end;

function TPackageInfoCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  Pkg: string;
  InstalledPkgs: TPackageArray;
  IsInstalled: Boolean;
  UnknownOption: string;
  i: Integer;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INFO_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INFO_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INFO_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    Ctx.Err.WriteLn(_(HELP_PACKAGE_INFO_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_INFO_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  Pkg := AParams[0];
  if Trim(Pkg) = '' then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_INFO_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  for i := 1 to High(AParams) do
    if (AParams[i] <> '') and (AParams[i][1] <> '-') then
    begin
      Ctx.Err.WriteLn(_(HELP_PACKAGE_INFO_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    InstalledPkgs := LMgr.GetInstalledPackageList;
    IsInstalled := False;
    for i := 0 to High(InstalledPkgs) do
      if SameText(InstalledPkgs[i].Name, Pkg) then
      begin
        IsInstalled := True;
        Break;
      end;
    if not IsInstalled then
    begin
      Ctx.Err.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_FOUND, [Pkg]));
      Exit(EXIT_NOT_FOUND);
    end;

    if LMgr.ShowPackageInfo(Pkg, Ctx.Out) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','info'], @PackageInfoFactory, []);

end.
