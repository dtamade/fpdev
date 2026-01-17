unit fpdev.platform;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils;

type
  { Platform operating system types }
  TPlatformOS = (posUnknown, posWindows, posLinux, posDarwin, posFreeBSD);

  { Platform CPU architecture types }
  TPlatformCPU = (pcUnknown, pcX86_64, pcI386, pcAArch64, pcARM);

  { Platform information record }
  TPlatformInfo = record
    OS: TPlatformOS;
    CPU: TPlatformCPU;
    function ToString: string;
    function IsValid: Boolean;
  end;

{ Detect current platform }
function DetectPlatform: TPlatformInfo;

{ Convert platform to string (e.g., "linux-x86_64") }
function PlatformToString(const AInfo: TPlatformInfo): string;

{ Parse platform string to TPlatformInfo }
function StringToPlatform(const AStr: string): TPlatformInfo;

implementation

{ TPlatformInfo }

function TPlatformInfo.ToString: string;
begin
  Result := PlatformToString(Self);
end;

function TPlatformInfo.IsValid: Boolean;
begin
  Result := (OS <> posUnknown) and (CPU <> pcUnknown);
end;

{ Platform detection }

function DetectPlatform: TPlatformInfo;
begin
  Result.OS := posUnknown;
  Result.CPU := pcUnknown;

  // Detect OS
  {$IFDEF WINDOWS}
  Result.OS := posWindows;
  {$ENDIF}
  {$IFDEF LINUX}
  Result.OS := posLinux;
  {$ENDIF}
  {$IFDEF DARWIN}
  Result.OS := posDarwin;
  {$ENDIF}
  {$IFDEF FREEBSD}
  Result.OS := posFreeBSD;
  {$ENDIF}

  // Detect CPU
  {$IFDEF CPUX86_64}
  Result.CPU := pcX86_64;
  {$ENDIF}
  {$IFDEF CPUI386}
  Result.CPU := pcI386;
  {$ENDIF}
  {$IFDEF CPUAARCH64}
  Result.CPU := pcAArch64;
  {$ENDIF}
  {$IFDEF CPUARM}
  Result.CPU := pcARM;
  {$ENDIF}
end;

function PlatformToString(const AInfo: TPlatformInfo): string;
var
  OSStr, CPUStr: string;
begin
  // Convert OS to string
  case AInfo.OS of
    posWindows: OSStr := 'windows';
    posLinux: OSStr := 'linux';
    posDarwin: OSStr := 'darwin';
    posFreeBSD: OSStr := 'freebsd';
    else OSStr := 'unknown';
  end;

  // Convert CPU to string
  case AInfo.CPU of
    pcX86_64: CPUStr := 'x86_64';
    pcI386: CPUStr := 'i386';
    pcAArch64: CPUStr := 'aarch64';
    pcARM: CPUStr := 'arm';
    else CPUStr := 'unknown';
  end;

  Result := OSStr + '-' + CPUStr;
end;

function StringToPlatform(const AStr: string): TPlatformInfo;
var
  Parts: TStringList;
  OSStr, CPUStr: string;
begin
  Result.OS := posUnknown;
  Result.CPU := pcUnknown;

  Parts := TStringList.Create;
  try
    Parts.Delimiter := '-';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := AStr;

    if Parts.Count <> 2 then
      Exit;

    OSStr := LowerCase(Parts[0]);
    CPUStr := LowerCase(Parts[1]);

    // Parse OS
    if OSStr = 'windows' then Result.OS := posWindows
    else if OSStr = 'linux' then Result.OS := posLinux
    else if OSStr = 'darwin' then Result.OS := posDarwin
    else if OSStr = 'freebsd' then Result.OS := posFreeBSD;

    // Parse CPU
    if CPUStr = 'x86_64' then Result.CPU := pcX86_64
    else if CPUStr = 'i386' then Result.CPU := pcI386
    else if CPUStr = 'aarch64' then Result.CPU := pcAArch64
    else if CPUStr = 'arm' then Result.CPU := pcARM;
  finally
    Parts.Free;
  end;
end;

end.
