unit fpdev.cmd.cross.configure;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.cross,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TCrossConfigureCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils,
  fpdev.cross.search,
  fpdev.config.interfaces;

function TCrossConfigureCommand.Name: string; begin Result := 'configure'; end;
function TCrossConfigureCommand.Aliases: TStringArray; begin Result := nil; end;
function TCrossConfigureCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function CrossConfigureFactory: ICommand;
begin
  Result := TCrossConfigureCommand.Create;
end;

function ParseTargetForSearch(const ATarget: string; out ACPU, AOS: string): Boolean;
var
  P: Integer;
begin
  Result := False;
  P := Pos('-', ATarget);
  if P < 2 then Exit;
  ACPU := Copy(ATarget, 1, P - 1);
  AOS := Copy(ATarget, P + 1, Length(ATarget));
  Result := (ACPU <> '') and (AOS <> '');
end;

function TCrossConfigureCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LTarget: string;
  LBinutils, LLibraries: string;
  LMgr: TCrossCompilerManager;
  LAutoDetect: Boolean;
  Search: TCrossToolchainSearch;
  SearchTarget: TCrossTarget;
  BinResult: TCrossSearchResult;
  LibPaths: TStringArray;
  CPU, OS: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
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

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['target']));
    Ctx.Err.WriteLn(_(HELP_CROSS_CONFIGURE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  LTarget := AParams[0];
  LBinutils := '';
  LLibraries := '';
  GetFlagValue(AParams, 'binutils', LBinutils);
  GetFlagValue(AParams, 'libraries', LLibraries);
  LAutoDetect := HasFlag(AParams, 'auto');

  // Auto-detect missing paths using search engine
  if LAutoDetect or (LBinutils = '') or (LLibraries = '') then
  begin
    if ParseTargetForSearch(LTarget, CPU, OS) then
    begin
      Search := TCrossToolchainSearch.Create;
      try
        SearchTarget := Default(TCrossTarget);
        SearchTarget.CPU := CPU;
        SearchTarget.OS := OS;

        // Auto-detect binutils path
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

        // Auto-detect libraries path
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
  end;

  if (LBinutils = '') or (LLibraries = '') then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['--binutils, --libraries (or use --auto)']));
    Ctx.Err.WriteLn(_(HELP_CROSS_CONFIGURE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

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
