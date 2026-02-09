unit fpdev.cmd.fpc.current;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.fpc,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TFPCCurrentCommand }
  TFPCCurrentCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils, fpjson;

function TFPCCurrentCommand.Name: string; begin Result := 'current'; end;

function TFPCCurrentCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCCurrentCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function TFPCCurrentCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer: string;
  LMgr: TFPCManager;
  LJsonOutput: Boolean;
  LJson: TJSONObject;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_CURRENT_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_CURRENT_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('  --json           Output in JSON format');
    Ctx.Out.WriteLn(_(HELP_FPC_CURRENT_OPT_HELP));
    Exit(EXIT_OK);
  end;

  LJsonOutput := HasFlag(AParams, 'json');

  LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
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
        Ctx.Out.WriteLn(_Fmt(CMD_FPC_CURRENT_VERSION, [LVer]))
      else
        Ctx.Out.WriteLn(_(CMD_FPC_CURRENT_NONE));
    end;
  finally
    LMgr.Free;
  end;
end;

function FPCCurrentFactory: ICommand;
begin
  Result := TFPCCurrentCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','current'], @FPCCurrentFactory, []);

end.

