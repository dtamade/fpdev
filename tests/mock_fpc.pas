program mock_fpc;

{$mode objfpc}{$H+}

uses
  SysUtils;

begin
  // Mock FPC that returns version 3.2.2 when called with -iV
  if (ParamCount = 1) and (ParamStr(1) = '-iV') then
    WriteLn('3.2.2')
  else
    WriteLn('Mock FPC compiler');

  ExitCode := 0;
end.
