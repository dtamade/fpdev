unit fpdev.cmd.cross.disable;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.cross,
  fpdev.i18n, fpdev.i18n.strings;

type
  TCrossDisableCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

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
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_DISABLE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_DISABLE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_DISABLE_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['target']));
    Ctx.Err.WriteLn(_(HELP_CROSS_DISABLE_USAGE));
    Exit(2);
  end;

  LTarget := AParams[0];
  LMgr := TCrossCompilerManager.Create(Ctx.Config);
  try
    if LMgr.DisableTarget(LTarget, Ctx.Out, Ctx.Err) then
      Exit(0);
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross','disable'], @CrossDisableFactory, []);

end.
