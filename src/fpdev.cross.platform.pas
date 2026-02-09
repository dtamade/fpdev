unit fpdev.cross.platform;

{
  Cross-compilation platform utilities

  Provides platform enum, string conversion, system detection,
  and package manager instructions for cross-compilation toolchains.
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  { TCrossTargetPlatform - Supported cross-compilation target platforms }
  TCrossTargetPlatform = (
    ctpWin32, ctpWin64, ctpLinux32, ctpLinux64, ctpLinuxARM, ctpLinuxARM64,
    ctpDarwin32, ctpDarwin64, ctpDarwinARM64, ctpAndroid, ctpiOS,
    ctpFreeBSD32, ctpFreeBSD64, ctpCustom
  );

{ Convert platform enum to string }
function PlatformToString(APlatform: TCrossTargetPlatform): string;

{ Convert string to platform enum }
function StringToPlatform(const AStr: string): TCrossTargetPlatform;

{ Get binutils prefix for target platform }
function GetBinutilsPrefix(APlatform: TCrossTargetPlatform): string;

{ Detect system cross compiler for target, returns binutils path if found }
function DetectSystemCrossCompiler(const ATarget: string; out ABinutilsPath: string): Boolean;

{ Get package manager installation instructions for target }
function GetPackageManagerInstructions(const ATarget: string): string;

implementation

function PlatformToString(APlatform: TCrossTargetPlatform): string;
begin
  case APlatform of
    ctpWin32: Result := 'win32';
    ctpWin64: Result := 'win64';
    ctpLinux32: Result := 'linux32';
    ctpLinux64: Result := 'linux64';
    ctpLinuxARM: Result := 'linuxarm';
    ctpLinuxARM64: Result := 'linuxarm64';
    ctpDarwin32: Result := 'darwin32';
    ctpDarwin64: Result := 'darwin64';
    ctpDarwinARM64: Result := 'darwinarm64';
    ctpAndroid: Result := 'android';
    ctpiOS: Result := 'ios';
    ctpFreeBSD32: Result := 'freebsd32';
    ctpFreeBSD64: Result := 'freebsd64';
    ctpCustom: Result := 'custom';
  end;
end;

function StringToPlatform(const AStr: string): TCrossTargetPlatform;
begin
  if SameText(AStr, 'win32') then Result := ctpWin32
  else if SameText(AStr, 'win64') then Result := ctpWin64
  else if SameText(AStr, 'linux32') then Result := ctpLinux32
  else if SameText(AStr, 'linux64') then Result := ctpLinux64
  else if SameText(AStr, 'linuxarm') then Result := ctpLinuxARM
  else if SameText(AStr, 'linuxarm64') then Result := ctpLinuxARM64
  else if SameText(AStr, 'darwin32') then Result := ctpDarwin32
  else if SameText(AStr, 'darwin64') then Result := ctpDarwin64
  else if SameText(AStr, 'darwinarm64') then Result := ctpDarwinARM64
  else if SameText(AStr, 'android') then Result := ctpAndroid
  else if SameText(AStr, 'ios') then Result := ctpiOS
  else if SameText(AStr, 'freebsd32') then Result := ctpFreeBSD32
  else if SameText(AStr, 'freebsd64') then Result := ctpFreeBSD64
  else Result := ctpCustom;
end;

function GetBinutilsPrefix(APlatform: TCrossTargetPlatform): string;
begin
  case APlatform of
    ctpWin32: Result := 'i686-w64-mingw32-';
    ctpWin64: Result := 'x86_64-w64-mingw32-';
    ctpLinux32: Result := 'i686-linux-gnu-';
    ctpLinux64: Result := 'x86_64-linux-gnu-';
    ctpLinuxARM: Result := 'arm-linux-gnueabihf-';
    ctpLinuxARM64: Result := 'aarch64-linux-gnu-';
    ctpDarwin64: Result := 'x86_64-apple-darwin-';
    ctpDarwinARM64: Result := 'aarch64-apple-darwin-';
    ctpAndroid: Result := 'arm-linux-androideabi-';
  else
    Result := '';
  end;
end;

function DetectSystemCrossCompiler(const ATarget: string; out ABinutilsPath: string): Boolean;
var
  SearchPaths: array of string;
  Prefix, GCCExe: string;
  i: Integer;
begin
  Result := False;
  ABinutilsPath := '';

  // Get binutils prefix for target
  Prefix := GetBinutilsPrefix(StringToPlatform(ATarget));
  if Prefix = '' then
    Exit;

  // Search paths for cross compilers
  SearchPaths := nil;
  {$IFDEF UNIX}
  SetLength(SearchPaths, 4);
  SearchPaths[0] := '/usr/bin';
  SearchPaths[1] := '/usr/local/bin';
  SearchPaths[2] := '/opt/cross/bin';
  SearchPaths[3] := ExpandFileName('~/.local/bin');
  {$ELSE}
  SetLength(SearchPaths, 3);
  SearchPaths[0] := 'C:' + PathDelim + 'mingw64' + PathDelim + 'bin';
  SearchPaths[1] := 'C:' + PathDelim + 'mingw32' + PathDelim + 'bin';
  SearchPaths[2] := GetEnvironmentVariable('MINGW_HOME') + PathDelim + 'bin';
  {$ENDIF}

  // Search for GCC with the target prefix
  for i := 0 to High(SearchPaths) do
  begin
    GCCExe := SearchPaths[i] + PathDelim + Prefix + 'gcc';
    {$IFDEF MSWINDOWS}
    GCCExe := GCCExe + '.exe';
    {$ENDIF}

    if FileExists(GCCExe) then
    begin
      ABinutilsPath := SearchPaths[i];
      Result := True;
      Exit;
    end;
  end;
end;

function GetPackageManagerInstructions(const ATarget: string): string;
var
  Platform: TCrossTargetPlatform;
begin
  Result := '';
  Platform := StringToPlatform(ATarget);

  {$IFDEF LINUX}
  case Platform of
    ctpWin32, ctpWin64:
      Result := 'Install MinGW cross compiler:' + LineEnding +
                '  Debian/Ubuntu: sudo apt-get install gcc-mingw-w64' + LineEnding +
                '  Fedora/RHEL:   sudo dnf install mingw64-gcc mingw32-gcc' + LineEnding +
                '  Arch Linux:    sudo pacman -S mingw-w64-gcc';
    ctpLinuxARM:
      Result := 'Install ARM cross compiler:' + LineEnding +
                '  Debian/Ubuntu: sudo apt-get install gcc-arm-linux-gnueabihf' + LineEnding +
                '  Fedora/RHEL:   sudo dnf install arm-linux-gnueabihf-gcc' + LineEnding +
                '  Arch Linux:    sudo pacman -S arm-linux-gnueabihf-gcc';
    ctpLinuxARM64:
      Result := 'Install AArch64 cross compiler:' + LineEnding +
                '  Debian/Ubuntu: sudo apt-get install gcc-aarch64-linux-gnu' + LineEnding +
                '  Fedora/RHEL:   sudo dnf install aarch64-linux-gnu-gcc' + LineEnding +
                '  Arch Linux:    sudo pacman -S aarch64-linux-gnu-gcc';
  else
    Result := 'Cross compiler not available via package manager.' + LineEnding +
              'Please install manually and use "fpdev cross configure".';
  end;
  {$ENDIF}

  {$IFDEF DARWIN}
  case Platform of
    ctpWin32, ctpWin64:
      Result := 'Install MinGW cross compiler:' + LineEnding +
                '  Homebrew: brew install mingw-w64';
    ctpLinuxARM, ctpLinuxARM64:
      Result := 'Install ARM cross compiler:' + LineEnding +
                '  Homebrew: brew install arm-linux-gnueabihf-binutils';
  else
    Result := 'Cross compiler not available via Homebrew.' + LineEnding +
              'Please install manually and use "fpdev cross configure".';
  end;
  {$ENDIF}

  {$IFDEF MSWINDOWS}
  case Platform of
    ctpLinux32, ctpLinux64, ctpLinuxARM, ctpLinuxARM64:
      Result := 'Install cross compiler from:' + LineEnding +
                '  https://gnutoolchains.com/raspberry/' + LineEnding +
                '  Or use WSL for Linux cross-compilation.';
  else
    Result := 'Cross compiler not readily available.' + LineEnding +
              'Please install manually and use "fpdev cross configure".';
  end;
  {$ENDIF}

  if Result = '' then
    Result := 'Please install the cross compiler manually and use "fpdev cross configure".';
end;

end.
