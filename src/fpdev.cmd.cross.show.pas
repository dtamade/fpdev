unit fpdev.cmd.cross.show;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.cross,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TCrossShowCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TCrossShowCommand.Name: string; begin Result := 'show'; end;
function TCrossShowCommand.Aliases: TStringArray; begin Result := nil; end;
function TCrossShowCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function CrossShowFactory: ICommand;
begin
  Result := TCrossShowCommand.Create;
end;

function TCrossShowCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LTarget: string;
  LMgr: TCrossCompilerManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_SHOW_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_SHOW_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_SHOW_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
    Exit(MissingArgError(Ctx, 'target', _(HELP_CROSS_SHOW_USAGE)));

  LTarget := AParams[0];
  LMgr := TCrossCompilerManager.Create(Ctx.Config);
  try
    if LMgr.ShowTargetInfo(LTarget, Ctx.Out, Ctx.Err) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross','show'], @CrossShowFactory, []);

end.
