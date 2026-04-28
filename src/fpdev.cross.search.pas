unit fpdev.cross.search;

{$mode objfpc}{$H+}
// acq:allow-hardcoded-constants-file

{
  TCrossToolchainSearch - Multi-layer toolchain search engine

  Searches for cross-compilation binutils and libraries using a prioritized
  6-layer strategy chain:

    Layer 1: fpdev-managed directory (~/.fpdev/cross/<cpu>-<os>/bin)
    Layer 2: System package paths (/usr/bin, /usr/local/bin)
    Layer 3: PATH environment variable
    Layer 4: Platform-specific paths (multiarch, Homebrew, MSYS2)
    Layer 5: Linker-based discovery (ld --sysroot, dpkg -L)
    Layer 6: Configuration file hints (fpc.cfg -FD/-XP values)

  Each layer returns a TCrossSearchResult. The first successful hit wins.
  All layers produce a search log for diagnostics (cross doctor).
}

interface

uses
  SysUtils, Classes,
  fpdev.config.interfaces, fpdev.cross.searchdiag, fpdev.cross.searchflow;

type
  { Search result from a single strategy layer }
  TCrossSearchResult = fpdev.cross.searchflow.TCrossSearchResult;

  { Search log entry for diagnostics }
  TCrossSearchLogEntry = fpdev.cross.searchdiag.TCrossSearchLogLine;

  { TCrossToolchainSearch - 6-layer cross-compilation toolchain search }
  TCrossToolchainSearch = class
  private
    FLog: array of TCrossSearchLogEntry;
    FLogCount: Integer;
    procedure AddLog(ALayer: Integer; const ALayerName, APath, APrefix: string; AFound: Boolean);
    function CheckTool(const ADir, APrefix, ATool: string): Boolean;

    function SearchLayer1_FPDevManaged(const ATarget: TCrossTarget): TCrossSearchResult;
    function SearchLayer2_SystemPaths(const ATarget: TCrossTarget): TCrossSearchResult;
    function SearchLayer3_EnvPath(const ATarget: TCrossTarget): TCrossSearchResult;
    function SearchLayer4_PlatformSpecific(const ATarget: TCrossTarget): TCrossSearchResult;
    function SearchLayer5_LinkerDiscovery(const ATarget: TCrossTarget): TCrossSearchResult;
    function SearchLayer6_ConfigHints(const ATarget: TCrossTarget; const AFpcCfgPath: string): TCrossSearchResult;

    function GetPrefixCandidates(const ATarget: TCrossTarget): TStringArray;
  public
    constructor Create;

    { Search all layers for binutils }
    function SearchBinutils(const ATarget: TCrossTarget): TCrossSearchResult; virtual;
    function SearchBinutilsWithConfig(const ATarget: TCrossTarget;
      const AFpcCfgPath: string): TCrossSearchResult; virtual;

    { Search for cross-compilation libraries }
    function SearchLibraries(const ATarget: TCrossTarget): TStringArray; virtual;

    { Diagnose toolchain status for a specific target (for cross doctor) }
    function DiagnoseTarget(const ATarget: TCrossTarget): TStringArray; virtual;

    { Diagnostics }
    function GetSearchLog: TStringArray;
    function GetSearchLogCount: Integer;
    procedure ClearLog;
  end;

implementation

uses
  fpdev.paths,
  fpdev.cross.searchpaths;

const
  TOOL_AS = 'as';
  SYSTEM_TOOLCHAIN_DIRS: array[0..2] of string = (
    '/usr/bin',
    '/usr/local/bin',
    '/opt/cross/bin'
  );

{ TCrossToolchainSearch }

constructor TCrossToolchainSearch.Create;
begin
  inherited Create;
  FLog := nil;
  SetLength(FLog, 32);
  FLogCount := 0;
end;

procedure TCrossToolchainSearch.AddLog(ALayer: Integer;
  const ALayerName, APath, APrefix: string; AFound: Boolean);
begin
  if FLogCount >= Length(FLog) then
    SetLength(FLog, Length(FLog) * 2);
  FLog[FLogCount].Layer := ALayer;
  FLog[FLogCount].LayerName := ALayerName;
  FLog[FLogCount].Path := APath;
  FLog[FLogCount].Prefix := APrefix;
  FLog[FLogCount].Found := AFound;
  Inc(FLogCount);
end;

function TCrossToolchainSearch.CheckTool(const ADir, APrefix, ATool: string): Boolean;
var
  FullPath: string;
begin
  FullPath := ADir + PathDelim + APrefix + ATool;
  {$IFDEF MSWINDOWS}
  if not FileExists(FullPath) then
    FullPath := FullPath + '.exe';
  {$ENDIF}
  Result := FileExists(FullPath);
end;

function TCrossToolchainSearch.GetPrefixCandidates(const ATarget: TCrossTarget): TStringArray;
begin
  Result := GetCrossPrefixCandidatesCore(ATarget);
end;

function TCrossToolchainSearch.SearchLayer1_FPDevManaged(
  const ATarget: TCrossTarget): TCrossSearchResult;
var
  BaseDir, TargetDir: string;
  Prefixes: TStringArray;
  I: Integer;
begin
  Result := Default(TCrossSearchResult);

  // fpdev-managed cross toolchains: ~/.fpdev/cross/<cpu>-<os>/bin
  BaseDir := GetDataRoot + PathDelim + 'cross';
  TargetDir := BaseDir + PathDelim + ATarget.CPU + '-' + ATarget.OS + PathDelim + 'bin';

  Prefixes := GetPrefixCandidates(ATarget);
  for I := 0 to High(Prefixes) do
  begin
    if CheckTool(TargetDir, Prefixes[I], TOOL_AS) then
    begin
      Result.Found := True;
      Result.BinutilsPath := TargetDir;
      Result.BinutilsPrefix := Prefixes[I];
      Result.Layer := 1;
      Result.LayerName := 'fpdev-managed';
      AddLog(1, 'fpdev-managed', TargetDir, Prefixes[I], True);
      Exit;
    end;
    AddLog(1, 'fpdev-managed', TargetDir, Prefixes[I], False);
  end;

  // Also check legacy flat path: ~/.fpdev/cross/bin
  TargetDir := BaseDir + PathDelim + 'bin';
  for I := 0 to High(Prefixes) do
  begin
    if CheckTool(TargetDir, Prefixes[I], TOOL_AS) then
    begin
      Result.Found := True;
      Result.BinutilsPath := TargetDir;
      Result.BinutilsPrefix := Prefixes[I];
      Result.Layer := 1;
      Result.LayerName := 'fpdev-managed (legacy)';
      AddLog(1, 'fpdev-managed (legacy)', TargetDir, Prefixes[I], True);
      Exit;
    end;
    AddLog(1, 'fpdev-managed (legacy)', TargetDir, Prefixes[I], False);
  end;
end;

function TCrossToolchainSearch.SearchLayer2_SystemPaths(
  const ATarget: TCrossTarget): TCrossSearchResult;
var
  SystemDir: string;
  Prefixes: TStringArray;
  I, J: Integer;
begin
  Result := Default(TCrossSearchResult);

  Prefixes := GetPrefixCandidates(ATarget);
  for I := Low(SYSTEM_TOOLCHAIN_DIRS) to High(SYSTEM_TOOLCHAIN_DIRS) do
  begin
    SystemDir := SYSTEM_TOOLCHAIN_DIRS[I];
    for J := 0 to High(Prefixes) do
    begin
      if CheckTool(SystemDir, Prefixes[J], TOOL_AS) then
      begin
        Result.Found := True;
        Result.BinutilsPath := SystemDir;
        Result.BinutilsPrefix := Prefixes[J];
        Result.Layer := 2;
        Result.LayerName := 'system-paths';
        AddLog(2, 'system-paths', SystemDir, Prefixes[J], True);
        Exit;
      end;
      AddLog(2, 'system-paths', SystemDir, Prefixes[J], False);
    end;
  end;
end;

function TCrossToolchainSearch.SearchLayer3_EnvPath(
  const ATarget: TCrossTarget): TCrossSearchResult;
var
  EnvPath, Dir: string;
  Dirs: TStringArray;
  Prefixes: TStringArray;
  I, J: Integer;
  Delim: Char;
begin
  Result := Default(TCrossSearchResult);

  EnvPath := GetEnvironmentVariable('PATH');
  if EnvPath = '' then Exit;

  {$IFDEF MSWINDOWS}
  Delim := ';';
  {$ELSE}
  Delim := ':';
  {$ENDIF}

  // Split PATH
  Dirs := nil;
  SetLength(Dirs, 0);
  while EnvPath <> '' do
  begin
    I := Pos(Delim, EnvPath);
    if I > 0 then
    begin
      Dir := Copy(EnvPath, 1, I - 1);
      Delete(EnvPath, 1, I);
    end
    else
    begin
      Dir := EnvPath;
      EnvPath := '';
    end;
    if Dir <> '' then
    begin
      SetLength(Dirs, Length(Dirs) + 1);
      Dirs[High(Dirs)] := Dir;
    end;
  end;

  Prefixes := GetPrefixCandidates(ATarget);
  for I := 0 to High(Dirs) do
  begin
    for J := 0 to High(Prefixes) do
    begin
      if CheckTool(Dirs[I], Prefixes[J], TOOL_AS) then
      begin
        Result.Found := True;
        Result.BinutilsPath := Dirs[I];
        Result.BinutilsPrefix := Prefixes[J];
        Result.Layer := 3;
        Result.LayerName := 'env-path';
        AddLog(3, 'env-path', Dirs[I], Prefixes[J], True);
        Exit;
      end;
      // Don't log every PATH dir to keep log manageable
    end;
  end;
  AddLog(3, 'env-path', '(all PATH dirs)', '', False);
end;

function TCrossToolchainSearch.SearchLayer4_PlatformSpecific(
  const ATarget: TCrossTarget): TCrossSearchResult;
var
  Dirs: array of string;
  DirCount: Integer;
  Prefixes: TStringArray;
  I, J: Integer;

  procedure AddDir(const ADir: string);
  begin
    if DirCount >= Length(Dirs) then
      SetLength(Dirs, Length(Dirs) + 8);
    Dirs[DirCount] := ADir;
    Inc(DirCount);
  end;

begin
  Result := Default(TCrossSearchResult);
  Dirs := nil;
  SetLength(Dirs, 8);
  DirCount := 0;

  {$IFDEF LINUX}
  // Debian/Ubuntu multiarch: /usr/bin/<triple>
  AddDir('/usr/bin');
  // Cross-compilation packages often install to /usr/<triple>/bin
  Prefixes := GetPrefixCandidates(ATarget);
  if Length(Prefixes) > 0 then
  begin
    // e.g. /usr/arm-linux-gnueabihf/bin (tools without prefix)
    AddDir('/usr/' + Copy(Prefixes[0], 1, Length(Prefixes[0]) - 1) + '/bin');
  end;
  // Linaro / ARM toolchain directories
  AddDir('/opt/gcc-arm/bin');
  AddDir('/opt/gcc-linaro/bin');
  // Android NDK typical location
  if ATarget.OS = 'android' then
  begin
    AddDir(GetEnvironmentVariable('ANDROID_NDK_HOME') + '/toolchains/llvm/prebuilt/linux-x86_64/bin');
    AddDir(GetUserDir + 'Android/Sdk/ndk-bundle/toolchains/llvm/prebuilt/linux-x86_64/bin');
  end;
  {$ENDIF}

  {$IFDEF DARWIN}
  // Homebrew paths
  AddDir('/opt/homebrew/bin');
  AddDir('/opt/homebrew/opt/binutils/bin');
  AddDir('/usr/local/opt/binutils/bin');
  {$ENDIF}

  {$IFDEF MSWINDOWS}
  // MSYS2 paths
  AddDir('C:\msys64\mingw64\bin');
  AddDir('C:\msys64\mingw32\bin');
  AddDir('C:\msys64\usr\bin');
  // Typical Windows cross-compilation paths
  AddDir(GetEnvironmentVariable('PROGRAMFILES') + '\FPC\bin');
  {$ENDIF}

  Prefixes := GetPrefixCandidates(ATarget);
  for I := 0 to DirCount - 1 do
  begin
    if Dirs[I] = '' then Continue;
    for J := 0 to High(Prefixes) do
    begin
      if CheckTool(Dirs[I], Prefixes[J], TOOL_AS) then
      begin
        Result.Found := True;
        Result.BinutilsPath := Dirs[I];
        Result.BinutilsPrefix := Prefixes[J];
        Result.Layer := 4;
        Result.LayerName := 'platform-specific';
        AddLog(4, 'platform-specific', Dirs[I], Prefixes[J], True);
        Exit;
      end;
      AddLog(4, 'platform-specific', Dirs[I], Prefixes[J], False);
    end;
  end;
end;

function TCrossToolchainSearch.SearchLayer5_LinkerDiscovery(
  const ATarget: TCrossTarget): TCrossSearchResult;
var
  Prefixes: TStringArray;
  I: Integer;
  {$IFDEF LINUX}
  DpkgDir: string;
  {$ENDIF}
begin
  Result := Default(TCrossSearchResult);
  Prefixes := GetPrefixCandidates(ATarget);

  {$IFDEF LINUX}
  // On Debian/Ubuntu, cross binutils are installed via packages like
  // binutils-arm-linux-gnueabihf, which places tools in /usr/bin/
  // and /usr/<triple>/bin/
  // Check /usr/<triple>/bin for the unprefixed tools
  for I := 0 to High(Prefixes) do
  begin
    // Strip trailing dash for directory name
    DpkgDir := '/usr/' + Copy(Prefixes[I], 1, Length(Prefixes[I]) - 1) + '/bin';
    // In this directory, tools are unprefixed
    if FileExists(DpkgDir + PathDelim + TOOL_AS) then
    begin
      Result.Found := True;
      Result.BinutilsPath := DpkgDir;
      Result.BinutilsPrefix := ''; // Tools are unprefixed in this dir
      Result.Layer := 5;
      Result.LayerName := 'linker-discovery';
      AddLog(5, 'linker-discovery', DpkgDir, '(unprefixed)', True);
      Exit;
    end;
    AddLog(5, 'linker-discovery', DpkgDir, '(unprefixed)', False);
  end;
  {$ENDIF}

  // Fallback: unused on non-Linux
  if ATarget.CPU <> '' then; // suppress hint
  if Length(Prefixes) > 0 then; // suppress hint
  AddLog(5, 'linker-discovery', '(no candidates)', '', False);
end;

function TCrossToolchainSearch.SearchLayer6_ConfigHints(
  const ATarget: TCrossTarget; const AFpcCfgPath: string): TCrossSearchResult;
var
  CfgFile: TStringList;
  Line, Dir, Prefix: string;
  I: Integer;
  InTargetSection: Boolean;
  TargetCPU: string;
begin
  Result := Default(TCrossSearchResult);

  if (AFpcCfgPath = '') or not FileExists(AFpcCfgPath) then
  begin
    AddLog(6, 'config-hints', AFpcCfgPath, '(not found)', False);
    Exit;
  end;

  TargetCPU := UpperCase(ATarget.CPU);
  Dir := '';
  Prefix := '';
  InTargetSection := False;

  CfgFile := TStringList.Create;
  try
    CfgFile.LoadFromFile(AFpcCfgPath);
    for I := 0 to CfgFile.Count - 1 do
    begin
      Line := Trim(CfgFile[I]);

      // Track #IFDEF CPU sections
      if (Pos('#IFDEF CPU', UpperCase(Line)) = 1) then
      begin
        if Pos(TargetCPU, UpperCase(Line)) > 0 then
          InTargetSection := True;
      end
      else if UpperCase(Line) = '#ENDIF' then
      begin
        if InTargetSection then
        begin
          // Check if we found anything in this section
          if Dir <> '' then
          begin
            Result.Found := True;
            Result.BinutilsPath := Dir;
            Result.BinutilsPrefix := Prefix;
            Result.Layer := 6;
            Result.LayerName := 'config-hints';
            AddLog(6, 'config-hints', Dir, Prefix, True);
            Exit;
          end;
          InTargetSection := False;
        end;
      end;

      if InTargetSection then
      begin
        // Parse -FD<path> (binutils directory)
        if Copy(Line, 1, 3) = '-FD' then
          Dir := Copy(Line, 4, Length(Line))
        // Parse -XP<prefix> (binutils prefix)
        else if Copy(Line, 1, 3) = '-XP' then
          Prefix := Copy(Line, 4, Length(Line));
      end;
    end;
  finally
    CfgFile.Free;
  end;

  AddLog(6, 'config-hints', AFpcCfgPath, '(no match)', False);
end;

{ Public API }

function TCrossToolchainSearch.SearchBinutils(const ATarget: TCrossTarget): TCrossSearchResult;
begin
  Result := SearchBinutilsWithConfig(ATarget, '');
end;

function TCrossToolchainSearch.SearchBinutilsWithConfig(const ATarget: TCrossTarget;
  const AFpcCfgPath: string): TCrossSearchResult;
var
  Callbacks: TCrossSearchCallbacks;
begin
  Callbacks := Default(TCrossSearchCallbacks);
  Callbacks.ClearLog := @ClearLog;
  Callbacks.CheckTool := @CheckTool;
  Callbacks.AddLog := @AddLog;
  Callbacks.SearchLayer1 := @SearchLayer1_FPDevManaged;
  Callbacks.SearchLayer2 := @SearchLayer2_SystemPaths;
  Callbacks.SearchLayer3 := @SearchLayer3_EnvPath;
  Callbacks.SearchLayer4 := @SearchLayer4_PlatformSpecific;
  Callbacks.SearchLayer5 := @SearchLayer5_LinkerDiscovery;
  Callbacks.SearchLayer6 := @SearchLayer6_ConfigHints;
  Result := ExecuteCrossBinutilsSearchCore(ATarget, AFpcCfgPath, TOOL_AS, Callbacks);
end;

function TCrossToolchainSearch.SearchLibraries(const ATarget: TCrossTarget): TStringArray;
var
  Prefixes: TStringArray;
begin
  Prefixes := GetPrefixCandidates(ATarget);
  Result := BuildCrossLibraryCandidatesCore(ATarget, Prefixes);
end;

function TCrossToolchainSearch.DiagnoseTarget(const ATarget: TCrossTarget): TStringArray;
var
  BinRes: TCrossSearchResult;
  Libs, Log: TStringArray;
begin
  BinRes := SearchBinutils(ATarget);
  Libs := SearchLibraries(ATarget);
  Log := GetSearchLog;
  Result := BuildCrossDiagnoseLinesCore(
    ATarget.CPU,
    ATarget.OS,
    BinRes.Found,
    BinRes.Layer,
    BinRes.LayerName,
    BinRes.BinutilsPath,
    BinRes.BinutilsPrefix,
    Libs,
    Log
  );
end;

function TCrossToolchainSearch.GetSearchLog: TStringArray;
var
  I: Integer;
  Entries: TCrossSearchLogLineArray;
begin
  Entries := nil;
  SetLength(Entries, FLogCount);
  for I := 0 to FLogCount - 1 do
    Entries[I] := FLog[I];
  Result := BuildCrossSearchLogLinesCore(Entries);
end;

function TCrossToolchainSearch.GetSearchLogCount: Integer;
begin
  Result := FLogCount;
end;

procedure TCrossToolchainSearch.ClearLog;
begin
  FLogCount := 0;
end;

end.
