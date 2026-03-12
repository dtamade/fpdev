unit fpdev.cmd.cross.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cross.manager,
  fpdev.command.utils, fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TCrossListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpjson;

function TCrossListCommand.Name: string; begin Result := 'list'; end;
function TCrossListCommand.Aliases: TStringArray; begin Result := nil; end;
function TCrossListCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function CrossListFactory: ICommand;
begin
  Result := TCrossListCommand.Create;
end;

function CrossTargetToJson(const AInfo: TCrossTargetInfo): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('name', AInfo.Name);
  Result.Add('display_name', AInfo.DisplayName);
  Result.Add('cpu', AInfo.CPU);
  Result.Add('os', AInfo.OS);
  Result.Add('binutils_prefix', AInfo.BinutilsPrefix);
  Result.Add('available', AInfo.Available);
  Result.Add('installed', AInfo.Installed);
end;

function TCrossListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LShowAll, LJsonOutput: Boolean;
  LMgr: TCrossCompilerManager;
  LTargets: TCrossTargetArray;
  LJson: TJSONObject;
  LArr: TJSONArray;
  I: Integer;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn(_(HELP_CROSS_LIST_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_OPT_ALL));
    Ctx.Out.WriteLn('  --json           Output in JSON format');
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_OPT_HELP));
    Exit(EXIT_OK);
  end;

  for I := Low(AParams) to High(AParams) do
  begin
    if SameText(AParams[I], '--all') or SameText(AParams[I], '-all') or
       SameText(AParams[I], '--remote') or SameText(AParams[I], '-remote') or
       SameText(AParams[I], '--json') or SameText(AParams[I], '-json') then
      Continue;
    Ctx.Err.WriteLn(_(HELP_CROSS_LIST_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  LShowAll := HasFlag(AParams, 'all') or HasFlag(AParams, 'remote');
  LJsonOutput := HasFlag(AParams, 'json');

  LMgr := TCrossCompilerManager.Create(Ctx.Config);
  try
    if LJsonOutput then
    begin
      // JSON output mode
      if LShowAll then
        LTargets := LMgr.GetAvailableTargets
      else
        LTargets := LMgr.GetInstalledTargets;

      LJson := TJSONObject.Create;
      try
        LArr := TJSONArray.Create;
        for I := 0 to High(LTargets) do
          LArr.Add(CrossTargetToJson(LTargets[I]));
        LJson.Add('targets', LArr);
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
      if LMgr.ListTargets(LShowAll, Ctx.Out) then
        Exit(EXIT_OK);
      Result := EXIT_ERROR;
    end;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross','list'], @CrossListFactory, []);

end.
