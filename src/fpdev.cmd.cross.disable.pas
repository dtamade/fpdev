unit fpdev.cmd.cross.disable;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cross.manager,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TCrossDisableCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TCrossDisableCommand.Name: string; begin Result := 'disable'; end;
function TCrossDisableCommand.Aliases: TStringArray; begin Result := nil; end;
function TCrossDisableCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function CrossDisableFactory: ICommand;
begin
  Result := TCrossDisableCommand.Create;
end;

function TCrossDisableCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LTarget: string;
  LMgr: TCrossCompilerManager;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn(_(HELP_CROSS_DISABLE_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn(_(HELP_CROSS_DISABLE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_DISABLE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_DISABLE_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
    Exit(MissingArgError(Ctx, 'target', _(HELP_CROSS_DISABLE_USAGE)));
  if Length(AParams) > 1 then
  begin
    Ctx.Err.WriteLn(_(HELP_CROSS_DISABLE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  if (Length(AParams[0]) > 0) and (AParams[0][1] = '-') then
  begin
    Ctx.Err.WriteLn(_(HELP_CROSS_DISABLE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  LTarget := AParams[0];
  LMgr := TCrossCompilerManager.Create(Ctx.Config);
  try
    if LMgr.DisableTarget(LTarget, Ctx.Out, Ctx.Err) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross','disable'], @CrossDisableFactory, []);

end.
