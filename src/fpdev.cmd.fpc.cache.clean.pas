unit fpdev.cmd.fpc.cache.clean;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.build.cache,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TFPCCacheCleanCommand }
  TFPCCacheCleanCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.registry, fpdev.cmd.utils;

function TFPCCacheCleanCommand.Name: string; begin Result := 'clean'; end;

function TFPCCacheCleanCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCCacheCleanCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function FPCCacheCleanFactory: ICommand;
begin
  Result := TFPCCacheCleanCommand.Create;
end;

function TFPCCacheCleanCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LCacheDir: string;
  LCache: TBuildCache;
  LVersions: TStringArray;
  LVersion: string;
  LAll: Boolean;
  i, LDeleted: Integer;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn('Usage: fpdev fpc cache clean [version] [options]');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Clean cached FPC versions');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Arguments:');
    Ctx.Out.WriteLn('  version       Specific version to clean (e.g., 3.2.2)');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Options:');
    Ctx.Out.WriteLn('  --all         Clean all cached versions');
    Ctx.Out.WriteLn('  -h, --help    Show this help message');
    Exit(0);
  end;

  // Initialize cache
  LCacheDir := GetAppConfigDir(False) + '.fpdev' + PathDelim + 'cache';
  LCache := TBuildCache.Create(LCacheDir);
  try
    LAll := HasFlag(AParams, 'all');

    if LAll then
    begin
      // Clean all cached versions
      LVersions := LCache.ListCachedVersions;
      if Length(LVersions) = 0 then
      begin
        Ctx.Out.WriteLn('No cached versions to clean.');
        Exit(0);
      end;

      Ctx.Out.WriteLn(Format('Found %d cached version(s). Cleaning...', [Length(LVersions)]));
      LDeleted := 0;

      for i := 0 to High(LVersions) do
      begin
        if LCache.DeleteArtifacts(LVersions[i]) then
        begin
          Ctx.Out.WriteLn('  Deleted: ' + LVersions[i]);
          Inc(LDeleted);
        end
        else
          Ctx.Err.WriteLn('  Failed to delete: ' + LVersions[i]);
      end;

      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn(Format('Cleaned %d of %d cached version(s)', [LDeleted, Length(LVersions)]));
    end
    else if Length(AParams) > 0 then
    begin
      // Clean specific version
      LVersion := AParams[0];

      if not LCache.HasArtifacts(LVersion) then
      begin
        Ctx.Err.WriteLn('Version ' + LVersion + ' is not cached.');
        Exit(1);
      end;

      if LCache.DeleteArtifacts(LVersion) then
      begin
        Ctx.Out.WriteLn('Cleaned cache for FPC ' + LVersion);
        Exit(0);
      end
      else
      begin
        Ctx.Err.WriteLn('Failed to clean cache for FPC ' + LVersion);
        Exit(3);
      end;
    end
    else
    begin
      Ctx.Err.WriteLn('Error: Please specify a version or use --all');
      Ctx.Err.WriteLn('Usage: fpdev fpc cache clean [version] [--all]');
      Exit(2);
    end;
  finally
    LCache.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','cache','clean'], @FPCCacheCleanFactory, []);

end.
