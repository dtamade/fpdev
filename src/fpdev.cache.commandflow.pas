unit fpdev.cache.commandflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf;

procedure WriteCacheHelp(const Ctx: IContext);
procedure RunCacheStatus(const Ctx: IContext);
procedure RunCacheStats(const Ctx: IContext);
procedure RunCachePath(const Ctx: IContext);

implementation

uses
  fpdev.help.details.system,
  fpdev.paths,
  fpdev.build.cache,
  fpdev.build.cache.types,
  fpdev.system.view;

function FormatCacheSize(ABytes: Int64): string;
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

function GetDirectorySize(const APath: string): Int64;
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

procedure WriteCacheHelp(const Ctx: IContext);
begin
  WriteSystemCacheHelpCore(Ctx);
end;

procedure RunCacheStatus(const Ctx: IContext);
var
  DataRoot: string;
  CacheDir, BuildsDir, PackagesDir, IndexDir: string;
  TotalSize: Int64;
  BuildCache: TBuildCache;
  Stats: TCacheDetailedStats;
  Versions: TStringArray;
  Lines: TStringArray;
  Line: string;
  BuildSizeText: string;
  PackageSizeText: string;
  IndexSizeText: string;
  TotalSizeText: string;
begin
  DataRoot := GetDataRoot;
  CacheDir := DataRoot + PathDelim + 'cache';
  BuildsDir := CacheDir + PathDelim + 'builds';
  PackagesDir := DataRoot + PathDelim + 'registry' + PathDelim + 'packages';
  IndexDir := CacheDir + PathDelim + 'index';
  TotalSize := 0;
  BuildSizeText := '';
  if DirectoryExists(BuildsDir) then
  begin
    BuildCache := TBuildCache.Create(BuildsDir);
    try
      Stats := BuildCache.GetDetailedStats;
      Versions := BuildCache.ListCachedVersions;
      BuildSizeText := FormatCacheSize(Stats.TotalSize);
      TotalSize := TotalSize + Stats.TotalSize;
    finally
      BuildCache.Free;
    end;
  end
  else
    Versions := nil;

  PackageSizeText := '';
  if DirectoryExists(PackagesDir) then
  begin
    PackageSizeText := FormatCacheSize(GetDirectorySize(PackagesDir));
    TotalSize := TotalSize + GetDirectorySize(PackagesDir);
  end;

  IndexSizeText := '';
  if DirectoryExists(IndexDir) then
  begin
    IndexSizeText := FormatCacheSize(GetDirectorySize(IndexDir));
    TotalSize := TotalSize + GetDirectorySize(IndexDir);
  end;

  TotalSizeText := FormatCacheSize(TotalSize);
  Lines := BuildSystemCacheStatusLinesCore(
    PackagesDir,
    IndexDir,
    Length(Versions),
    BuildSizeText,
    PackageSizeText,
    IndexSizeText,
    TotalSizeText,
    DirectoryExists(BuildsDir),
    DirectoryExists(PackagesDir),
    DirectoryExists(IndexDir)
  );
  for Line in Lines do
    Ctx.Out.WriteLn(Line);
end;

procedure RunCacheStats(const Ctx: IContext);
var
  DataRoot, BuildsDir: string;
  BuildCache: TBuildCache;
  Stats: TCacheDetailedStats;
  Lines: TStringArray;
  Line: string;
  MostAccessedText: string;
  LeastAccessedText: string;
begin
  DataRoot := GetDataRoot;
  BuildsDir := DataRoot + PathDelim + 'cache' + PathDelim + 'builds';
  if DirectoryExists(BuildsDir) then
  begin
    BuildCache := TBuildCache.Create(BuildsDir);
    try
      Stats := BuildCache.GetDetailedStats;
      if Stats.MostAccessedVersion <> '' then
        MostAccessedText := Stats.MostAccessedVersion + ' (' + IntToStr(Stats.MostAccessedCount) + ' times)'
      else
        MostAccessedText := '';

      if Stats.LeastAccessedVersion <> '' then
        LeastAccessedText := Stats.LeastAccessedVersion + ' (' + IntToStr(Stats.LeastAccessedCount) + ' times)'
      else
        LeastAccessedText := '';
      Lines := BuildSystemCacheStatsLinesCore(
        True,
        Stats.TotalEntries,
        FormatCacheSize(Stats.TotalSize),
        FormatCacheSize(Stats.AverageEntrySize),
        IntToStr(Stats.TotalAccesses),
        MostAccessedText,
        LeastAccessedText
      );
    finally
      BuildCache.Free;
    end;
  end
  else
    Lines := BuildSystemCacheStatsLinesCore(False, 0, '', '', '', '', '');
  for Line in Lines do
    Ctx.Out.WriteLn(Line);
end;

procedure RunCachePath(const Ctx: IContext);
var
  DataRoot: string;
  Lines: TStringArray;
  Line: string;
begin
  DataRoot := GetDataRoot;
  Lines := BuildSystemCachePathLinesCore(
    DataRoot,
    DataRoot + PathDelim + 'cache' + PathDelim + 'builds',
    DataRoot + PathDelim + 'cache' + PathDelim + 'index',
    DataRoot + PathDelim + 'cache' + PathDelim + 'downloads',
    DataRoot + PathDelim + 'registry' + PathDelim + 'packages',
    GetConfigPath
  );
  for Line in Lines do
    Ctx.Out.WriteLn(Line);
end;

end.
