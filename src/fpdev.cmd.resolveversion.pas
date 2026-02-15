unit fpdev.cmd.resolveversion;

{
  fpdev resolve-version command

  Internal command for use by shell hooks
  Resolve the effective FPC version for the current directory (respecting configuration precedence)

  Usage:
    fpdev resolve-version           # Output the effective FPC version
    fpdev resolve-version --json    # Output full details in JSON format
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.exitcodes;

type
  { TResolveVersionCommand - Resolve effective version }
  TResolveVersionCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function ResolveVersionCommandFactory: ICommand;

implementation

uses
  fpjson,
  fpdev.config.project;

const
  HELP_RESOLVE_VERSION =
    'Usage: fpdev resolve-version [--json]' + LineEnding +
    '' + LineEnding +
    'Resolve the effective FPC version for the current directory.' + LineEnding +
    '' + LineEnding +
    'Options:' + LineEnding +
    '  --json           Output detailed JSON' + LineEnding +
    '  --help, -h       Show this help message';

function ResolveVersionCommandFactory: ICommand;
begin
  Result := TResolveVersionCommand.Create;
end;

{ TResolveVersionCommand }

function TResolveVersionCommand.Name: string;
begin
  Result := 'resolve-version';
end;

function TResolveVersionCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TResolveVersionCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function TResolveVersionCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LResolver: TProjectConfigResolver;
  LResolved: TResolvedConfig;
  LGlobalFPC, LGlobalLazarus: string;
  LJsonOutput: Boolean;
  LJson: TJSONObject;
  I: Integer;
begin
  Result := EXIT_OK;

  // Help output (this is an internal command used by shell hooks)
  for I := 0 to High(AParams) do
  begin
    if (AParams[I] = '--help') or (AParams[I] = '-h') then
    begin
      Ctx.Out.WriteLn(HELP_RESOLVE_VERSION);
      Exit(EXIT_OK);
    end;
  end;

  // Check --json flag
  LJsonOutput := False;
  for I := 0 to High(AParams) do
  begin
    if AParams[I] = '--json' then
    begin
      LJsonOutput := True;
      Break;
    end;
  end;

  // Get global defaults
  LGlobalFPC := '';
  LGlobalLazarus := '';

  if Ctx.Config <> nil then
  begin
    LGlobalFPC := Ctx.Config.GetToolchainManager.GetDefaultToolchain;
    // Remove 'fpc-' prefix
    if Pos('fpc-', LGlobalFPC) = 1 then
      LGlobalFPC := Copy(LGlobalFPC, 5, Length(LGlobalFPC));

    LGlobalLazarus := Ctx.Config.GetLazarusManager.GetDefaultLazarusVersion;
    // Remove 'lazarus-' prefix
    if Pos('lazarus-', LGlobalLazarus) = 1 then
      LGlobalLazarus := Copy(LGlobalLazarus, 9, Length(LGlobalLazarus));
  end;

  // Create resolver
  LResolver := TProjectConfigResolver.Create(LGlobalFPC, LGlobalLazarus);
  try
    LResolved := LResolver.ResolveConfig(GetCurrentDir);

    if LJsonOutput then
    begin
      // JSON-formatted output
      LJson := TJSONObject.Create;
      try
        LJson.Add('fpc_version', LResolved.FPCVersion);
        LJson.Add('fpc_source', ConfigSourceToString(LResolved.FPCSource));
        if LResolved.FPCSourceFile <> '' then
          LJson.Add('fpc_source_file', LResolved.FPCSourceFile);

        LJson.Add('lazarus_version', LResolved.LazarusVersion);
        LJson.Add('lazarus_source', ConfigSourceToString(LResolved.LazarusSource));
        if LResolved.LazarusSourceFile <> '' then
          LJson.Add('lazarus_source_file', LResolved.LazarusSourceFile);

        LJson.Add('mirror', LResolved.Mirror);
        LJson.Add('auto_install', LResolved.AutoInstall);

        Ctx.Out.WriteLn(LJson.FormatJSON);
      finally
        LJson.Free;
      end;
    end
    else
    begin
      // Simple output: version number only (for shell hook use)
      Ctx.Out.WriteLn(LResolved.FPCVersion);
    end;
  finally
    LResolver.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['resolve-version'], @ResolveVersionCommandFactory, []);

end.
