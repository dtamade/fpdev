unit fpdev.cmd.cross.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.cross,
  fpdev.cmd.utils, fpdev.i18n, fpdev.i18n.strings;

type
  TCrossListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TCrossListCommand.Name: string; begin Result := 'list'; end;
function TCrossListCommand.Aliases: TStringArray; begin Result := nil; end;
function TCrossListCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function CrossListFactory: ICommand;
begin
  Result := TCrossListCommand.Create;
end;

function TCrossListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LShowAll: Boolean;
  LMgr: TCrossCompilerManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_OPT_ALL));
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_OPT_HELP));
    Exit(0);
  end;

  LShowAll := HasFlag(AParams, 'all') or HasFlag(AParams, 'remote');
  LMgr := TCrossCompilerManager.Create(Ctx.Config);
  try
    if LMgr.ListTargets(LShowAll, Ctx.Out) then
      Exit(0);
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross','list'], @CrossListFactory, []);

end.
