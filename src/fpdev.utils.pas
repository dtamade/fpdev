unit fpdev.utils;

{$mode objfpc}{$H+}

{$I fpdev.settings.inc}

interface

uses
  SysUtils, Classes, fpdev.constants
  {$IFDEF UNIX}
  , BaseUnix
  , ctypes
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  , Windows
  {$ENDIF}
  ;

type
  env_item = record
    name: string;
    value: string;
  end;
  env_item_array = array of env_item;

  env_item_ptr = ^env_item;
  ppasswd_t = ^passwd_t;
  putsname_t = ^utsname_t;

  passwd_t = record
    pw_name: PChar;
    pw_passwd: PChar;
    pw_uid: LongWord;
    pw_gid: LongWord;
    pw_gecos: PChar;
    pw_dir: PChar;
    pw_shell: PChar;
  end;

  utsname_t = record
    sysname: array[0..255] of Char;
    nodename: array[0..255] of Char;
    release: array[0..255] of Char;
    version: array[0..255] of Char;
    machine: array[0..255] of Char;
  end;

  pid_t = LongWord;
  clock_id = LongInt;

  timeval64_t = record
    tv_sec: Int64;
    tv_usec: Int64;
  end;
  ptimeval64_t = ^timeval64_t;

  timespec64_t = record
    tv_sec: Int64;
    tv_nsec: Int64;
  end;
  ptimespec64_t = ^timespec64_t;

  cpu_info = record
    model: string;
    speed: UInt64;
    count: UInt32;
  end;
  cpu_info_array = array of cpu_info;

  rusage_t = record
    ru_utime: timeval64_t;
    ru_stime: timeval64_t;
  end;
  prusage_t = ^rusage_t;

// Essential functions - only these are actually implemented
function cwd: string;
function chdir(const aDir: string): Boolean;
function get_home_dir: String;
function get_tmp_dir: String;
function get_env(const aName: string): String; overload;
function get_env(const aName: string; out aValue: string): Boolean; overload;
function set_env(const aName, aValue: string): Boolean;
function unset_env(const aName: string): Boolean;

// Basic functions
function exepath: string;
function get_pid: pid_t;
function get_ppid: pid_t;

// System information functions
function uname(var system_info: utsname_t): LongInt;
function get_hostname: string;
function get_cpu_count: UInt32;
function hrtime: UInt64;
function uptime: Integer;
function get_free_memory: UInt64;
function get_total_memory: UInt64;
function available_parallelism: UInt32;

// File I/O utilities
procedure SafeWriteAllText(const AFileName, AContent: string);
function ReadAllTextIfExists(const AFileName: string): string;

// String utilities
function JsonEscape(const S: string): string;

// Version utilities
function ParseVersionString(const S: string; out Major, Minor, Patch: Integer): Boolean;
function CompareVersions(const V1, V2: string): Integer;  // Returns: -1 if V1<V2, 0 if equal, 1 if V1>V2
function IsVersionHigher(const V1, V2: string): Boolean;  // Returns True if V1 > V2

implementation

{$IFDEF UNIX}
function c_setenv(name, value: PChar; overwrite: cint): cint; cdecl; external 'c' name 'setenv';
function c_unsetenv(name: PChar): cint; cdecl; external 'c' name 'unsetenv';
function c_getenv(name: PChar): PChar; cdecl; external 'c' name 'getenv';
var
  environ: PPAnsiChar; cvar; external;

procedure SyncUnixEnvSnapshot;
begin
  if environ <> nil then
    envp := environ;
end;
{$ENDIF}

// Essential implementations
function cwd: string;
begin
  Result := GetCurrentDir();
end;

function chdir(const aDir: string): Boolean;
begin
  Result := SetCurrentDir(aDir);
end;

function get_home_dir: String;
begin
  Result := GetUserDir;
end;

function get_tmp_dir: String;
begin
  Result := GetTempDir;
end;

function get_env(const aName: string): String;
{$IFDEF UNIX}
var
  P: PChar;
{$ENDIF}
begin
  {$IFDEF UNIX}
  // Use C library getenv for consistency with setenv
  P := c_getenv(PChar(aName));
  if P <> nil then
    Result := StrPas(P)
  else
    Result := '';
  {$ELSE}
  Result := SysUtils.GetEnvironmentVariable(aName);
  {$ENDIF}
end;

function get_env(const aName: string; out aValue: string): Boolean;
{$IFDEF UNIX}
var
  P: PChar;
{$ENDIF}
begin
  {$IFDEF UNIX}
  // Use C library getenv for consistency with setenv
  P := c_getenv(PChar(aName));
  if P <> nil then
  begin
    aValue := StrPas(P);
    Result := True;
  end
  else
  begin
    aValue := '';
    Result := False;
  end;
  {$ELSE}
  aValue := SysUtils.GetEnvironmentVariable(aName);
  Result := aValue <> '';
  {$ENDIF}
end;

function unset_env(const aName: string): Boolean;
begin
  {$IFDEF UNIX}
  Result := c_unsetenv(PChar(aName)) = 0;
  if Result then
    SyncUnixEnvSnapshot;
  {$ELSE}
    {$IFDEF MSWINDOWS}
  Result := SetEnvironmentVariableW(PWideChar(UTF8Decode(aName)), nil);
    {$ELSE}
  Result := False;
    {$ENDIF}
  {$ENDIF}
end;

function set_env(const aName, aValue: string): Boolean;
begin
  {$IFDEF UNIX}
  if aValue = '' then
    Result := c_unsetenv(PChar(aName)) = 0
  else
    Result := c_setenv(PChar(aName), PChar(aValue), 1) = 0;
  if Result then
    SyncUnixEnvSnapshot;
  {$ELSE}
    {$IFDEF MSWINDOWS}
  if aValue = '' then
    Result := SetEnvironmentVariableW(PWideChar(UTF8Decode(aName)), nil)
  else
    Result := SetEnvironmentVariableW(PWideChar(UTF8Decode(aName)), PWideChar(UTF8Decode(aValue)));
    {$ELSE}
  Result := False;
    {$ENDIF}
  {$ENDIF}
end;

function exepath: string;
begin
  Result := ParamStr(0);
end;

function get_pid: pid_t;
begin
  Result := GetProcessID;
end;

function get_ppid: pid_t;
begin
  {$IFDEF UNIX}
  Result := fpgetppid;
  {$ELSE}
  Result := 0; // Not available on Windows
  {$ENDIF}
end;

function get_hostname: string;
begin
  {$IFDEF UNIX}
  Result := GetEnvironmentVariable('HOSTNAME');
  if Result = '' then
    Result := GetEnvironmentVariable('HOST');
  if Result = '' then
    Result := 'localhost';
  {$ELSE}
  Result := SysUtils.GetEnvironmentVariable('COMPUTERNAME');
  if Result = '' then
    Result := 'localhost';
  {$ENDIF}
end;

function get_cpu_count: UInt32;
begin
  Result := GetCPUCount;
end;

function hrtime: UInt64;
begin
  // Return high-resolution time in nanoseconds
  Result := GetTickCount64 * 1000000; // Convert milliseconds to nanoseconds
end;

function uptime: Integer;
{$IFDEF UNIX}
var
  F: TextFile;
  Line: string;
  UptimeSeconds: Double;
  Code: Integer;
{$ENDIF}
begin
  {$IFDEF UNIX}
  // Read from /proc/uptime on Linux
  Result := 0;
  if FileExists(PROC_UPTIME_FILE) then
  begin
    try
      AssignFile(F, PROC_UPTIME_FILE);
      Reset(F);
      ReadLn(F, Line);
      CloseFile(F);
      // First value is uptime in seconds
      Val(Copy(Line, 1, Pos(' ', Line) - 1), UptimeSeconds, Code);
      if Code = 0 then
        Result := Trunc(UptimeSeconds);
    except
      Result := 0;
    end;
  end;
  {$ELSE}
  // Windows: return uptime in seconds based on GetTickCount64
  Result := GetTickCount64 div 1000;
  {$ENDIF}
end;

function get_free_memory: UInt64;
{$IFDEF UNIX}
var
  F: TextFile;
  Line: string;
  Parts: TStringList;
  MemFree: Int64;
  Code: Integer;
{$ENDIF}
{$IFDEF MSWINDOWS}
var
  MemStatus: TMemoryStatusEx;
{$ENDIF}
begin
  Result := 0;
  {$IFDEF UNIX}
  // Read from /proc/meminfo on Linux
  if FileExists(PROC_MEMINFO_FILE) then
  begin
    try
      AssignFile(F, PROC_MEMINFO_FILE);
      Reset(F);
      Parts := TStringList.Create;
      try
        while not Eof(F) do
        begin
          ReadLn(F, Line);
          if Pos('MemAvailable:', Line) = 1 then
          begin
            // MemAvailable: 12345678 kB
            Delete(Line, 1, 13); // Remove "MemAvailable:"
            Line := Trim(Line);
            // Remove " kB" suffix
            if Pos(' kB', Line) > 0 then
              Delete(Line, Pos(' kB', Line), 3);
            Val(Line, MemFree, Code);
            if Code = 0 then
              Result := MemFree * 1024; // Convert kB to bytes
            Break;
          end;
        end;
      finally
        Parts.Free;
      end;
      CloseFile(F);
    except
      Result := 0;
    end;
  end;
  {$ELSE}
    {$IFDEF MSWINDOWS}
  MemStatus.dwLength := SizeOf(MemStatus);
  if GlobalMemoryStatusEx(MemStatus) then
    Result := MemStatus.ullAvailPhys
  else
    Result := 0;
    {$ELSE}
  Result := 0;
    {$ENDIF}
  {$ENDIF}
end;

function get_total_memory: UInt64;
{$IFDEF UNIX}
var
  F: TextFile;
  Line: string;
  MemTotal: Int64;
  Code: Integer;
{$ENDIF}
{$IFDEF MSWINDOWS}
var
  MemStatus: TMemoryStatusEx;
{$ENDIF}
begin
  Result := 0;
  {$IFDEF UNIX}
  // Read from /proc/meminfo on Linux
  if FileExists(PROC_MEMINFO_FILE) then
  begin
    try
      AssignFile(F, PROC_MEMINFO_FILE);
      Reset(F);
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        if Pos('MemTotal:', Line) = 1 then
        begin
          // MemTotal: 12345678 kB
          Delete(Line, 1, 9); // Remove "MemTotal:"
          Line := Trim(Line);
          // Remove " kB" suffix
          if Pos(' kB', Line) > 0 then
            Delete(Line, Pos(' kB', Line), 3);
          Val(Line, MemTotal, Code);
          if Code = 0 then
            Result := MemTotal * 1024; // Convert kB to bytes
          Break;
        end;
      end;
      CloseFile(F);
    except
      Result := 0;
    end;
  end;
  {$ELSE}
    {$IFDEF MSWINDOWS}
  MemStatus.dwLength := SizeOf(MemStatus);
  if GlobalMemoryStatusEx(MemStatus) then
    Result := MemStatus.ullTotalPhys
  else
    Result := 0;
    {$ELSE}
  Result := 0;
    {$ENDIF}
  {$ENDIF}
end;

function available_parallelism: UInt32;
begin
  // Return the number of logical CPU cores available for parallel execution
  Result := GetCPUCount;
end;

procedure SafeWriteAllText(const AFileName, AContent: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Text := AContent;
    SL.SaveToFile(AFileName);
  finally
    SL.Free;
  end;
end;

function ReadAllTextIfExists(const AFileName: string): string;
var
  SL: TStringList;
begin
  Result := '';
  if not FileExists(AFileName) then Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(AFileName);
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

function JsonEscape(const S: string): string;
var
  i: Integer;
  ch: Char;
  LRes: string;
begin
  LRes := '';
  for i := 1 to Length(S) do
  begin
    ch := S[i];
    case ch of
      '"': LRes := LRes + '\"';
      #92:  LRes := LRes + '\\';
      #8: LRes := LRes + '\b';
      #9: LRes := LRes + '\t';
      #10: LRes := LRes + '\n';
      #12: LRes := LRes + '\f';
      #13: LRes := LRes + '\r';
    else
      if Ord(ch) < 32 then
        LRes := LRes + '\u' + IntToHex(Ord(ch), 4)
      else
        LRes := LRes + ch;
    end;
  end;
  Result := LRes;
end;

function ParseVersionString(const S: string; out Major, Minor, Patch: Integer): Boolean;
var
  Parts: array of string;
  i, Code: Integer;
  Start: Integer;
  PartCount: Integer;
begin
  Major := 0;
  Minor := 0;
  Patch := 0;
  Result := False;
  if S = '' then Exit;

  // Split by '.'
  Parts := nil;
  SetLength(Parts, 0);
  Start := 1;
  for i := 1 to Length(S) do
  begin
    if S[i] = '.' then
    begin
      SetLength(Parts, Length(Parts) + 1);
      Parts[High(Parts)] := Copy(S, Start, i - Start);
      Start := i + 1;
    end;
  end;
  // Add last part
  SetLength(Parts, Length(Parts) + 1);
  Parts[High(Parts)] := Copy(S, Start, Length(S) - Start + 1);

  PartCount := Length(Parts);
  if PartCount >= 1 then
  begin
    Val(Parts[0], Major, Code);
    if Code <> 0 then Major := 0;
  end;
  if PartCount >= 2 then
  begin
    Val(Parts[1], Minor, Code);
    if Code <> 0 then Minor := 0;
  end;
  if PartCount >= 3 then
  begin
    Val(Parts[2], Patch, Code);
    if Code <> 0 then Patch := 0;
  end;
  Result := True;
end;

function CompareVersions(const V1, V2: string): Integer;
var
  M1, N1, P1, M2, N2, P2: Integer;
begin
  ParseVersionString(V1, M1, N1, P1);
  ParseVersionString(V2, M2, N2, P2);

  if M1 < M2 then Exit(-1);
  if M1 > M2 then Exit(1);
  if N1 < N2 then Exit(-1);
  if N1 > N2 then Exit(1);
  if P1 < P2 then Exit(-1);
  if P1 > P2 then Exit(1);
  Result := 0;
end;

function IsVersionHigher(const V1, V2: string): Boolean;
begin
  Result := CompareVersions(V1, V2) > 0;
end;

// Uname system call - get system information
{$IFDEF UNIX}
function uname(var system_info: utsname_t): LongInt;
var
  U: BaseUnix.UTSName;
begin
  FillChar(system_info, SizeOf(system_info), 0);
  U := Default(BaseUnix.UTSName);
  Result := fpUname(U);
  if Result = 0 then
  begin
    StrPLCopy(@system_info.sysname[0], StrPas(@U.sysname[0]), High(system_info.sysname));
    StrPLCopy(@system_info.nodename[0], StrPas(@U.nodename[0]), High(system_info.nodename));
    StrPLCopy(@system_info.release[0], StrPas(@U.release[0]), High(system_info.release));
    StrPLCopy(@system_info.version[0], StrPas(@U.version[0]), High(system_info.version));
    StrPLCopy(@system_info.machine[0], StrPas(@U.machine[0]), High(system_info.machine));
  end;
end;
{$ENDIF}

{$IFNDEF UNIX}
function uname(var system_info: utsname_t): LongInt;
begin
  // Windows compatibility: provide uname-like info on non-Unix platforms
  FillChar(system_info, SizeOf(system_info), 0);
  StrPCopy(system_info.sysname, 'Windows');
  StrPCopy(system_info.machine, 'x86');
  Result := 0;
end;
{$ENDIF}

end.
