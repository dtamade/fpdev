program fpdev;

{$mode objfpc}{$H+}
{$Define SYSTEMINLINE}

uses
{$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  Classes,
  fpdev.utils,
  fpdev.cmd.help,
  fpdev.cmd.version,
  fpdev.terminal,
  fpdev.settings;

var
  LParam1: string;

begin
  if ParamCount = 0 then execute_cmd_help
  else
  begin
    LParam1 := ParamStr(1);
    
    if      SameText(LParam1, 'help')    then execute_cmd_help
    else if SameText(LParam1, 'version') then execute_cmd_version
    //else if SameText(LParam1, 'fpc')     then execute_cmd_fpc
    //else if SameText(LParam1, 'lazarus') then execute_cmd_lazarus
    //else if SameText(LParam1, 'package') then execute_cmd_package
    //else if SameText(LParam1, 'cross')   then execute_cmd_cross
    //else if SameText(LParam1, 'project') then execute_cmd_project
    else
      WriteLn('unknown command: ' + LParam1);
  end;
end.
    
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
