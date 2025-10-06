program example_policy_check;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.toolchain;

var
  LStatus, LReason, LMin, LRec, LCur: string;
  LSrc: string;
begin
  if ParamCount>=1 then LSrc := ParamStr(1) else LSrc := 'main';
  if CheckFPCVersionPolicy(LSrc, LStatus, LReason, LMin, LRec, LCur) then
  begin
    WriteLn('Policy OK: src=', LSrc, ' current=', LCur, ' min=', LMin, ' rec=', LRec, ' status=', LStatus);
  end
  else
  begin
    WriteLn('Policy FAIL: src=', LSrc, ' current=', LCur, ' min=', LMin, ' rec=', LRec, ' reason=', LReason);
    Halt(2);
  end;
end.

