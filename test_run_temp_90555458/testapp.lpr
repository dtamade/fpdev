program testapp;
{$mode objfpc}{$H+}
uses SysUtils;
var i: Integer;
begin
  WriteLn('TestApp Running');
  for i := 1 to ParamCount do
    WriteLn('Arg ', i, ': ', ParamStr(i));
  ExitCode := 0;
end.
