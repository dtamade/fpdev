unit fpdev.cmd.cross.update;

{$mode objfpc}{$H+}

{ B237: CLI command for updating cross-compilation target binutils and libraries }

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.cross,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TCrossUpdateCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TCrossUpdateCommand.Name: string; begin Result := 'update'; end;
function TCrossUpdateCommand.Aliases: TStringArray; begin Result := nil; end;
function TCrossUpdateCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function CrossUpdateFactory: ICommand;
begin
  Result := TCrossUpdateCommand.Create;
end;

function TCrossUpdateCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LTarget: string;
  LMgr: TCrossCompilerManager;
begin
  Result := 0;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_UPDATE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_UPDATE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_UPDATE_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
    Exit(MissingArgError(Ctx, 'target', _(HELP_CROSS_UPDATE_USAGE)));

  LTarget := AParams[0];
  LMgr := TCrossCompilerManager.Create(Ctx.Config);
  try
    if LMgr.UpdateTarget(LTarget, Ctx.Out, Ctx.Err) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross','update'], @CrossUpdateFactory, []);

end.
