program fpdev_git2_fpcunit;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  fpcunit, testregistry, testutils, consoletestrunner,
  fpdev.git2.fpcunit.tests;

begin
  RunRegisteredTests;
end.
