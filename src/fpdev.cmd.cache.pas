unit fpdev.cmd.cache;

{
================================================================================
  fpdev.cmd.cache - Global Cache Management Command
================================================================================

  Provides commands for managing all fpdev caches:
  - fpdev cache status    - Show overall cache status
  - fpdev cache stats     - Show detailed cache statistics
  - fpdev cache clean     - Clean all caches (with confirmation)
  - fpdev cache path      - Show cache directory paths

  Aggregates information from:
  - FPC build cache
  - Lazarus cache
  - Package registry cache
  - Index cache

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.output.intf, fpdev.paths, fpdev.exitcodes,
  fpdev.build.cache, fpdev.build.cache.types;

type
  { TCacheCommand - Global cache management }
  TCacheCommand = class(TInterfacedObject, ICommand)
  private
    procedure ShowStatus(const Ctx: IContext);
    procedure ShowStats(const Ctx: IContext);
    procedure ShowPaths(const Ctx: IContext);
    procedure ShowHelp(const Ctx: IContext);

    function FormatSize(ABytes: Int64): string;
    function GetDirectorySize(const APath: string): Int64;
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateCacheCommand: ICommand;

implementation

function CreateCacheCommand: ICommand;
begin
  Result := TCacheCommand.Create;
end;

{ TCacheCommand }

function TCacheCommand.Name: string;
begin
  Result := 'cache';
end;

function TCacheCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TCacheCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TCacheCommand.FormatSize(ABytes: Int64): string;
begin
  if ABytes < 1024 then
    Result := Format('%d B', [ABytes])
  else if ABytes < 1024 * 1024 then
    Result := Format('%.1f KB', [ABytes / 1024])
  else if ABytes < 1024 * 1024 * 1024 then
    Result := Format('%.1f MB', [ABytes / (1024 * 1024)])
  else
    Result := Format('%.2f GB', [ABytes / (1024 * 1024 * 1024)]);
end;

function TCacheCommand.GetDirectorySize(const APath: string): Int64;
var
  SR: TSearchRec;
  FullPath: string;
begin
  Result := 0;
  if not DirectoryExists(APath) then
    Exit;

  if FindFirst(APath + PathDelim + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        FullPath := APath + PathDelim + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
          Result := Result + GetDirectorySize(FullPath)
        else
          Result := Result + SR.Size;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TCacheCommand.ShowHelp(const Ctx: IContext);
begin
  Ctx.Out.WriteLn('Usage: fpdev cache <command>');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Manage fpdev caches.');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Commands:');
  Ctx.Out.WriteLn('  status    Show overall cache status');
  Ctx.Out.WriteLn('  stats     Show detailed cache statistics');
  Ctx.Out.WriteLn('  path      Show cache directory paths');
  Ctx.Out.WriteLn('  help      Show this help');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('For FPC-specific cache management, use:');
  Ctx.Out.WriteLn('  fpdev fpc cache list');
  Ctx.Out.WriteLn('  fpdev fpc cache clean');
  Ctx.Out.WriteLn('  fpdev fpc cache stats');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Examples:');
  Ctx.Out.WriteLn('  fpdev cache status');
  Ctx.Out.WriteLn('  fpdev cache stats');
  Ctx.Out.WriteLn('  fpdev cache path');
end;

procedure TCacheCommand.ShowStatus(const Ctx: IContext);
var
  DataRoot: string;
  CacheDir, BuildsDir, PackagesDir, IndexDir: string;
  TotalSize: Int64;
  BuildCache: TBuildCache;
  Stats: TCacheDetailedStats;
  Versions: TStringArray;
begin
  Ctx.Out.WriteLn('Cache Status');
  Ctx.Out.WriteLn('============');
  Ctx.Out.WriteLn('');

  DataRoot := GetDataRoot;
  CacheDir := DataRoot + PathDelim + 'cache';
  BuildsDir := CacheDir + PathDelim + 'builds';
  PackagesDir := DataRoot + PathDelim + 'registry' + PathDelim + 'packages';
  IndexDir := CacheDir + PathDelim + 'index';

  TotalSize := 0;

  // FPC Build Cache
  Ctx.Out.WriteLn('FPC Build Cache:');
  if DirectoryExists(BuildsDir) then
  begin
    BuildCache := TBuildCache.Create(BuildsDir);
    try
      Stats := BuildCache.GetDetailedStats;
      Versions := BuildCache.ListCachedVersions;
      Ctx.Out.WriteLn('  Entries: ' + IntToStr(Length(Versions)));
      Ctx.Out.WriteLn('  Size:    ' + FormatSize(Stats.TotalSize));
      TotalSize := TotalSize + Stats.TotalSize;
    finally
      BuildCache.Free;
    end;
  end
  else
    Ctx.Out.WriteLn('  (not created)');

  Ctx.Out.WriteLn('');

  // Package Registry
  Ctx.Out.WriteLn('Package Registry:');
  if DirectoryExists(PackagesDir) then
  begin
    Ctx.Out.WriteLn('  Path: ' + PackagesDir);
    Ctx.Out.WriteLn('  Size: ' + FormatSize(GetDirectorySize(PackagesDir)));
    TotalSize := TotalSize + GetDirectorySize(PackagesDir);
  end
  else
    Ctx.Out.WriteLn('  (not created)');

  Ctx.Out.WriteLn('');

  // Index Cache
  Ctx.Out.WriteLn('Index Cache:');
  if DirectoryExists(IndexDir) then
  begin
    Ctx.Out.WriteLn('  Path: ' + IndexDir);
    Ctx.Out.WriteLn('  Size: ' + FormatSize(GetDirectorySize(IndexDir)));
    TotalSize := TotalSize + GetDirectorySize(IndexDir);
  end
  else
    Ctx.Out.WriteLn('  (not created)');

  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Total Cache Size: ' + FormatSize(TotalSize));
end;

procedure TCacheCommand.ShowStats(const Ctx: IContext);
var
  DataRoot, BuildsDir: string;
  BuildCache: TBuildCache;
  Stats: TCacheDetailedStats;
begin
  Ctx.Out.WriteLn('Cache Statistics');
  Ctx.Out.WriteLn('================');
  Ctx.Out.WriteLn('');

  DataRoot := GetDataRoot;
  BuildsDir := DataRoot + PathDelim + 'cache' + PathDelim + 'builds';

  // FPC Build Cache detailed stats
  Ctx.Out.WriteLn('FPC Build Cache:');
  if DirectoryExists(BuildsDir) then
  begin
    BuildCache := TBuildCache.Create(BuildsDir);
    try
      Stats := BuildCache.GetDetailedStats;
      Ctx.Out.WriteLn('  Total Entries:    ' + IntToStr(Stats.TotalEntries));
      Ctx.Out.WriteLn('  Total Size:       ' + FormatSize(Stats.TotalSize));
      Ctx.Out.WriteLn('  Average Size:     ' + FormatSize(Stats.AverageEntrySize));
      Ctx.Out.WriteLn('  Total Accesses:   ' + IntToStr(Stats.TotalAccesses));

      if Stats.MostAccessedVersion <> '' then
      begin
        Ctx.Out.WriteLn('');
        Ctx.Out.WriteLn('  Most Accessed:    ' + Stats.MostAccessedVersion +
                        ' (' + IntToStr(Stats.MostAccessedCount) + ' times)');
      end;

      if Stats.LeastAccessedVersion <> '' then
        Ctx.Out.WriteLn('  Least Accessed:   ' + Stats.LeastAccessedVersion +
                        ' (' + IntToStr(Stats.LeastAccessedCount) + ' times)');
    finally
      BuildCache.Free;
    end;
  end
  else
    Ctx.Out.WriteLn('  (not created)');
end;

procedure TCacheCommand.ShowPaths(const Ctx: IContext);
var
  DataRoot: string;
begin
  Ctx.Out.WriteLn('Cache Paths');
  Ctx.Out.WriteLn('===========');
  Ctx.Out.WriteLn('');

  DataRoot := GetDataRoot;

  Ctx.Out.WriteLn('Data Root:');
  Ctx.Out.WriteLn('  ' + DataRoot);
  Ctx.Out.WriteLn('');

  Ctx.Out.WriteLn('Cache Directories:');
  Ctx.Out.WriteLn('  Builds:    ' + DataRoot + PathDelim + 'cache' + PathDelim + 'builds');
  Ctx.Out.WriteLn('  Index:     ' + DataRoot + PathDelim + 'cache' + PathDelim + 'index');
  Ctx.Out.WriteLn('  Downloads: ' + DataRoot + PathDelim + 'cache' + PathDelim + 'downloads');
  Ctx.Out.WriteLn('');

  Ctx.Out.WriteLn('Registry:');
  Ctx.Out.WriteLn('  Packages:  ' + DataRoot + PathDelim + 'registry' + PathDelim + 'packages');
  Ctx.Out.WriteLn('');

  Ctx.Out.WriteLn('Config:');
  Ctx.Out.WriteLn('  File:      ' + GetConfigPath);
end;

function TCacheCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  SubCmd: string;
begin
  Result := EXIT_OK;

  if Length(AParams) = 0 then
  begin
    ShowHelp(Ctx);
    Exit;
  end;

  SubCmd := LowerCase(AParams[0]);

  if (SubCmd = 'help') or (SubCmd = '--help') or (SubCmd = '-h') then
    ShowHelp(Ctx)
  else if SubCmd = 'status' then
    ShowStatus(Ctx)
  else if SubCmd = 'stats' then
    ShowStats(Ctx)
  else if SubCmd = 'path' then
    ShowPaths(Ctx)
  else
  begin
    Ctx.Err.WriteLn('Error: Unknown subcommand: ' + SubCmd);
    ShowHelp(Ctx);
    Result := EXIT_USAGE_ERROR;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cache'], @CreateCacheCommand, []);

end.
