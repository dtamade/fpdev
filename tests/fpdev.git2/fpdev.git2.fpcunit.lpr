program fpdev_git2_fpcunit;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  fpcunit, testregistry, testutils, consoletestrunner,
  fpdev.git2.fpcunit.tests;

var
  Runner: TTestRunner;

begin
  Runner := TTestRunner.Create(nil);
  try
    Runner.Initialize;
    Runner.Run;
  finally
    Runner.Free;
  end;
end.
