program minimal_test;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils;

function SameText(const S1, S2: string): Boolean;
begin
  Result := CompareText(S1, S2) = 0;
end;

var
  LParam: string;
begin
  try
    WriteLn('MINIMAL TEST START');
    
    if ParamCount = 0 then 
    begin
      WriteLn('NO PARAMS');
    end
    else
    begin
      WriteLn('PARAMS COUNT: ', ParamCount);
      LParam := ParamStr(1);
      WriteLn('PARAM 1: "', LParam, '"');
      
      if SameText(LParam, 'fpc') then
      begin
        WriteLn('FPC COMMAND DETECTED');
      end
      else
      begin
        WriteLn('OTHER COMMAND: ', LParam);
      end;
    end;
    
    WriteLn('MINIMAL TEST END');
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
    end;
  end;
end.
