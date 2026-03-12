unit fpdev.cmd.package.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager,
  fpdev.package.types, fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TPackageListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils, fpjson;

function TPackageListCommand.Name: string; begin Result := 'list'; end;
function TPackageListCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageListCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageListFactory: ICommand;
begin
  Result := TPackageListCommand.Create;
end;

function PackageInfoToJson(const AInfo: TPackageInfo): TJSONObject;
var
  LDeps: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.Add('name', AInfo.Name);
  Result.Add('version', AInfo.Version);
  Result.Add('description', AInfo.Description);
  Result.Add('author', AInfo.Author);
  Result.Add('license', AInfo.License);
  Result.Add('homepage', AInfo.Homepage);
  LDeps := TJSONArray.Create;
  for I := 0 to High(AInfo.Dependencies) do
    LDeps.Add(AInfo.Dependencies[I]);
  Result.Add('dependencies', LDeps);
end;

function TPackageListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  ShowAll, LJsonOutput: Boolean;
  LPackages: TPackageArray;
  LJson: TJSONObject;
  LArr: TJSONArray;
  UnknownOption: string;
  I: Integer;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_OPT_ALL));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_OPT_JSON));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_OPT_HELP));
    Exit(EXIT_OK);
  end;

  ShowAll := HasFlag(AParams, 'all') or HasFlag(AParams, 'a');
  LJsonOutput := HasFlag(AParams, 'json');
  if FindUnknownOption(AParams, ['--all', '-a', '--json'], UnknownOption) then
  begin
    Ctx.Err.WriteLn(_(HELP_PACKAGE_LIST_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  for I := 0 to High(AParams) do
    if (AParams[I] <> '') and (AParams[I][1] <> '-') then
    begin
      Ctx.Err.WriteLn(_(HELP_PACKAGE_LIST_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LJsonOutput then
    begin
      // JSON output mode
      if ShowAll then
        LPackages := LMgr.GetAvailablePackageList
      else
        LPackages := LMgr.GetInstalledPackageList;

      LJson := TJSONObject.Create;
      try
        LArr := TJSONArray.Create;
        for I := 0 to High(LPackages) do
          LArr.Add(PackageInfoToJson(LPackages[I]));
        LJson.Add('packages', LArr);
        LJson.Add('show_all', ShowAll);
        Ctx.Out.WriteLn(LJson.FormatJSON);
      finally
        LJson.Free;
      end;
      Exit(EXIT_OK);
    end
    else
    begin
      // Normal text output
      if LMgr.ListPackages(ShowAll, Ctx.Out) then
        Exit(EXIT_OK);
      Result := EXIT_ERROR;
    end;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','list'], @PackageListFactory, []);

end.
