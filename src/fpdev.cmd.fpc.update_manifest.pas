unit fpdev.cmd.fpc.update_manifest;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.fpc,
  fpdev.i18n.strings, fpdev.exitcodes;

type
  { TFPCUpdateManifestCommand }
  TFPCUpdateManifestCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.cmd.utils, fpdev.manifest.cache, fpdev.manifest;

function TFPCUpdateManifestCommand.Name: string;
begin
  Result := 'update-manifest';
end;

function TFPCUpdateManifestCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCUpdateManifestCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function TFPCUpdateManifestCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  Cache: TManifestCache;
  Manifest: TManifestParser;
  ForceRefresh: Boolean;
  Err: string;
  Versions: TStringArray;
  I: Integer;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn('Usage: fpdev fpc update-manifest [options]');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Download and cache the latest FPC manifest from remote repository.');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Options:');
    Ctx.Out.WriteLn('  --force       Force refresh even if cache is valid');
    Ctx.Out.WriteLn('  -h, --help    Show this help message');
    Exit(EXIT_OK);
  end;

  ForceRefresh := HasFlag(AParams, 'force');

  Ctx.Out.WriteLn('Updating FPC manifest...');

  Cache := TManifestCache.Create('');
  try
    // Download manifest
    if ForceRefresh then
    begin
      Ctx.Out.WriteLn('Forcing manifest refresh...');
      if not Cache.DownloadManifest('fpc', Err) then
      begin
        Ctx.Err.WriteLn('Error: Failed to download manifest: ' + Err);
        Exit(EXIT_ERROR);
      end;
    end;

    // Load manifest (will auto-download if needed)
    if not Cache.LoadCachedManifest('fpc', Manifest, ForceRefresh) then
    begin
      Ctx.Err.WriteLn('Error: Failed to load manifest');
      Exit(EXIT_ERROR);
    end;

    try
      // Display manifest info
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Manifest updated successfully!');
      Ctx.Out.WriteLn('  Version: ' + Manifest.ManifestVersion);
      Ctx.Out.WriteLn('  Date: ' + Manifest.Date);
      Ctx.Out.WriteLn('  Cache: ' + Cache.CacheDir);

      // List available versions
      Versions := Manifest.ListVersions('fpc');
      if Length(Versions) > 0 then
      begin
        Ctx.Out.WriteLn('');
        Ctx.Out.WriteLn('Available FPC versions:');
        for I := 0 to High(Versions) do
          Ctx.Out.WriteLn('  - ' + Versions[I]);
      end;

      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Use "fpdev fpc list --remote" to see all available versions.');
    finally
      Manifest.Free;
    end;
  finally
    Cache.Free;
  end;
end;

function FPCUpdateManifestFactory: ICommand;
begin
  Result := TFPCUpdateManifestCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','update-manifest'], @FPCUpdateManifestFactory, []);

end.
