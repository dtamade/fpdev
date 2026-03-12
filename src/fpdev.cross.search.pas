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
  fpdev.config.interfaces;

type
  { Search result from a single strategy layer }
  TCrossSearchResult = record
    Found: Boolean;
    BinutilsPath: string;    // Directory containing binutils
    BinutilsPrefix: string;  // Tool prefix (e.g. arm-linux-gnueabihf-)
    LibrariesPath: string;   // Cross-compilation libraries path
    Layer: Integer;           // Which layer found it (1-6)
    LayerName: string;        // Human-readable layer name
  end;

  { Search log entry for diagnostics }
  TCrossSearchLogEntry = record
    Layer: Integer;
    LayerName: string;
    Path: string;
    Prefix: string;
    Found: Boolean;
  end;

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
    function SearchBinutils(const ATarget: TCrossTarget): TCrossSearchResult;
    function SearchBinutilsWithConfig(const ATarget: TCrossTarget;
      const AFpcCfgPath: string): TCrossSearchResult;

    { Search for cross-compilation libraries }
    function SearchLibraries(const ATarget: TCrossTarget): TStringArray;

    { Diagnose toolchain status for a specific target (for cross doctor) }
    function DiagnoseTarget(const ATarget: TCrossTarget): TStringArray;

    { Diagnostics }
    function GetSearchLog: TStringArray;
    function GetSearchLogCount: Integer;
    procedure ClearLog;
  end;

implementation

uses
  fpdev.paths;

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
var
  CPU, OS: string;
begin
  Result := nil;
  CPU := ATarget.CPU;
  OS := ATarget.OS;

  // If target already has a configured prefix, try it first
  if ATarget.BinutilsPrefix <> '' then
  begin
    SetLength(Result, 1);
    Result[0] := ATarget.BinutilsPrefix;
    Exit;
  end;

  if CPU = 'arm' then
  begin
    if OS = 'linux' then
    begin
      SetLength(Result, 4);
      Result[0] := 'arm-linux-gnueabihf-';
      Result[1] := 'arm-linux-gnueabi-';
      Result[2] := 'arm-none-eabi-';
      Result[3] := 'arm-linux-musleabihf-';
    end
    else if OS = 'android' then
    begin
      SetLength(Result, 2);
      Result[0] := 'arm-linux-androideabi-';
      Result[1] := 'armv7a-linux-androideabi-';
    end
    else
    begin
      SetLength(Result, 1);
      Result[0] := 'arm-' + OS + '-';
    end;
  end
  else if CPU = 'aarch64' then
  begin
    if OS = 'linux' then
    begin
      SetLength(Result, 2);
      Result[0] := 'aarch64-linux-gnu-';
      Result[1] := 'aarch64-linux-musl-';
    end
    else if OS = 'android' then
    begin
      SetLength(Result, 1);
      Result[0] := 'aarch64-linux-android-';
    end
    else if OS = 'darwin' then
    begin
      SetLength(Result, 1);
      Result[0] := 'aarch64-apple-darwin-';
    end
    else
    begin
      SetLength(Result, 1);
      Result[0] := 'aarch64-' + OS + '-';
    end;
  end
  else if CPU = 'i386' then
  begin
    if (OS = 'win32') or (OS = 'win64') then
    begin
      SetLength(Result, 1);
      Result[0] := 'i686-w64-mingw32-';
    end
    else
    begin
      SetLength(Result, 2);
      Result[0] := 'i686-linux-gnu-';
      Result[1] := 'i386-linux-gnu-';
    end;
  end
  else if CPU = 'x86_64' then
  begin
    if (OS = 'win64') or (OS = 'win32') then
    begin
      SetLength(Result, 1);
      Result[0] := 'x86_64-w64-mingw32-';
    end
    else if OS = 'darwin' then
    begin
      SetLength(Result, 1);
      Result[0] := 'x86_64-apple-darwin-';
    end
    else
    begin
      SetLength(Result, 1);
      Result[0] := 'x86_64-linux-gnu-';
    end;
  end
  else if CPU = 'mipsel' then
  begin
    SetLength(Result, 2);
    Result[0] := 'mipsel-linux-gnu-';
    Result[1] := 'mipsel-linux-musl-';
  end
  else if CPU = 'mips' then
  begin
    SetLength(Result, 2);
    Result[0] := 'mips-linux-gnu-';
    Result[1] := 'mips-linux-musl-';
  end
  else if CPU = 'powerpc' then
  begin
    SetLength(Result, 1);
    Result[0] := 'powerpc-linux-gnu-';
  end
  else if CPU = 'powerpc64' then
  begin
    SetLength(Result, 2);
    Result[0] := 'powerpc64le-linux-gnu-';
    Result[1] := 'powerpc64-linux-gnu-';
  end
  else if CPU = 'riscv64' then
  begin
    SetLength(Result, 1);
    Result[0] := 'riscv64-linux-gnu-';
  end
  else if CPU = 'riscv32' then
  begin
    SetLength(Result, 1);
    Result[0] := 'riscv32-linux-gnu-';
  end
  else if CPU = 'sparc' then
  begin
    SetLength(Result, 1);
    Result[0] := 'sparc64-linux-gnu-';
  end
  else
  begin
    // Generic fallback
    SetLength(Result, 1);
    Result[0] := CPU + '-' + OS + '-';
  end;
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
begin
  ClearLog;

  // If target already has a configured path, verify it directly
  if ATarget.BinutilsPath <> '' then
  begin
    if CheckTool(ATarget.BinutilsPath, ATarget.BinutilsPrefix, TOOL_AS) then
    begin
      Result.Found := True;
      Result.BinutilsPath := ATarget.BinutilsPath;
      Result.BinutilsPrefix := ATarget.BinutilsPrefix;
      Result.Layer := 0;
      Result.LayerName := 'configured';
      AddLog(0, 'configured', ATarget.BinutilsPath, ATarget.BinutilsPrefix, True);
      Exit;
    end;
    AddLog(0, 'configured', ATarget.BinutilsPath, ATarget.BinutilsPrefix, False);
  end;

  // Layer 1: fpdev-managed
  Result := SearchLayer1_FPDevManaged(ATarget);
  if Result.Found then Exit;

  // Layer 2: System paths
  Result := SearchLayer2_SystemPaths(ATarget);
  if Result.Found then Exit;

  // Layer 3: PATH environment
  Result := SearchLayer3_EnvPath(ATarget);
  if Result.Found then Exit;

  // Layer 4: Platform-specific
  Result := SearchLayer4_PlatformSpecific(ATarget);
  if Result.Found then Exit;

  // Layer 5: Linker-based discovery
  Result := SearchLayer5_LinkerDiscovery(ATarget);
  if Result.Found then Exit;

  // Layer 6: Config file hints
  Result := SearchLayer6_ConfigHints(ATarget, AFpcCfgPath);
end;

function TCrossToolchainSearch.SearchLibraries(const ATarget: TCrossTarget): TStringArray;
var
  Candidates: array of string;
  CandCount: Integer;
  I: Integer;
  Prefix: string;
  Prefixes: TStringArray;

  procedure AddCandidate(const ADir: string);
  var
    J: Integer;
  begin
    if (ADir = '') or not DirectoryExists(ADir) then Exit;
    // Deduplicate
    for J := 0 to CandCount - 1 do
      if Candidates[J] = ADir then Exit;
    if CandCount >= Length(Candidates) then
      SetLength(Candidates, Length(Candidates) + 8);
    Candidates[CandCount] := ADir;
    Inc(CandCount);
  end;

begin
  Result := nil;
  Candidates := nil;
  SetLength(Candidates, 16);
  CandCount := 0;

  Prefixes := GetPrefixCandidates(ATarget);

  // Priority 0: Configured library path
  if ATarget.LibrariesPath <> '' then
    AddCandidate(ATarget.LibrariesPath);

  // Priority 1: fpdev-managed
  AddCandidate(GetDataRoot + PathDelim + 'cross' + PathDelim +
    ATarget.CPU + '-' + ATarget.OS + PathDelim + 'lib');

  {$IFDEF LINUX}
  // Priority 2: Debian/Ubuntu multiarch — /usr/<triple>/lib
  for I := 0 to High(Prefixes) do
  begin
    Prefix := Copy(Prefixes[I], 1, Length(Prefixes[I]) - 1);
    AddCandidate('/usr/' + Prefix + '/lib');
    // multiarch variant: /usr/lib/<triple>
    AddCandidate('/usr/lib/' + Prefix);
    // 32/64 multilib: /usr/<triple>/lib32, /usr/<triple>/lib64
    AddCandidate('/usr/' + Prefix + '/lib32');
    AddCandidate('/usr/' + Prefix + '/lib64');
  end;

  // Priority 3: Generic cross paths
  AddCandidate('/usr/' + ATarget.CPU + '-' + ATarget.OS + '/lib');

  // Priority 4: NDK sysroot for Android
  if ATarget.OS = 'android' then
  begin
    AddCandidate(GetEnvironmentVariable('ANDROID_NDK_HOME') +
      '/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/' +
      ATarget.CPU + '-linux-android');
    AddCandidate(GetUserDir + 'Android/Sdk/ndk-bundle/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/' +
      ATarget.CPU + '-linux-android');
  end;

  // Priority 5: Linaro / ARM-specific
  if (ATarget.CPU = 'arm') or (ATarget.CPU = 'aarch64') then
  begin
    AddCandidate('/opt/gcc-arm/lib');
    AddCandidate('/opt/gcc-linaro/lib');
  end;

  // Priority 6: Windows cross-lib (mingw sysroot)
  if (ATarget.OS = 'win64') or (ATarget.OS = 'win32') then
  begin
    for I := 0 to High(Prefixes) do
    begin
      Prefix := Copy(Prefixes[I], 1, Length(Prefixes[I]) - 1);
      AddCandidate('/usr/' + Prefix + '/lib');
    end;
  end;
  {$ENDIF}

  {$IFDEF DARWIN}
  // macOS SDK
  AddCandidate('/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib');
  // Homebrew cross-compilation
  AddCandidate('/opt/homebrew/opt/' + ATarget.CPU + '-' + ATarget.OS + '/lib');
  {$ENDIF}

  {$IFDEF MSWINDOWS}
  // MSYS2 cross-lib directories
  if (ATarget.OS = 'linux') or (ATarget.OS = 'darwin') then
  begin
    AddCandidate('C:\msys64\usr\lib');
  end;
  {$ENDIF}

  // Build result array
  SetLength(Result, CandCount);
  for I := 0 to CandCount - 1 do
    Result[I] := Candidates[I];
end;

function TCrossToolchainSearch.DiagnoseTarget(const ATarget: TCrossTarget): TStringArray;
var
  BinRes: TCrossSearchResult;
  Libs, Log: TStringArray;
  Lines: array of string;
  LineCount: Integer;
  I: Integer;

  procedure AddLine(const ALine: string);
  begin
    if LineCount >= Length(Lines) then
      SetLength(Lines, Length(Lines) + 16);
    Lines[LineCount] := ALine;
    Inc(LineCount);
  end;

begin
  Result := nil;
  Lines := nil;
  SetLength(Lines, 16);
  LineCount := 0;

  AddLine('Target: ' + ATarget.CPU + '-' + ATarget.OS);

  // Search binutils
  BinRes := SearchBinutils(ATarget);
  if BinRes.Found then
  begin
    AddLine('[OK] Binutils found (layer ' + IntToStr(BinRes.Layer) + ': ' + BinRes.LayerName + ')');
    AddLine('     Path: ' + BinRes.BinutilsPath);
    if BinRes.BinutilsPrefix <> '' then
      AddLine('     Prefix: ' + BinRes.BinutilsPrefix);
  end
  else
    AddLine('[X] Binutils not found');

  // Search libraries
  Libs := SearchLibraries(ATarget);
  if Length(Libs) > 0 then
  begin
    AddLine('[OK] Libraries found (' + IntToStr(Length(Libs)) + ' path(s))');
    for I := 0 to High(Libs) do
      AddLine('     ' + Libs[I]);
  end
  else
    AddLine('[!] No library paths found');

  // Search log summary
  AddLine('Search log (' + IntToStr(GetSearchLogCount) + ' entries):');
  Log := GetSearchLog;
  for I := 0 to High(Log) do
    AddLine('  ' + Log[I]);

  SetLength(Result, LineCount);
  for I := 0 to LineCount - 1 do
    Result[I] := Lines[I];
end;

function TCrossToolchainSearch.GetSearchLog: TStringArray;
var
  I: Integer;
  StatusStr: string;
begin
  Result := nil;
  SetLength(Result, FLogCount);
  for I := 0 to FLogCount - 1 do
  begin
    if FLog[I].Found then
      StatusStr := 'FOUND'
    else
      StatusStr := 'miss';
    Result[I] := Format('[L%d:%s] %s prefix=%s => %s',
      [FLog[I].Layer, FLog[I].LayerName, FLog[I].Path,
       FLog[I].Prefix, StatusStr]);
  end;
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
