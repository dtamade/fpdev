unit fpdev.cmd.lazarus.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.lazarus,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TLazListCommand }
  TLazListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils, fpjson;

function TLazListCommand.Name: string; begin Result := 'list'; end;
function TLazListCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazListCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function LazarusVersionToJson(const AInfo: TLazarusVersionInfo): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('version', AInfo.Version);
  Result.Add('release_date', AInfo.ReleaseDate);
  Result.Add('git_tag', AInfo.GitTag);
  Result.Add('branch', AInfo.Branch);
  Result.Add('fpc_version', AInfo.FPCVersion);
  Result.Add('available', AInfo.Available);
  Result.Add('installed', AInfo.Installed);
end;

function TLazListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LAll, LJsonOutput: Boolean;
  LMgr: TLazarusManager;
  LVersions: TLazarusVersionArray;
  LJson: TJSONObject;
  LArr: TJSONArray;
  LDefault: string;
  I: Integer;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn(_(HELP_LAZARUS_LIST_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_OPT_ALL));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_OPT_JSON));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_OPT_HELP));
    Exit(EXIT_OK);
  end;

  for I := Low(AParams) to High(AParams) do
  begin
    if SameText(AParams[I], '--all') or SameText(AParams[I], '-all') or
       SameText(AParams[I], '--json') or SameText(AParams[I], '-json') then
      Continue;
    Ctx.Err.WriteLn(_(HELP_LAZARUS_LIST_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  LAll := HasFlag(AParams, 'all');
  LJsonOutput := HasFlag(AParams, 'json');

  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    if LJsonOutput then
    begin
      // JSON output mode
      if LAll then
        LVersions := LMgr.GetAvailableVersions
      else
        LVersions := LMgr.GetInstalledVersions;

      LDefault := '';
      if Ctx.Config <> nil then
      begin
        LDefault := Ctx.Config.GetLazarusManager.GetDefaultLazarusVersion;
        if Pos('lazarus-', LDefault) = 1 then
          LDefault := Copy(LDefault, 9, Length(LDefault));
      end;

      LJson := TJSONObject.Create;
      try
        LArr := TJSONArray.Create;
        for I := 0 to High(LVersions) do
          LArr.Add(LazarusVersionToJson(LVersions[I]));
        LJson.Add('versions', LArr);
        if LDefault <> '' then
        begin
          LJson.Add('default', LDefault);
          LJson.Add('has_default', True);
        end
        else
        begin
          LJson.Add('default', TJSONNull.Create);
          LJson.Add('has_default', False);
        end;
        LJson.Add('show_all', LAll);
        Ctx.Out.WriteLn(LJson.FormatJSON);
      finally
        LJson.Free;
      end;
      Exit(EXIT_OK);
    end
    else
    begin
      // Normal text output
      if LMgr.ListVersions(Ctx.Out, LAll) then
        Exit(EXIT_OK);
      Result := EXIT_ERROR;
    end;
  finally
    LMgr.Free;
  end;
end;

function LazListFactory: ICommand;
begin
  Result := TLazListCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','list'], @LazListFactory, []);

end.
