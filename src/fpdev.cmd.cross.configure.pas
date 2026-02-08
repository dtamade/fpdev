unit fpdev.cmd.cross.configure;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.cross,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TCrossConfigureCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TCrossConfigureCommand.Name: string; begin Result := 'configure'; end;
function TCrossConfigureCommand.Aliases: TStringArray; begin Result := nil; end;
function TCrossConfigureCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function CrossConfigureFactory: ICommand;
begin
  Result := TCrossConfigureCommand.Create;
end;

function TCrossConfigureCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LTarget: string;
  LBinutils, LLibraries: string;
  LMgr: TCrossCompilerManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_OPT_BINUTILS));
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_OPT_LIBRARIES));
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['target']));
    Ctx.Err.WriteLn(_(HELP_CROSS_CONFIGURE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  LTarget := AParams[0];
  LBinutils := '';
  LLibraries := '';
  GetFlagValue(AParams, 'binutils', LBinutils);
  GetFlagValue(AParams, 'libraries', LLibraries);

  if (LBinutils = '') or (LLibraries = '') then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['--binutils, --libraries']));
    Ctx.Err.WriteLn(_(HELP_CROSS_CONFIGURE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  LMgr := TCrossCompilerManager.Create(Ctx.Config);
  try
    if LMgr.ConfigureTarget(LTarget, LBinutils, LLibraries, Ctx.Out, Ctx.Err) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross','configure'], @CrossConfigureFactory, []);

end.
