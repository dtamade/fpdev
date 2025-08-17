unit fpdev.git2.testcase;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  git2.api, git2.impl, fpdev.git2;

procedure RunAll;

implementation

procedure RunAll;
begin
  // 预留：若后续重构为 fpcunit，这里作为桥接
end;

end.

