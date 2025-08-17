program test_main;

{$mode objfpc}{$H+}

uses
  SysUtils;

function make_params: TStringArray;
var
  i: Integer;
begin
  SetLength(Result, ParamCount - 1);
  for i := 2 to ParamCount do
    Result[i - 2] := ParamStr(i);
end;

var
  LParam: string;
  LParams: TStringArray;
  i: Integer;

begin
  try
    WriteLn('Program started');
    WriteLn('ParamCount: ', ParamCount);
    
    for i := 0 to ParamCount do
      WriteLn('Param[', i, ']: "', ParamStr(i), '"');
    
    if ParamCount = 0 then
    begin
      WriteLn('No parameters provided');
    end
    else
    begin
      LParam := ParamStr(1);
      LParams := make_params;
      
      WriteLn('First param: "', LParam, '"');
      WriteLn('Remaining params count: ', Length(LParams));
      
      for i := 0 to High(LParams) do
        WriteLn('LParams[', i, ']: "', LParams[i], '"');
      
      if SameText(LParam, 'project') then
        WriteLn('Would call project module')
      else
        WriteLn('Unknown command: ', LParam);
    end;
    
    WriteLn('Program completed');
    
  except
    on E: Exception do
    begin
      WriteLn('Error: ', E.ClassName, ': ', E.Message);
    end;
  end;
end.
