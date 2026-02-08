unit fpdev.cmd.fpc.cache.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.build.cache,
  fpdev.i18n.strings;

type
  { TFPCCacheListCommand }
  TFPCCacheListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.registry, fpdev.cmd.utils;

function TFPCCacheListCommand.Name: string; begin Result := 'list'; end;

function TFPCCacheListCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCCacheListCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function FPCCacheListFactory: ICommand;
begin
  Result := TFPCCacheListCommand.Create;
end;

function TFPCCacheListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LCacheDir: string;
  LCache: TBuildCache;
  LVersions: TStringArray;
  LInfo: TArtifactInfo;
  i: Integer;
  LSizeStr: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn('Usage: fpdev fpc cache list [options]');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('List all cached FPC versions');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Options:');
    Ctx.Out.WriteLn('  -h, --help    Show this help message');
    Exit(0);
  end;

  // Initialize cache
  LCacheDir := GetAppConfigDir(False) + '.fpdev' + PathDelim + 'cache';
  LCache := TBuildCache.Create(LCacheDir);
  try
    LVersions := LCache.ListCachedVersions;

    if Length(LVersions) = 0 then
    begin
      Ctx.Out.WriteLn('No cached FPC versions found.');
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Cache directory: ' + LCacheDir);
      Exit(0);
    end;

    Ctx.Out.WriteLn('Cached FPC versions:');
    Ctx.Out.WriteLn('');

    for i := 0 to High(LVersions) do
    begin
      if LCache.GetArtifactInfo(LVersions[i], LInfo) then
      begin
        // Format size in human-readable format
        if LInfo.ArchiveSize > 1024 * 1024 * 1024 then
          LSizeStr := Format('%.2f GB', [LInfo.ArchiveSize / (1024.0 * 1024.0 * 1024.0)])
        else if LInfo.ArchiveSize > 1024 * 1024 then
          LSizeStr := Format('%.2f MB', [LInfo.ArchiveSize / (1024.0 * 1024.0)])
        else if LInfo.ArchiveSize > 1024 then
          LSizeStr := Format('%.2f KB', [LInfo.ArchiveSize / 1024.0])
        else
          LSizeStr := Format('%d bytes', [LInfo.ArchiveSize]);

        Ctx.Out.WriteLn(Format('  %s (%s, %s-%s)',
          [LVersions[i], LSizeStr, LInfo.CPU, LInfo.OS]));
      end
      else
      begin
        Ctx.Out.WriteLn('  ' + LVersions[i]);
      end;
    end;

    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(Format('Total: %d cached version(s)', [Length(LVersions)]));
    Ctx.Out.WriteLn('Cache directory: ' + LCacheDir);
  finally
    LCache.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','cache','list'], @FPCCacheListFactory, []);

end.
