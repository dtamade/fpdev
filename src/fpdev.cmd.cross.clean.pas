unit fpdev.cmd.cross.clean;

{$mode objfpc}{$H+}

{ B236: CLI command for cleaning cross-compilation target build artifacts }

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.cross,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TCrossCleanCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TCrossCleanCommand.Name: string; begin Result := 'clean'; end;
function TCrossCleanCommand.Aliases: TStringArray; begin Result := nil; end;
function TCrossCleanCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function CrossCleanFactory: ICommand;
begin
  Result := TCrossCleanCommand.Create;
end;

function TCrossCleanCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LTarget: string;
  LMgr: TCrossCompilerManager;
begin
  Result := 0;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_CLEAN_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_CLEAN_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_CLEAN_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
    Exit(MissingArgError(Ctx, 'target', _(HELP_CROSS_CLEAN_USAGE)));

  LTarget := AParams[0];
  LMgr := TCrossCompilerManager.Create(Ctx.Config);
  try
    if LMgr.CleanTarget(LTarget, Ctx.Out, Ctx.Err) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross','clean'], @CrossCleanFactory, []);

end.
