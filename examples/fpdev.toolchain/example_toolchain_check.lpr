program example_toolchain_check;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.toolchain;

begin
  WriteLn(BuildToolchainReportJSON);
end.

