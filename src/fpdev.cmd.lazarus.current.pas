unit fpdev.cmd.lazarus.current;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.lazarus,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TLazCurrentCommand }
  TLazCurrentCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils, fpjson;

function TLazCurrentCommand.Name: string; begin Result := 'current'; end;
function TLazCurrentCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazCurrentCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazCurrentCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer: string;
  LMgr: TLazarusManager;
  LJsonOutput: Boolean;
  LJson: TJSONObject;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CURRENT_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CURRENT_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('  --json           Output in JSON format');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CURRENT_OPT_HELP));
    Exit(EXIT_OK);
  end;

  LJsonOutput := HasFlag(AParams, 'json');

  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    LVer := LMgr.GetCurrentVersion;

    if LJsonOutput then
    begin
      // JSON output mode
      LJson := TJSONObject.Create;
      try
        if LVer <> '' then
        begin
          LJson.Add('version', LVer);
          LJson.Add('has_default', True);
        end
        else
        begin
          LJson.Add('version', TJSONNull.Create);
          LJson.Add('has_default', False);
        end;
        Ctx.Out.WriteLn(LJson.FormatJSON);
      finally
        LJson.Free;
      end;
    end
    else
    begin
      // Normal text output
      if LVer <> '' then
        Ctx.Out.WriteLn(_Fmt(CMD_LAZARUS_CURRENT_VERSION, [LVer]))
      else
        Ctx.Out.WriteLn(_(CMD_LAZARUS_CURRENT_NONE));
    end;
  finally
    LMgr.Free;
  end;
end;

function LazCurrentFactory: ICommand;
begin
  Result := TLazCurrentCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','current'], @LazCurrentFactory, []);

end.

