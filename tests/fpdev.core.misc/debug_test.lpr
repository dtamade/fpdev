program debug_test;

{$codepage utf8}
{$mode objfpc}{$H+}

begin
  WriteLn('Hello World!');
  WriteLn('This is a debug test');
  WriteLn('Program arguments: ', ParamCount);
  if ParamCount > 0 then
    WriteLn('First argument: ', ParamStr(1));
end.
