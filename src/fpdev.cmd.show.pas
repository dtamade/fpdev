unit fpdev.cmd.show;

{
  fpdev show command

  Display an overview of the current toolchain configuration, similar to rustup show

  Usage:
    fpdev show              # Show full configuration overview
    fpdev show --active     # Show only active versions
    fpdev show --installed  # Show only installed versions
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf,
  fpdev.command.registry, fpdev.exitcodes;

type
  { TShowCommand - Display current configuration overview }
  TShowCommand = class(TInterfacedObject, ICommand)
  private
    procedure ShowActiveToolchain(const Ctx: IContext);
    procedure ShowInstalledVersions(const Ctx: IContext);
    procedure ShowFullOverview(const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function ShowCommandFactory: ICommand;

implementation

uses
  fpdev.config.interfaces,
  fpdev.config.project;

const
  HELP_SHOW = 'Usage: fpdev show [options]' + LineEnding +
              '' + LineEnding +
              'Display current toolchain configuration overview.' + LineEnding +
              '' + LineEnding +
              'Options:' + LineEnding +
              '  --active      Show only active toolchain versions' + LineEnding +
              '  --installed   Show only installed versions' + LineEnding +
              '  -h, --help    Show this help message' + LineEnding +
              '' + LineEnding +
              'Without options, shows a complete overview including:' + LineEnding +
              '  - Active toolchain (and why it''s active)' + LineEnding +
              '  - Installed FPC versions' + LineEnding +
              '  - Installed Lazarus versions' + LineEnding +
              '  - Cross-compilation targets' + LineEnding +
              '  - Global defaults';

function ShowCommandFactory: ICommand;
begin
  Result := TShowCommand.Create;
end;

{ TShowCommand }

function TShowCommand.Name: string;
begin
  Result := 'show';
end;

function TShowCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TShowCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

procedure TShowCommand.ShowActiveToolchain(const Ctx: IContext);
var
  LResolver: TProjectConfigResolver;
  LResolved: TResolvedConfig;
  LGlobalFPC, LGlobalLazarus: string;
begin
  // Get global defaults
  LGlobalFPC := '';
  LGlobalLazarus := '';

  if Ctx.Config <> nil then
  begin
    LGlobalFPC := Ctx.Config.GetToolchainManager.GetDefaultToolchain;
    if Pos('fpc-', LGlobalFPC) = 1 then
      LGlobalFPC := Copy(LGlobalFPC, 5, Length(LGlobalFPC));

    LGlobalLazarus := Ctx.Config.GetLazarusManager.GetDefaultLazarusVersion;
    if Pos('lazarus-', LGlobalLazarus) = 1 then
      LGlobalLazarus := Copy(LGlobalLazarus, 9, Length(LGlobalLazarus));
  end;

  LResolver := TProjectConfigResolver.Create(LGlobalFPC, LGlobalLazarus);
  try
    LResolved := LResolver.ResolveConfig(GetCurrentDir);

    Ctx.Out.WriteLn('Active toolchain');
    Ctx.Out.WriteLn('----------------');
    Ctx.Out.WriteLn('');

    // FPC
    Ctx.Out.WriteLn('FPC:     ' + LResolved.FPCVersion);
    case LResolved.FPCSource of
      csDefault:
        Ctx.Out.WriteLn('         (system default)');
      csGlobal:
        Ctx.Out.WriteLn('         (global default)');
      csProject:
        Ctx.Out.WriteLn('         (set by ' + LResolved.FPCSourceFile + ')');
      csCommandLine:
        Ctx.Out.WriteLn('         (set by command line)');
      csEnvironment:
        Ctx.Out.WriteLn('         (set by $' + LResolved.FPCSourceFile + ')');
    end;

    Ctx.Out.WriteLn('');

    // Lazarus
    Ctx.Out.WriteLn('Lazarus: ' + LResolved.LazarusVersion);
    case LResolved.LazarusSource of
      csDefault:
        Ctx.Out.WriteLn('         (system default)');
      csGlobal:
        Ctx.Out.WriteLn('         (global default)');
      csProject:
        Ctx.Out.WriteLn('         (set by ' + LResolved.LazarusSourceFile + ')');
      csCommandLine:
        Ctx.Out.WriteLn('         (set by command line)');
      csEnvironment:
        Ctx.Out.WriteLn('         (set by $' + LResolved.LazarusSourceFile + ')');
    end;
  finally
    LResolver.Free;
  end;
end;

procedure TShowCommand.ShowInstalledVersions(const Ctx: IContext);
var
  LToolchains: TStringArray;
  LLazarusVersions: TStringArray;
  LCrossTargets: TStringArray;
  I: Integer;
  LName: string;
begin
  Ctx.Out.WriteLn('Installed toolchains');
  Ctx.Out.WriteLn('--------------------');
  Ctx.Out.WriteLn('');

  // FPC versions
  Ctx.Out.WriteLn('FPC:');
  LToolchains := Ctx.Config.GetToolchainManager.ListToolchains;
  if Length(LToolchains) = 0 then
    Ctx.Out.WriteLn('  (none installed)')
  else
  begin
    for I := 0 to High(LToolchains) do
    begin
      LName := LToolchains[I];
      // Remove 'fpc-' prefix for display
      if Pos('fpc-', LName) = 1 then
        LName := Copy(LName, 5, Length(LName));
      Ctx.Out.WriteLn('  ' + LName);
    end;
  end;

  Ctx.Out.WriteLn('');

  // Lazarus versions
  Ctx.Out.WriteLn('Lazarus:');
  LLazarusVersions := Ctx.Config.GetLazarusManager.ListLazarusVersions;
  if Length(LLazarusVersions) = 0 then
    Ctx.Out.WriteLn('  (none installed)')
  else
  begin
    for I := 0 to High(LLazarusVersions) do
    begin
      LName := LLazarusVersions[I];
      if Pos('lazarus-', LName) = 1 then
        LName := Copy(LName, 9, Length(LName));
      Ctx.Out.WriteLn('  ' + LName);
    end;
  end;

  Ctx.Out.WriteLn('');

  // Cross targets
  Ctx.Out.WriteLn('Cross-compilation targets:');
  LCrossTargets := Ctx.Config.GetCrossTargetManager.ListCrossTargets;
  if Length(LCrossTargets) = 0 then
    Ctx.Out.WriteLn('  (none installed)')
  else
  begin
    for I := 0 to High(LCrossTargets) do
      Ctx.Out.WriteLn('  ' + LCrossTargets[I]);
  end;
end;

procedure TShowCommand.ShowFullOverview(const Ctx: IContext);
var
  LDefaultFPC, LDefaultLazarus: string;
  LSettings: TFPDevSettings;
  LProjectConfig: string;
  LResolver: TProjectConfigResolver;
begin
  // Show active toolchain
  ShowActiveToolchain(Ctx);

  Ctx.Out.WriteLn('');

  // Show installed versions
  ShowInstalledVersions(Ctx);

  Ctx.Out.WriteLn('');

  // Show global defaults
  Ctx.Out.WriteLn('Global defaults');
  Ctx.Out.WriteLn('---------------');

  LDefaultFPC := Ctx.Config.GetToolchainManager.GetDefaultToolchain;
  if Pos('fpc-', LDefaultFPC) = 1 then
    LDefaultFPC := Copy(LDefaultFPC, 5, Length(LDefaultFPC));

  LDefaultLazarus := Ctx.Config.GetLazarusManager.GetDefaultLazarusVersion;
  if Pos('lazarus-', LDefaultLazarus) = 1 then
    LDefaultLazarus := Copy(LDefaultLazarus, 9, Length(LDefaultLazarus));

  if LDefaultFPC <> '' then
    Ctx.Out.WriteLn('  FPC default:     ' + LDefaultFPC)
  else
    Ctx.Out.WriteLn('  FPC default:     (not set)');

  if LDefaultLazarus <> '' then
    Ctx.Out.WriteLn('  Lazarus default: ' + LDefaultLazarus)
  else
    Ctx.Out.WriteLn('  Lazarus default: (not set)');

  Ctx.Out.WriteLn('');

  // Show project configuration
  Ctx.Out.WriteLn('Project configuration');
  Ctx.Out.WriteLn('---------------------');

  LResolver := TProjectConfigResolver.Create;
  try
    LProjectConfig := LResolver.FindProjectConfig(GetCurrentDir);
    if LProjectConfig <> '' then
      Ctx.Out.WriteLn('  Config file: ' + LProjectConfig)
    else
      Ctx.Out.WriteLn('  No .fpdevrc or fpdev.toml found in current directory tree');
  finally
    LResolver.Free;
  end;

  Ctx.Out.WriteLn('');

  // Show settings
  Ctx.Out.WriteLn('Settings');
  Ctx.Out.WriteLn('--------');
  LSettings := Ctx.Config.GetSettingsManager.GetSettings;
  Ctx.Out.WriteLn('  Install root:   ' + LSettings.InstallRoot);
  Ctx.Out.WriteLn('  Mirror:         ' + LSettings.Mirror);
  Ctx.Out.WriteLn('  Parallel jobs:  ' + IntToStr(LSettings.ParallelJobs));
  Ctx.Out.WriteLn('  Keep sources:   ' + BoolToStr(LSettings.KeepSources, 'yes', 'no'));
end;

function TShowCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  I: Integer;
  LShowActive, LShowInstalled: Boolean;
begin
  Result := 0;
  LShowActive := False;
  LShowInstalled := False;

  // Parse arguments
  for I := 0 to High(AParams) do
  begin
    if (AParams[I] = '-h') or (AParams[I] = '--help') then
    begin
      Ctx.Out.WriteLn(HELP_SHOW);
      Exit(EXIT_OK);
    end
    else if AParams[I] = '--active' then
      LShowActive := True
    else if AParams[I] = '--installed' then
      LShowInstalled := True;
  end;

  Ctx.Out.WriteLn('');

  if LShowActive then
    ShowActiveToolchain(Ctx)
  else if LShowInstalled then
    ShowInstalledVersions(Ctx)
  else
    ShowFullOverview(Ctx);

  Ctx.Out.WriteLn('');
end;

initialization
  GlobalCommandRegistry.RegisterPath(['show'], @ShowCommandFactory, []);

end.
