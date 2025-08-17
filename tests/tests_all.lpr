program tests_all;
{$CODEPAGE UTF8}


{$mode objfpc}{$H+}

uses
  consoletestrunner, testregistry,
  test_git2_cases;

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

