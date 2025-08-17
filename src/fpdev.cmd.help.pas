unit fpdev.cmd.help;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.help

帮助


## 声明

转发或者用于自己项目请保留本项目的版权声明,谢谢.

fafafaStudio
Email:dtamade@gmail.com
QQ群:685403987  QQ:179033731    

}

{$mode objfpc}{$H+}

interface

uses
  sysutils,
  fpdev.terminal;

procedure execute(const aParams: array of string);

implementation

procedure execute(const aParams: array of string);
var
  LParamCount: Integer;
  LParam:      string;
begin
  LParamCount := Length(aParams);
  WriteLn('fpdev help:');

  if LParamCount > 0 then
  begin
    for LParam in aParams do
      WriteLn('fpdev help ' + LParam);
  end
  else
  begin
    WriteLn('fpdev help [command]');
    WriteLn('fpdev help version');
    WriteLn('fpdev help fpc');
    WriteLn('fpdev help lazarus');
    WriteLn('fpdev help package');
    WriteLn('fpdev help cross');
    WriteLn('fpdev help project'); 
  end;
end;


end.