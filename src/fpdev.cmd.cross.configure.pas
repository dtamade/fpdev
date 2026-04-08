unit fpdev.cmd.cross.configure;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cross.manager,
  fpdev.cross.search,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TCrossToolchainSearchFactory = function: TCrossToolchainSearch;

  TCrossConfigureCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

var
  CrossToolchainSearchFactory: TCrossToolchainSearchFactory;

implementation

uses fpdev.command.utils,
  fpdev.config.interfaces,
  fpdev.cross.targets;

function TCrossConfigureCommand.Name: string; begin Result := 'configure'; end;
function TCrossConfigureCommand.Aliases: TStringArray; begin Result := nil; end;
function TCrossConfigureCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function CrossConfigureFactory: ICommand;
begin
  Result := TCrossConfigureCommand.Create;
end;

function ResolveSearchTarget(const ATarget: string; out ASearchTarget: TCrossTarget): Boolean;
var
  Registry: TCrossTargetRegistry;
  TargetDef: TCrossTargetDef;
begin
  ASearchTarget := Default(TCrossTarget);
  Registry := TCrossTargetRegistry.Create;
  try
    Registry.LoadBuiltinTargets;
    Result := Registry.GetTarget(ATarget, TargetDef);
    if Result then
    begin
      ASearchTarget.CPU := TargetDef.CPU;
      ASearchTarget.OS := TargetDef.OS;
      ASearchTarget.SubArch := TargetDef.SubArch;
      ASearchTarget.ABI := TargetDef.ABI;
      ASearchTarget.BinutilsPrefix := TargetDef.BinutilsPrefix;
    end;
  finally
    Registry.Free;
  end;
end;

function TCrossConfigureCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LTarget: string;
  LBinutils, LLibraries: string;
  LMgr: TCrossCompilerManager;
  LAutoDetect, HasBinutils, HasLibraries: Boolean;
  Search: TCrossToolchainSearch;
  SearchTarget: TCrossTarget;
  BinResult: TCrossSearchResult;
  LibPaths: TStringArray;
  I, LPositionalCount: Integer;
  LParam, LParamLower: string;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn(_(HELP_CROSS_CONFIGURE_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_OPT_BINUTILS));
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_OPT_LIBRARIES));
    Ctx.Out.WriteLn('  --auto                Auto-detect binutils and libraries paths');
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_OPT_HELP));
    Exit(EXIT_OK);
  end;

  LTarget := '';
  LPositionalCount := 0;
  for I := Low(AParams) to High(AParams) do
  begin
    LParam := AParams[I];
    if LParam = '' then
      Continue;

    if LParam[1] = '-' then
    begin
      LParamLower := LowerCase(LParam);
      if SameText(LParam, '--auto') or SameText(LParam, '-auto') then
        Continue;
      if Pos('--binutils=', LParamLower) = 1 then
        Continue;
      if Pos('--libraries=', LParamLower) = 1 then
        Continue;
      Ctx.Err.WriteLn(_(HELP_CROSS_CONFIGURE_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;

    Inc(LPositionalCount);
    if LPositionalCount = 1 then
      LTarget := LParam
    else
    begin
      Ctx.Err.WriteLn(_(HELP_CROSS_CONFIGURE_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
  end;

  if LPositionalCount < 1 then
    Exit(MissingArgError(Ctx, 'target', _(HELP_CROSS_CONFIGURE_USAGE)));

  if not ResolveSearchTarget(LTarget, SearchTarget) then
  begin
    Ctx.Err.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [LTarget]));
    Exit(EXIT_ERROR);
  end;

  LBinutils := '';
  LLibraries := '';
  HasBinutils := GetFlagValue(AParams, 'binutils', LBinutils);
  if HasBinutils and (LBinutils = '') then
    Exit(MissingArgError(Ctx, '--binutils', _(HELP_CROSS_CONFIGURE_USAGE)));
  HasLibraries := GetFlagValue(AParams, 'libraries', LLibraries);
  if HasLibraries and (LLibraries = '') then
    Exit(MissingArgError(Ctx, '--libraries', _(HELP_CROSS_CONFIGURE_USAGE)));
  LAutoDetect := HasFlag(AParams, 'auto');

  // Only explicit --auto may fill missing paths; otherwise missing args stay usage errors.
  if LAutoDetect then
  begin
    if Assigned(CrossToolchainSearchFactory) then
      Search := CrossToolchainSearchFactory()
    else
      Search := TCrossToolchainSearch.Create;
    try
      // Search uses registry metadata so target support is decided before autodetect.
      if LBinutils = '' then
      begin
        BinResult := Search.SearchBinutils(SearchTarget);
        if BinResult.Found then
        begin
          LBinutils := BinResult.BinutilsPath;
          Ctx.Out.WriteLn('Auto-detected binutils: ' + LBinutils +
            ' (prefix: ' + BinResult.BinutilsPrefix + ', layer: ' + BinResult.LayerName + ')');
        end
        else if LAutoDetect then
        begin
          Ctx.Err.WriteLn('Error: could not auto-detect binutils for ' + LTarget);
          Ctx.Err.WriteLn('Install cross-compilation tools or use --binutils=<path>');
          Exit(EXIT_ERROR);
        end;
      end;

      if LLibraries = '' then
      begin
        LibPaths := Search.SearchLibraries(SearchTarget);
        if Length(LibPaths) > 0 then
        begin
          LLibraries := LibPaths[0];
          Ctx.Out.WriteLn('Auto-detected libraries: ' + LLibraries);
        end
        else if LAutoDetect then
        begin
          Ctx.Err.WriteLn('Error: could not auto-detect libraries for ' + LTarget);
          Ctx.Err.WriteLn('Install target libraries or use --libraries=<path>');
          Exit(EXIT_ERROR);
        end;
      end;
    finally
      Search.Free;
    end;
  end;

  if (LBinutils = '') or (LLibraries = '') then
    Exit(MissingArgError(Ctx, '--binutils, --libraries (or use --auto)', _(HELP_CROSS_CONFIGURE_USAGE)));

  LMgr := TCrossCompilerManager.Create(Ctx.Config);
  try
    if LMgr.ConfigureTarget(LTarget, LBinutils, LLibraries, Ctx.Out, Ctx.Err) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross','configure'], @CrossConfigureFactory, []);

end.
