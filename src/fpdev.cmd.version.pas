unit fpdev.cmd.version;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.version

版本


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
  sysutils,
  fpdev.utils;

const
  VERSION_MAJOR = 0;
  VERSION_MINOR = 0;
  VERSION_BUILD = 1;

resourcestring
  S_PLATFORM     = 'platform:';
  S_MACHINE      = 'machine:';
  S_VERSION      = 'version:';
  S_BUILD_TIME   = 'build time:';
  S_COMPILER     = 'compiler:';
  S_PATH         = 'path:    ';
  S_FPC          = 'fpc:';
  S_FPC_PATH     = 'fpc path:';
  S_LAZARUS      = 'lazarus:';
  S_LAZARUS_PATH = 'lazarus path:';
  S_CROSS        = 'cross:';
  S_CROSS_PATH   = 'cross path:';


procedure execute(const aParams: array of string);

var
  BUILD_DATE:  String = {$I %date%};
  BUILD_TIME:  string = {$I %time%};
  FPC_VERSION: string = {$I %FPCVERSION%};

implementation

procedure execute(const aParams: array of string);
var
  LUName:utsname_t;
begin
  WriteLn(S_VERSION, #9,     VERSION_MAJOR,'.',VERSION_MINOR,'.',VERSION_BUILD);
  WriteLn(S_BUILD_TIME, #9,  BUILD_DATE,' ', BUILD_TIME);
  WriteLn(S_COMPILER, #9,    'fpc-',FPC_VERSION);
  WriteLn(S_PATH, #9,        exepath());

  if uname(@LUName) then
  begin
    WriteLn(S_PLATFORM, #9, LUName.version,' ', LUName.sysname,' ',LUName.release,' ');
    WriteLn(S_machine,#9, LUName.machine);
  end;

end;


end.