uses
  windows;

const
  MAX_PATH      = {$IFDEF FPDEV_LONG_PATH}32768{$ELSE}260{$ENDIF};
  SIZE_WIDECHAR = SizeOf(WideChar);

  KERNEL32      = 'kernel32.dll';
  NTDLL         = 'ntdll.dll';
  PSAPILIB      = 'psapi.dll';
  USERENVLIB    = 'userenv.dll';
  WS2_32LIB     = 'ws2_32.dll';

  PROCESSBASICINFORMATION = 0;
  SYSTEMPROCESSORPERFORMANCEINFORMATION = 8;

  PROCESSOR_ARCHITECTURE_INTEL          = 0;
  PROCESSOR_ARCHITECTURE_MIPS           = 1;
  PROCESSOR_ARCHITECTURE_ALPHA          = 2;
  PROCESSOR_ARCHITECTURE_PPC            = 3;
  PROCESSOR_ARCHITECTURE_SHX            = 4;
  PROCESSOR_ARCHITECTURE_ARM            = 5;
  PROCESSOR_ARCHITECTURE_IA64           = 6;
  PROCESSOR_ARCHITECTURE_ALPHA64        = 7;
 // PROCESSOR_ARCHITECTURE_MSIL           = 8;
  PROCESSOR_ARCHITECTURE_AMD64          = 9;
  PROCESSOR_ARCHITECTURE_IA32_ON_WIN64  = 10;
 // PROCESSOR_ARCHITECTURE_NEUTRAL        = 11;
 // PROCESSOR_ARCHITECTURE_ARM64          = 12;
 // PROCESSOR_ARCHITECTURE_ARM32_ON_WIN64 = 13;
 // PROCESSOR_ARCHITECTURE_IA32_ON_ARM64  = 14;

type

  NTSTATUS  = Long;
  //PNTSTATUS = ^NTSTATUS;

  MEMORYSTATUSEX = record
    dwLength:                DWORD;
    dwMemoryLoad:            DWORD;
    ullTotalPhys:            uint64;
    ullAvailPhys:            uint64;
    ullTotalPageFile:        uint64;
    ullAvailPageFile:        uint64;
    ullTotalVirtual:         uint64;
    ullAvailVirtual:         uint64;
    ullAvailExtendedVirtual: uint64;
  end;
  PMemoryStatusEx = ^MEMORYSTATUSEX;

  PROCESS_BASIC_INFORMATION = record
    Reserved1:                    Pointer;
    PebBaseAddress:               Pointer;
    Reserved2:                    array [0..1] of Pointer;
    UniqueProcessId:              ULONG_PTR;
    InheritedFromUniqueProcessId: ULONG_PTR;
  end;
  //PPROCESS_BASIC_INFORMATION = ^PROCESS_BASIC_INFORMATION;

  PPROCESS_MEMORY_COUNTERS = ^PROCESS_MEMORY_COUNTERS;
  PROCESS_MEMORY_COUNTERS = record
    cb: DWORD;
    PageFaultCount: DWORD;
    PeakWorkingSetSize: SIZE_T;
    WorkingSetSize: SIZE_T;
    QuotaPeakPagedPoolUsage: SIZE_T;
    QuotaPagedPoolUsage: SIZE_T;
    QuotaPeakNonPagedPoolUsage: SIZE_T;
    QuotaNonPagedPoolUsage: SIZE_T;
    PagefileUsage: SIZE_T;
    PeakPagefileUsage: SIZE_T;
  end;

  // PROCESS_MEMORY_COUNTERS_EX = record
  //   cb: DWORD;
  //   PageFaultCount: DWORD;
  //   PeakWorkingSetSize: SIZE_T;
  //   WorkingSetSize: SIZE_T;
  //   QuotaPeakPagedPoolUsage: SIZE_T;
  //   QuotaPagedPoolUsage: SIZE_T;
  //   QuotaPeakNonPagedPoolUsage: SIZE_T;
  //   QuotaNonPagedPoolUsage: SIZE_T;
  //   PagefileUsage: SIZE_T;
  //   PeakPagefileUsage: SIZE_T;
  //   PrivateUsage: SIZE_T;
  // end;
  //PPROCESS_MEMORY_COUNTERS_EX = ^PROCESS_MEMORY_COUNTERS_EX;

  SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION = record
    IdleTime:       LARGE_INTEGER;
    KernelTime:     LARGE_INTEGER;
    UserTime:       LARGE_INTEGER;
    DpcTime:        LARGE_INTEGER;
    InterruptTime:  LARGE_INTEGER;
    InterruptCount: ULONG;
  end;
  PSYSTEM_PROCESSOR_PERFORMANCE_INFORMATION = ^SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION;

  PIO_COUNTERS = ^IO_COUNTERS;
  IO_COUNTERS = record
    ReadOperationCount:  Int64;
    WriteOperationCount: Int64;
    OtherOperationCount: Int64;
    ReadTransferCount:   Int64;
    WriteTransferCount:  Int64;
    OtherTransferCount:  Int64;
  end;

  TGetSystemTimeAsFileTimeFn = Procedure (lpSystemTimeAsFileTime:PFILETIME); stdcall;
  TGetHostNameWFn            = function  (lpHostName: LPWSTR; nameLen: Integer): Integer; stdcall;
  TRtlGetVersionFn           = function  (lpVersionInformation: POSVERSIONINFOW): NTSTATUS; stdcall;

  var
    GetSystemTimeAsFileTimeFn:TGetSystemTimeAsFileTimeFn;
    GetHostNameWFn: TGetHostNameWFn;
    RtlGetVersionFn: TRtlGetVersionFn;

    hrtime_frequency_: UInt64 = 0;

function GlobalMemoryStatusEx(lpBuffer: PMemoryStatusEx): BOOL; stdcall; external KERNEL32;
function NtQueryInformationProcess(ProcessHandle: HANDLE; ProcessInformationClass: UINT; ProcessInformation: Pointer; Length: ULONG; ReturnLength: PULONG): NTSTATUS; stdcall; external NTDLL;
function NtQuerySystemInformation(SystemInformationClass: UINT; SystemInformation: Pointer; SystemInformationLength: ULONG; ReturnLength: PULONG): NTSTATUS; stdcall; external NTDLL;
function GetProcessMemoryInfo(Process: HANDLE; ppsmemCounters: PPROCESS_MEMORY_COUNTERS; cb: DWORD): BOOL; stdcall; external PSAPILIB;
function GetProcessIoCounters(hProcess: HANDLE; lpIoCounters: PIO_COUNTERS): BOOL; stdcall;external KERNEL32;
function GetUserProfileDirectoryW(hToken: HANDLE; lpProfileDir: LPWSTR; lpcchSize: PDWORD): BOOL; stdcall;external USERENVLIB;
//function GetHostNameW(lpHostName: LPWSTR; nameLen: Integer): Integer; stdcall; external WS2_32LIB;

function  NT_SUCCESS(aStatus: NTSTATUS): Boolean;{$IFDEF FPDEV_INLINE}inline;{$ENDIF}
begin
  Result := (aStatus >= 0);
end;

procedure util_init;
var
  LKernel32:      TLibHandle;
  LWs2_32:        TLibHandle;
  LNtdll:         TLibHandle;
  LPerfFrequency: ULARGE_INTEGER;
begin
  LKernel32 := LoadLibrary(KERNEL32);

  if LKernel32 = 0 then
    raise Exception.Create('LoadLibrary '+KERNEL32+' failed');

  Pointer(GetSystemTimeAsFileTimeFn) := GetProcAddress(LKernel32,'GetSystemTimePreciseAsFileTime');

  if GetSystemTimeAsFileTimeFn = nil then
    Pointer(GetSystemTimeAsFileTimeFn) := GetProcAddress(LKernel32,'GetSystemTimeAsFileTime');

  if GetSystemTimeAsFileTimeFn = Nil then
    raise Exception.Create('GetProcAddress GetSystemTimeAsFileTime failed');


  FreeLibrary(LKernel32);

  LWs2_32 := LoadLibrary(WS2_32LIB);

  if LWs2_32 = 0 then
    raise Exception.Create('LoadLibrary '+WS2_32LIB+' failed');

  Pointer(GetHostNameWFn) := GetProcAddress(LWs2_32,'GetHostNameW');

  FreeLibrary(LWs2_32);

  LNtdll := LoadLibrary(NTDLL);

  if LNtdll = 0 then
    raise Exception.Create('LoadLibrary '+NTDLL+' failed');

  Pointer(RtlGetVersionFn) := GetProcAddress(LNtdll,'RtlGetVersion');

  FreeLibrary(LNtdll);

  if QueryPerformanceFrequency(TLargeInteger(LPerfFrequency)) then
    hrtime_frequency_ := LPerfFrequency.QuadPart
  else
    raise Exception.Create('QueryPerformanceFrequency failed');
end;

procedure util_final;
begin

end;

{$IFNDEF FPDEV_FPC_EXEPATH}
function exepath: string;
var
  buffer: array[0..MAX_PATH] of WideChar;
  LLen: DWORD;
begin
  LLen := GetModuleFileNameW(0, @buffer, MAX_PATH);
  if LLen > 0 then
    Result := UTF8Encode(WideString(buffer))
  else
    Result := '';
end;
{$ENDIF}


{$IFNDEF FPDEV_FPC_CWD}
function cwd: string;
var
  buffer: array[0..MAX_PATH] of WideChar;
  LLen: DWORD;
begin
  LLen := GetCurrentDirectoryW(MAX_PATH, @buffer);
  if LLen > 0 then
  begin
    Result := UTF8Encode(WideString(buffer));
    // 去掉末尾的斜杠
    if Result[Length(Result)] = '\' then
      Result := Copy(Result, 1, Length(Result) - 1);
  end
  else
    Result := '';
end;
{$ENDIF}

function chdir(const aDir: string): Boolean;
var
  LBuffer: array[0..MAX_PATH] of WideChar;
  LLen: DWORD;

  LDriveLetter: WideChar;
  LEnvVar: array[0..3] of WideChar;
begin
  LLen          := Utf8ToUnicode(PUnicodeChar(@LBuffer[0]),PAnsiChar(aDir),MAX_PATH);

  if LLen = 0 then
    Exit(False);

  LBuffer[LLen] := WideChar(0);
  Result        := SetCurrentDirectoryW(PWideChar(LBuffer));

  if Result then
  begin
    LLen := GetCurrentDirectoryW(MAX_PATH, @LBuffer);
    Result := (LLen>0);

    if Result then
    begin
      LBuffer[LLen] := WideChar(0);

      if (LLen < 2) or (LBuffer[1] <> ':') then
        LDriveLetter := WideChar(0)
      else if (LBuffer[0] >= 'A') and (LBuffer[0] <= 'Z') then
        LDriveLetter := LBuffer[0]
      else if (LBuffer[0] >= 'a') and (LBuffer[0] <= 'z') then
        LDriveLetter := WideChar( ord(LBuffer[0]) - ord('a') + ord('A') )
      else
        LDriveLetter := WideChar(0);

      if ord(LDriveLetter) <> 0 then
      begin
        LEnvVar[0] := WideChar('=');
        LEnvVar[1] := LDriveLetter;
        LEnvVar[2] := WideChar(':');
        LEnvVar[3] := WideChar(0);

        SetEnvironmentVariableW(PWideChar(@LEnvVar), PWideChar(@LBuffer));
      end;
    end;
  end;
end;

function get_home_dir: String;
var
  LPWD: passwd_t;
begin
  Initialize(Result);
  if not get_env('USERPROFILE',Result) then
  begin
    if (not get_passwd(@LPWD)) then
      Exit('');

    Result := LPWD.homedir;
  end;
end;

function get_tmp_dir: String;
label
  do_cleanup;
var
  LLen:  DWORD;
  LPath: array of WideChar;
begin
  Initialize(Result);
  Initialize(LPath);

  LLen := GetTempPathW(0,nil);

  if (LLen = 0) or (LLen < 3) then
    Exit('');

  SetLength(LPath, LLen);
  LLen := GetTempPathW(LLen, PWideChar(@LPath[0]));

  if LLen = 0 then
  begin
    Result := '';
    goto do_cleanup;
  end;

  if (LPath[LLen - 1] = '\') and (LLen = 3) and (LPath[1] = ':') then
  begin
    Dec(LLen);
    SetLength(LPath,LLen);
  end;

  SetLength(Result,LLen);
  UnicodeToUtf8(PAnsiChar(Result),PUnicodeChar(@LPath[0]),LLen);

  do_cleanup:
    SetLength(LPath,0);
end;

function get_env(const aName: string): String;
begin
  Initialize(Result);
  if not get_env(aName,Result) then
    Result := '';
end;

function get_env(const aName:String; var aValue:String):Boolean;
label
  do_cleanup;
const
  DEFAULT_SIZE = 512;
var
  LName:    array of WideChar;
  LBuf:     array of WideChar;
  LBufLen:  DWord;
  LLen:     SizeUInt;
begin
  Initialize(LName);
  Initialize(LBuf);

  LLen   := Length(aName);
  Result := (LLen > 0);

  if not Result then
    exit;

  SetLength(LName,LLen);
  LLen := Utf8ToUnicode(PWideChar(@LName[0]),PAnsiChar(aName),LLen);
  Result := (LLen > 0);

  if not Result then
    goto do_cleanup;

  SetLength(LBuf, DEFAULT_SIZE);
  LLen    := GetEnvironmentVariableW(PWideChar(@LName[0]), PWideChar(@LBuf[0]), DEFAULT_SIZE);
  Result  := (LLen > 0);

  if Result then
  begin
    if LLen > DEFAULT_SIZE then
    begin
      SetLength(LBuf, LLen);
      LBufLen := LLen;
      LLen    := GetEnvironmentVariableW(PWideChar(@LName[0]), PWideChar(@LBuf[0]), LBufLen);
      Result  := (LLen > LBufLen);
    end
    else
      SetLength(LBuf, LLen);

    if Result then
      aValue := UTF8Encode(WideString(LBuf));
  end;

  do_cleanup:
  begin
    SetLength(LName,0);
    SetLength(LBuf,0);
  end;
end;

function set_env(const aName, aValue: string): Boolean;
var
  LName:  UnicodeString;
  LValue: UnicodeString;
begin
  LName  := UTF8ToUnicodeString(aName);
  LValue := UTF8ToUnicodeString(aValue);
  Result := Boolean(SetEnvironmentVariableW(PWideChar(LName),PWideChar(LValue)));
end;

function unset_env(const aName: string): Boolean;
var
  LName: array of WideChar;
  LLen:  SizeUInt;
begin
  LLen   := Length(aName);
  Result := (LLen > 0);

  if Result then
  begin
    Initialize(LName);
    SetLength(LName,LLen);
    LLen   := Utf8ToUnicode(PWideChar(@LName[0]),PAnsiChar(aName),LLen);

    Result := (LLen > 0) and
              Boolean(SetEnvironmentVariableW(PWideChar(@LName[0]),nil));
  end;

  SetLength(LName,0);
end;

function env_items(var aEnvItems: env_item_array): Boolean;
label
  do_continue, do_fail;
var
  LEnv:     PWideChar;
  LEnv2:    PWideChar;
  i:        Integer;
  LCnt:     Integer;
  LEnvItem: penv_item_t;
  LPtr:     PChar;
begin
  SetLength(aEnvItems,0);
  LEnv := GetEnvironmentStringsW();

  if LEnv = nil then
    Exit(False);

  LEnv2 := LEnv;
  i     := 0;
  
  while LEnv2^ <> #0 do
  begin
    Inc(LEnv2, Length(LEnv2) + 1);
    Inc(i);
  end;

  LEnv2 := LEnv;
  LCnt  := 0;
  SetLength(aEnvItems,i);
  LEnvItem:=@aEnvItems[0];

  while (LEnv2^ <> #0) and (LCnt < i) do
  begin
    LEnvItem^.name := UTF8Encode(WideString(LEnv2));
    LPtr           :=StrScan(PChar(PChar(LEnvItem^.name)+1),'=');

    if LPtr = nil then
      goto do_continue;

    LEnvItem^.value := StrPas(LPtr + 1);
    SetLength(LEnvItem^.name, LPtr - PChar(LEnvItem^.name));

    Inc(LCnt);
    Inc(LEnvItem);

    do_continue:
    begin
      Inc(LEnv2, Length(LEnv2) + 1);
    end;
  end;

  if LCnt <> i then
    SetLength(aEnvItems,LCnt);

  FreeEnvironmentStringsW(LEnv);
  exit(True);

  do_fail:
  begin
    SetLength(aEnvItems,0);
    Result := False;
  end;
end;

function uname(aName: putsname_t): Boolean;
var
  LOSInfo:          OSVERSIONINFOW;
  LSystemInfo:      SYSTEM_INFO;
  LRegKey:          HKEY;
  LProductName:     array[0..255] of WideChar;
  LProductNameSize: DWORD;
  LVersionSize:     DWORD;
  LProcessorLevel:  Integer;
  LRet:             Integer;
begin
  if (aName = Nil) or (RtlGetVersionFn = Nil) then
    Exit(False);

  LOSInfo.dwOSVersionInfoSize := SizeOf(LOSInfo);
  LOSInfo.szCSDVersion[0]     := WideChar(#0);

  LVersionSize := 0;
  RtlGetVersionFn(@LOSInfo);
  LRet := RegOpenKeyExW(HKEY_LOCAL_MACHINE,
                        'SOFTWARE\Microsoft\Windows NT\CurrentVersion',
                        0,
                        KEY_QUERY_VALUE or KEY_WOW64_64KEY,
                        @LRegKey);

  if (LRet = ERROR_SUCCESS) then
  begin
    LProductNameSize := SizeOf(LProductName);
    LRet := RegQueryValueExW(LRegKey,'ProductName',Nil,Nil,PBYTE(@LProductName[0]),@LProductNameSize);
    RegCloseKey(LRegKey);

    if (LRet = ERROR_SUCCESS) then
    begin
      LProductNameSize := LProductNameSize div SIZE_WIDECHAR;

      if (LOSInfo.dwMajorVersion = 10) and 
         (LOSInfo.dwBuildNumber >= 22000) and 
         (LProductNameSize >= 10 {Length('Windows 10')}) then
      begin
        if StrLComp(LProductName,'Windows 10', 10 {Length('Windows 10')}) = 0 then
          LProductName[9] := '1';
      end;

     LVersionSize := UnicodeToUtf8(PAnsiChar(@(aName^.version[0])),PUnicodeChar(@LProductName[0]),Length(aName^.version));

      if (LVersionSize <> LProductNameSize) then
        exit(False);
    end;
  end;

  if LOSInfo.szCSDVersion[0] <> #0 then
  begin
    if LVersionSize > 0 then
    begin
      aName^.version[LVersionSize] := ' ';
      Inc(LVersionSize);
    end;

    UnicodeToUtf8(PAnsiChar(@(aName^.version[LVersionSize])),PUnicodeChar(@LOSInfo.szCSDVersion[0]),Length(aName^.version) - LVersionSize);
  end;

  aName^.sysname  := 'Windows_NT';
  aName^.release  := Concat(IntToStr(LOSInfo.dwMajorVersion),'.',IntToStr(LOSInfo.dwMinorVersion),'.',IntToStr(LOSInfo.dwBuildNumber));

  GetSystemInfo(@LSystemInfo);
  case LSystemInfo.wProcessorArchitecture of
    PROCESSOR_ARCHITECTURE_AMD64:         aName^.machine := 'x86_64';
    PROCESSOR_ARCHITECTURE_IA64:          aName^.machine := 'ia64';
    PROCESSOR_ARCHITECTURE_INTEL:
    begin
      aName^.machine := 'i386';

      if LSystemInfo.wProcessorLevel > 3 then
      begin
        if LSystemInfo.wProcessorLevel < 6 then
          LProcessorLevel := LSystemInfo.wProcessorLevel
        else
          LProcessorLevel := 6;

        aName^.machine[1] := Chr(Ord('0') + LProcessorLevel);
      end;
    end;
    PROCESSOR_ARCHITECTURE_IA32_ON_WIN64: aName^.machine := 'i686';
    PROCESSOR_ARCHITECTURE_MIPS:          aName^.machine := 'mips';
    PROCESSOR_ARCHITECTURE_ALPHA,
    PROCESSOR_ARCHITECTURE_ALPHA64:       aName^.machine := 'alpha';
    PROCESSOR_ARCHITECTURE_PPC:           aName^.machine := 'powerpc';
    PROCESSOR_ARCHITECTURE_SHX:           aName^.machine := 'sh';
    PROCESSOR_ARCHITECTURE_ARM:           aName^.machine := 'arm';
    else                                  aName^.machine := 'unknown';
  end;

  Result := True;
end;

function get_passwd(aPwd: ppasswd_t): Boolean;
var
  LToken: HANDLE;
  LUserName: array[0..UNLEN-1] of WideChar;
  LPath: array of WideChar;
  LLen: DWORD;
begin
  if aPwd = nil then
    Exit(False);

  Initialize(LToken);
  Result := Boolean(OpenProcessToken(GetCurrentProcess(), TOKEN_READ, LToken));

  if Result then
  begin
    LLen := 0;
    Result := GetUserProfileDirectoryW(LToken, nil, @LLen);

    if Result then
    begin
      Initialize(LPath);
      SetLength(LPath, LLen);
      Result := GetUserProfileDirectoryW(LToken, @LPath[0], @LLen);

      if Result then
      begin
        LLen := Length(LUserName);
        Result   := GetUserNameW(@LUserName[0], @LLen);

        if Result then
        begin
          LUserName[LLen] := WideChar(0);

          SetLength(aPwd^.username,LLen);
          Result := (UnicodeToUtf8(PAnsiChar(aPwd^.username),PUnicodeChar(@LUserName[0]),LLen) = LLen);

          if Result then
          begin
            LLen := Length(LPath);
            SetLength(aPwd^.homedir,LLen);
            Result := (UnicodeToUtf8(PAnsiChar(aPwd^.homedir),PUnicodeChar(@LPath[0]),LLen) = LLen);

            if Result then
            begin
              aPwd^.shell         := '';
              aPwd^.uid           := 0;
              aPwd^.gid           := 0;
            end;
          end;
        end;
      end;
      SetLength(LPath,0);
    end;
    CloseHandle(LToken);
  end;
end;

function get_hostname: String;
var
  LBuf: array[0..MAXHOSTNAMESIZE] of WideChar;
  LLen: DWORD;
begin
  if GetHostNameWFn = nil then
    exit('');

  Initialize(LBuf);
  FillChar(LBuf[0],SizeOf(LBuf),0);
  if GetHostNameWFn(PWideChar(@LBuf),MAXHOSTNAMESIZE) <> 0 then
    exit('');

  LLen := StrLen(PWideChar(@LBuf));
  if LLen = 0 then
    exit('');

  SetLength(Result,LLen);
  UnicodeToUtf8(PAnsiChar(Result),PUnicodeChar(@LBuf),LLen);
end;

function _get_handle(aPid: pid_t; aAccess: Integer; var aHandle: HANDLE): Boolean;
begin
  if aPid = 0 then
    aHandle := GetCurrentProcess()
  else
    aHandle := OpenProcess(aAccess, False, DWord(aPid));

  if aHandle = 0 then
    Exit(False);

  Result := True;
end;

function get_priority(aPid: pid_t; var aPriority: Integer): Boolean;
var
  LHandle:   HANDLE;
  LPriority: Integer;
begin
  Initialize(LHandle);
  Result := _get_handle(aPid,PROCESS_QUERY_LIMITED_INFORMATION,LHandle);

  if Result then
  begin
    LPriority := GetPriorityClass(LHandle);
    Result := (LPriority <>0);

    if Result then
    begin
      case LPriority of
        REALTIME_PRIORITY_CLASS:     aPriority := PRIORITY_HIGHEST;
        HIGH_PRIORITY_CLASS:         aPriority := PRIORITY_HIGH;
        ABOVE_NORMAL_PRIORITY_CLASS: aPriority := PRIORITY_ABOVE_NORMAL;
        NORMAL_PRIORITY_CLASS:       aPriority := PRIORITY_NORMAL;
        BELOW_NORMAL_PRIORITY_CLASS: aPriority := PRIORITY_BELOW_NORMAL;
        else                         aPriority := PRIORITY_LOW;
      end;
    end;
    CloseHandle(LHandle);
  end;
end;

function set_priority(aPid: pid_t; aPriority: Integer): Boolean;
var
  LHandle: HANDLE;
  LPriority: Integer;
begin
  Initialize(LHandle);
  Result := _get_handle(aPid,PROCESS_SET_INFORMATION,LHandle);

  if Result then
  begin
    case aPriority of
      PRIORITY_HIGHEST:      LPriority := REALTIME_PRIORITY_CLASS;
      PRIORITY_HIGH:         LPriority := HIGH_PRIORITY_CLASS;
      PRIORITY_ABOVE_NORMAL: LPriority := ABOVE_NORMAL_PRIORITY_CLASS;
      PRIORITY_NORMAL:       LPriority := NORMAL_PRIORITY_CLASS;
      PRIORITY_BELOW_NORMAL: LPriority := BELOW_NORMAL_PRIORITY_CLASS;
      else                   LPriority := IDLE_PRIORITY_CLASS;
    end;

    Result := SetPriorityClass(LHandle,LPriority);
    CloseHandle(LHandle);
  end;

end;

function get_free_memory: UInt64;
var
  LMemoryStatus: MEMORYSTATUSEX;
begin
  LMemoryStatus.dwLength := SizeOf(LMemoryStatus);
  if GlobalMemoryStatusEx(@LMemoryStatus) then
    Result := LMemoryStatus.ullAvailPhys
  else
    Result := 0;
end;

function get_total_memory: UInt64;
var
  LMemoryStatus: MEMORYSTATUSEX;
begin
  LMemoryStatus.dwLength := SizeOf(LMemoryStatus);
  if GlobalMemoryStatusEx(@LMemoryStatus) then
    Result := LMemoryStatus.ullTotalPhys
  else
    Result := 0;
end;

function get_cpu_count: UInt32;
var
  LSystemInfo: SYSTEM_INFO;
begin
  GetSystemInfo(@LSystemInfo);
  Result := LSystemInfo.dwNumberOfProcessors;
end;

function get_pid: pid_t;
begin
  Result := pid_t(GetCurrentProcessId());
end;

function get_ppid: pid_t;
var
  LStatus:    NTSTATUS;
  LBasicInfo: PROCESS_BASIC_INFORMATION;
begin
  LStatus := NtQueryInformationProcess(GetCurrentProcess(), PROCESSBASICINFORMATION, @LBasicInfo, SizeOf(LBasicInfo), nil);

  if NT_SUCCESS(LStatus) then
    Result := pid_t(LBasicInfo.InheritedFromUniqueProcessId)
  else
    Result := 0;
end;

function available_parallelism: UInt32;
var
  LProcMask: PtrUInt;
  LSysMask:  PtrUInt;
  i:         Integer;
  LCount:    Integer;
begin
  LCount := 0;
  Initialize(LProcMask);
  Initialize(LSysMask);

  if GetProcessAffinityMask(GetCurrentProcess(), LProcMask, LSysMask) then
    for i := 0 to 8 * SizeOf(LProcMask) - 1 do
      LCount := LCount + (1 and (LProcMask shr i));

  if LCount > 0 then
    Result := LCount
  else
    Result := 1;
end;

function _hrtime(aScale:UInt32): uint64;
var
  LCounter: LARGE_INTEGER;
  LScaledFreq: Double;
  LResult: Double;
begin
  Assert(hrtime_frequency_ <> 0);
  Assert(aScale <> 0);

  if not QueryPerformanceCounter(TLargeInteger(LCounter)) then
    raise Exception.Create('QueryPerformanceCounter failed');

  Assert(LCounter.QuadPart <> 0);
  LScaledFreq := (Double(hrtime_frequency_) / aScale);
  LResult     := (Double(LCounter.QuadPart) / LScaledFreq);
  Result      := Trunc(LResult); // Trunc 比 round 开销小
end;

function hrtime: uint64;
begin
  Result := _hrtime(NANO_SEC);
end;

function clock_gettime(aClockId: clock_id; aTimeSpec: ptimespec64_t): Boolean;
var
  LFileTime: FILETIME;
  LTime:     Int64;
begin
  if aTimeSpec = nil then
    Exit(False);

  case aClockId of
    CLOCK_MONOTONIC:
    begin
      LTime          := _hrtime(NANO_SEC);
      aTimeSpec^.sec  := LTime div NANO_SEC;
      aTimeSpec^.nsec := LTime mod NANO_SEC;
    end;
    CLOCK_REALTIME:
    begin
      GetSystemTimeAsFileTimeFn(@LFileTime);
      LTime          := (int64(LFileTime.dwHighDateTime) shl 32) or LFileTime.dwLowDateTime;
      LTime          := LTime - 116444736000000000;
      aTimeSpec^.sec  := LTime div NANO_SEC;
      aTimeSpec^.nsec := LTime mod NANO_SEC * 100;
    end;
  end;

  Result := True;
end;

function uptime: Integer;
begin
  Result := GetTickCount64() div 1000;
end;

const
  EPOCH: UInt64 = 116444736000000000;

function get_timeofday(aTimeSpec: ptimeval64_t): Boolean;
var
  LFileTime: FILETIME;
  LTime:     ULARGE_INTEGER;
begin
  if aTimeSpec = nil then
    Exit(False);

  GetSystemTimeAsFileTimeFn(@LFileTime);
  LTime.LowPart  := LFileTime.dwLowDateTime;
  LTime.HighPart := LFileTime.dwHighDateTime;
  aTimeSpec^.sec  := Int64((LTime.QuadPart - EPOCH) div 10000000);
  aTimeSpec^.usec := Int32(((LTime.QuadPart - EPOCH) mod 10000000) * 100);
  Result := True;
end;

function resident_set_memory(aRss: PSizeUInt): Boolean;
var
  LProcess: HANDLE;
  LMemoryInfo: PROCESS_MEMORY_COUNTERS;
begin
  LProcess := GetCurrentProcess();
  Result := GetProcessMemoryInfo(LProcess, @LMemoryInfo, SizeOf(LMemoryInfo));

  if Result then
    aRss^ := LMemoryInfo.WorkingSetSize
  else
    aRss^ := 0;
end;

function cpu_info(var aCpuInfos: cpu_info_array): Boolean;
label
  do_error;
const
  SUB_KEY = 'HARDWARE\DESCRIPTION\System\CentralProcessor\';
var
  LSPPI:         PSYSTEM_PROCESSOR_PERFORMANCE_INFORMATION;
  LPSPPI:        PSYSTEM_PROCESSOR_PERFORMANCE_INFORMATION;
  sppi_size:     DWORD;
  LSystemInfo:   SYSTEM_INFO;
  LCpuCount:     DWORD;
  i:             DWORD;
  LStatus:       NTSTATUS;
  LResultSize:   ULONG;

  LErr:          LongInt;
  LKeyName:      array[0..127] of WideChar;
  LProcessorKey: HKEY;
  LPCpuInfo:     pcpu_info_t;
  LSpeed:        DWORD;
  LSpeedSize:    DWORD;
  LCpuBrand:     array[0..255] of WideChar;
  LCpuBrandSize: DWORD;

begin
  LCpuCount := 0;
  LSPPI     := nil;

  GetSystemInfo(@LSystemInfo);
  LCpuCount := LSystemInfo.dwNumberOfProcessors;

  SetLength(aCpuInfos, LCpuCount);

  sppi_size := LCpuCount * SizeOf(SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION);
  LSPPI     := GetMem(sppi_size);

  LStatus := NtQuerySystemInformation(SystemProcessorPerformanceInformation, LSPPI, sppi_size, @LResultSize);

  if not NT_SUCCESS(LStatus) then
    goto do_error;

  Assert(LResultSize = sppi_size);
  LSpeedSize    := SizeOf(LSpeed);
  LPSPPI := LSPPI;
  Initialize(LProcessorKey);

  for i := 0 to LCpuCount - 1 do
  begin
    LKeyName := SUB_KEY + IntToStr(i);
    LErr := RegOpenKeyExW(HKEY_LOCAL_MACHINE, PWideChar(LKeyName), 0, KEY_QUERY_VALUE, LProcessorKey);

    if LErr <> ERROR_SUCCESS then
      goto do_error;

    LErr := RegQueryValueExW(LProcessorKey, '~MHz', nil, nil, PBYTE(@LSpeed), @LSpeedSize);

    if LErr <> ERROR_SUCCESS then
    begin
      RegCloseKey(LProcessorKey);
      goto do_error;
    end;

    LCpuBrandSize := SizeOf(LCpuBrand);
    LErr := RegQueryValueExW(LProcessorKey,'ProcessorNameString', nil, nil, PBYTE(@LCpuBrand[0]), @LCpuBrandSize);
    RegCloseKey(LProcessorKey);

    if LErr <> ERROR_SUCCESS then
      goto do_error;

    LPCpuInfo                 := @aCpuInfos[i];
    LPCpuInfo^.speed          := LSpeed;
    LPCpuInfo^.cpu_times.user := LPSPPI^.UserTime.QuadPart div 10000;
    LPCpuInfo^.cpu_times.sys  := (LPSPPI^.KernelTime.QuadPart - LPSPPI^.IdleTime.QuadPart) div 10000;
    LPCpuInfo^.cpu_times.idle := LPSPPI^.IdleTime.QuadPart div 10000;
    LPCpuInfo^.cpu_times.irq  := LPSPPI^.InterruptTime.QuadPart div 10000;
    LPCpuInfo^.cpu_times.nice := 0;

    LCpuBrandSize := LCpuBrandSize div SIZE_WIDECHAR;
    SetLength(LPCpuInfo^.model,LCpuBrandSize);
    UnicodeToUtf8(PAnsiChar(LPCpuInfo^.model),PUnicodeChar(@LCpuBrand[0]),LCpuBrandSize);

    Inc(LPSPPI)
  end;

  Freemem(LSPPI);
  Exit(True);

  do_error:
  begin
    FreeMem(LSPPI);
    SetLength(aCpuInfos,0);
    Result := False;
  end;
  
end;

function get_rusage(aRusage: prusage_t): Boolean;
var
  LHandle:           THANDLE;
  LCreateTime:       FILETIME;
  LExitTime:         FILETIME;
  LKernelTime:       FILETIME;
  LUserTime:         FILETIME;
  LKernelSystemTime: SYSTEMTIME;
  LUserSystemTime:   SYSTEMTIME;
  LMemCounters:      PROCESS_MEMORY_COUNTERS;
  LIoCounters:       IO_COUNTERS;
begin
  Initialize(LCreateTime);
  Initialize(LExitTime);
  Initialize(LKernelTime);
  Initialize(LUserTime);
  Initialize(LKernelSystemTime);
  Initialize(LUserSystemTime);
  // Initialize(LMemCounters);
  // Initialize(LIoCounters);

  LHandle := GetCurrentProcess();
  Result  := GetProcessTimes(LHandle,LCreateTime,LExitTime,LKernelTime,LUserTime) And
             FileTimeToSystemTime(LKernelTime,LKernelSystemTime) And
             FileTimeToSystemTime(LUserTime,LUserSystemTime) And
             GetProcessMemoryInfo(LHandle,@LMemCounters,SizeOf(LMemCounters)) And
             GetProcessIoCounters(LHandle,@LIoCounters);

  if Result then
  begin
    aRusage^.ru_utime.sec  := LUserSystemTime.wHour * 3600 +
                              LUserSystemTime.wMinute * 60 +
                              LUserSystemTime.wSecond;
    aRusage^.ru_utime.usec := LUserSystemTime.wMilliseconds * 1000;

    aRusage^.ru_stime.sec  := LKernelSystemTime.wHour * 3600 +
                              LKernelSystemTime.wMinute * 60 +
                              LKernelSystemTime.wSecond;
    aRusage^.ru_stime.usec := LKernelSystemTime.wMilliseconds * 1000;

    aRusage^.ru_majflt        := UInt64(LMemCounters.PageFaultCount);
    aRusage^.ru_maxrss        := UInt64(LMemCounters.PeakWorkingSetSize div 1024);
    aRusage^.ru_oublock       := UInt64(LIoCounters.WriteOperationCount);
    aRusage^.ru_inblock       := UInt64(LIoCounters.ReadOperationCount);
  end;

end;
