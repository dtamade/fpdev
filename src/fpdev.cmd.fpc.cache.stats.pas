unit fpdev.cmd.fpc.cache.stats;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.build.cache,
  fpdev.i18n.strings;

type
  { TFPCCacheStatsCommand }
  TFPCCacheStatsCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.registry, fpdev.cmd.utils;

function TFPCCacheStatsCommand.Name: string; begin Result := 'stats'; end;

function TFPCCacheStatsCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCCacheStatsCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function FPCCacheStatsFactory: ICommand;
begin
  Result := TFPCCacheStatsCommand.Create;
end;

function TFPCCacheStatsCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LCacheDir: string;
  LCache: TBuildCache;
  LVersions: TStringArray;
  LTotalSize: Int64;
  LSizeStr: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn('Usage: fpdev fpc cache stats [options]');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Show cache statistics');
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
    LTotalSize := LCache.GetTotalCacheSize;

    // Format size in human-readable format
    if LTotalSize > 1024 * 1024 * 1024 then
      LSizeStr := Format('%.2f GB', [LTotalSize / (1024.0 * 1024.0 * 1024.0)])
    else if LTotalSize > 1024 * 1024 then
      LSizeStr := Format('%.2f MB', [LTotalSize / (1024.0 * 1024.0)])
    else if LTotalSize > 1024 then
      LSizeStr := Format('%.2f KB', [LTotalSize / 1024.0])
    else
      LSizeStr := Format('%d bytes', [LTotalSize]);

    Ctx.Out.WriteLn('Cache Statistics:');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('  Cached versions: ' + IntToStr(Length(LVersions)));
    Ctx.Out.WriteLn('  Total size:      ' + LSizeStr);
    Ctx.Out.WriteLn('  Cache directory: ' + LCacheDir);
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(LCache.GetCacheStats);
  finally
    LCache.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','cache','stats'], @FPCCacheStatsFactory, []);

end.
