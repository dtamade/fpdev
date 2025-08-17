unit fpdev.utils;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.util

工具类


## 声明

转发或者用于自己项目请保留本项目的版权声明,谢谢.

fafafaStudio
Email:dtamade@gmail.com
QQ群:685403987  QQ:179033731    

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  sysutils;

const

  NANO_SEC        = 1000000000;
  UNLEN           = 256;
  MAXHOSTNAMESIZE = 256;

  {$IFDEF FPDEV_PASE}
  PRIORITY_LOW = 39;
  PRIORITY_BELOW_NORMAL = 15;
  PRIORITY_NORMAL = 0;
  PRIORITY_ABOVE_NORMAL = -4;
  PRIORITY_HIGH = -7;
  PRIORITY_HIGHEST = -10;
  {$ELSE}
  PRIORITY_LOW = 19;
  PRIORITY_BELOW_NORMAL = 10;
  PRIORITY_NORMAL = 0;
  PRIORITY_ABOVE_NORMAL = -7;
  PRIORITY_HIGH = -14;
  PRIORITY_HIGHEST = -20;
  {$ENDIF}

type

  pid_t = UInt32;

  clock_id = (CLOCK_MONOTONIC,CLOCK_REALTIME);

  timespec_t=record
    sec:  Int32;
    nsec: Int32;
  end;
  ptimespec_t=^timespec_t;

  timespec64_t=record
    sec:  int64;
    nsec: int32;
  end;
  ptimespec64_t=^timespec64_t;

  timeval_t=record
    sec:  Int32;
    usec: Int32;
  end;
  ptimeval_t=^timeval_t;

  timeval64_t=record
    sec:  int64;
    usec: int32;
  end;
  ptimeval64_t=^timeval64_t;

  // 毫秒
  cpu_times_t = record
    user: uint64;
    nice: uint64;
    sys:  uint64;
    idle: uint64;
    irq:  uint64;
  end;

  cpu_info_t = record
    model:     string;
    speed:     UInt32;
    cpu_times: cpu_times_t;
  end;
  pcpu_info_t = ^cpu_info_t;

  cpu_info_array = array of cpu_info_t;
  pcpu_info_array = ^cpu_info_array;

rusage_t = record
  ru_utime:    timeval_t;
  ru_stime:    timeval_t;
  ru_maxrss:   uint64;
  ru_ixrss:    uint64;
  ru_idrss:    uint64;
  ru_isrss:    uint64;
  ru_minflt:   uint64;
  ru_majflt:   uint64;
  ru_nswap:    uint64;
  ru_inblock:  uint64;
  ru_oublock:  uint64;
  ru_msgsnd:   uint64;
  ru_msgrcv:   uint64;
  ru_nsignals: uint64;
  ru_nvcsw:    uint64;
  ru_nivcsw:   uint64;
end;
prusage_t = ^rusage_t;

env_item_t = record
  name: string;
  value: string;
end;
penv_item_t = ^env_item_t;

env_item_array = array of env_item_t;
penv_item_array = ^env_item_array;

passwd_t = record
  username: string;
  uid:      uint64;
  gid:      uint64;
  shell:    string;
  homedir:  string;
end;
ppasswd_t = ^passwd_t;

utsname_t = record
  sysname:  array[0..255] of Char;
  nodename: array[0..255] of Char;
  release:  array[0..255] of Char;
  version:  array[0..255] of Char;
  machine:  array[0..255] of Char;
end;
putsname_t = ^utsname_t;


function exepath: string;
function cwd: string;
function chdir(const aDir: string): Boolean;
function get_home_dir: String;
function get_tmp_dir: String;
function get_env(const aName: string): String; overload;
function get_env(const aName: String; var aValue:String): Boolean;
function set_env(const aName, aValue: string): Boolean;
function unset_env(const aName: string): Boolean;
function env_items(var aEnvItems: env_item_array): Boolean;

function uname(aName: putsname_t): Boolean;
function get_passwd(aPwd: ppasswd_t): Boolean;
function get_hostname: String;
function get_priority(aPid: pid_t; var aPriority: Integer): Boolean;
function set_priority(aPid: pid_t; aPriority: Integer): Boolean;

function get_cpu_count: UInt32;
function get_pid: pid_t;
function get_ppid: pid_t;
function available_parallelism: UInt32;

function hrtime: uint64;
function clock_gettime(aClockId: clock_id; aTimeSpec: ptimespec64_t): Boolean;
function uptime:Integer;
function get_timeofday(aTimeSpec: ptimeval64_t): Boolean;

function get_free_memory: UInt64;
function get_total_memory: UInt64;
function resident_set_memory(aRss: PSizeUInt): Boolean;

function cpu_info(var aCpuInfos: cpu_info_array): Boolean;
function get_rusage(aRusage: prusage_t):Boolean;


implementation

{$IFDEF MSWINDOWS}
  {$I fpdev.utils.windows.inc}
{$ELSE}
  {$I fpdev.utils.unix.inc}
{$ENDIF}

{$IFDEF FPDEV_FPC_EXEPATH}
function exepath: string;
begin
  Result := ParamStr(0);
end;
{$ENDIF}

{$IFDEF FPDEV_FPC_CWD}
function cwd: string;
begin
  Result := GetCurrentDir();
end;
{$ENDIF}

{ 暂时注释掉未定义的初始化函数
initialization
  util_init;

finalization
  util_final;
}


end.
