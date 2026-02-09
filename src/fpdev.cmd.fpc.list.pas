unit fpdev.cmd.fpc.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.cmd.fpc,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TFPCListCommand }
  TFPCListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.registry, fpdev.cmd.utils, fpjson, fpdev.output.json, fpdev.fpc.version;

function TFPCListCommand.Name: string; begin Result := 'list'; end;

function TFPCListCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCListCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function FPCListFactory: ICommand;
begin
  Result := TFPCListCommand.Create;
end;


function TFPCListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LShowAll, LJsonOutput: Boolean;
  LMgr: TFPCManager;
  LVersions: TFPCVersionArray;
  LJson: TJSONObject;
  LArr: TJSONArray;
  LDefault: string;
  I: Integer;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_OPT_ALL));
    Ctx.Out.WriteLn('  --json           Output in JSON format');
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_OPT_HELP));
    Exit(EXIT_OK);
  end;

  LShowAll := HasFlag(AParams, 'all') or HasFlag(AParams, 'remote');
  LJsonOutput := HasFlag(AParams, 'json');

  LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
  try
    if LJsonOutput then
    begin
      // JSON output mode
      if LShowAll then
        LVersions := LMgr.GetAvailableVersions
      else
        LVersions := LMgr.GetInstalledVersions;

      LDefault := '';
      if Ctx.Config <> nil then
      begin
        LDefault := Ctx.Config.GetToolchainManager.GetDefaultToolchain;
        if Pos('fpc-', LDefault) = 1 then
          LDefault := Copy(LDefault, 5, Length(LDefault));
      end;

      LJson := TJSONObject.Create;
      try
        LArr := TJSONArray.Create;
        for I := 0 to High(LVersions) do
          LArr.Add(TJsonOutputHelper.VersionInfoToJson(LVersions[I]));
        LJson.Add('versions', LArr);
        LJson.Add('default', LDefault);
        LJson.Add('show_all', LShowAll);
        Ctx.Out.WriteLn(LJson.FormatJSON);
      finally
        LJson.Free;
      end;
      Exit(EXIT_OK);
    end
    else
    begin
      // Normal text output
      if LMgr.ListVersions(Ctx.Out, LShowAll) then
        Exit(EXIT_OK);
      Result := EXIT_ERROR;
    end;
  finally
    LMgr.Free;
  end;
end;


initialization
  GlobalCommandRegistry.RegisterPath(['fpc','list'], @FPCListFactory, []);

end.

