unit fpdev.cmd.package.publish;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.package,
  fpdev.i18n, fpdev.i18n.strings;

type
  TPackagePublishCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TPackagePublishCommand.Name: string; begin Result := 'publish'; end;
function TPackagePublishCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackagePublishCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackagePublishFactory: ICommand;
begin
  Result := TPackagePublishCommand.Create;
end;

function TPackagePublishCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  Pkg: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_PUBLISH_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_PUBLISH_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_PUBLISH_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_PUBLISH_USAGE));
    Exit(2);
  end;
  Pkg := AParams[0];

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LMgr.PublishPackage(Pkg, Ctx.Out, Ctx.Err) then
      Exit(0);
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','publish'], @PackagePublishFactory, []);

end.
