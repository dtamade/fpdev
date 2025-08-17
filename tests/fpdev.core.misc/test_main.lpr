program test_main;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils,
  fpdev.utils;

function make_params: TStringArray;
var
  i: Integer;
begin
  SetLength(Result, ParamCount - 1);
  for i := 2 to ParamCount do
    Result[i - 2] := ParamStr(i);
end;

function SameText(const S1, S2: string): Boolean;
begin
  Result := CompareText(S1, S2) = 0;
end;

var
  LParam: string;
  LParams: TStringArray;
  DebugFile: TextFile;
begin
  try
    // 写入调试文件
    AssignFile(DebugFile, 'debug.log');
    Rewrite(DebugFile);
    WriteLn(DebugFile, 'PROGRAM START');
    
    WriteLn('PROGRAM START');
    if ParamCount = 0 then 
    begin
      WriteLn(DebugFile, 'NO PARAMS');
      WriteLn('NO PARAMS');
    end
    else
    begin
      WriteLn(DebugFile, 'PARAMS COUNT: ', ParamCount);
      WriteLn('PARAMS COUNT: ', ParamCount);
      LParam  := ParamStr(1);
      LParams := make_params;

      WriteLn(DebugFile, 'DEBUG: Command = "', LParam, '"');
      WriteLn('DEBUG: Command = "', LParam, '"');
      
      if SameText(LParam, 'fpc') then 
      begin
        WriteLn(DebugFile, 'FPC COMMAND DETECTED');
        WriteLn('FPC COMMAND DETECTED');
      end
      else
      begin
        WriteLn(DebugFile, 'OTHER COMMAND: ', LParam);
        WriteLn('OTHER COMMAND: ', LParam);
      end;
    end;
    WriteLn(DebugFile, 'PROGRAM END');
    WriteLn('PROGRAM END');
    CloseFile(DebugFile);
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
      if Assigned(@DebugFile) then
      begin
        WriteLn(DebugFile, 'EXCEPTION: ', E.ClassName, ': ', E.Message);
        CloseFile(DebugFile);
      end;
      ExitCode := 1;
    end;
  end;
end.
