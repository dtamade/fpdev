program test_cli_helpers_verify;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.config.interfaces, fpdev.output.intf,
  fpdev.exitcodes, test_cli_helpers, test_temp_paths;

var
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  TempDir: string;

begin
  WriteLn('=== CLI Helpers Verification Tests ===');
  WriteLn;

  TempDir := CreateUniqueTempDir('fpdev_test_cli_helpers');

  try
    // Group 1: TStringOutput basics
    WriteLn('--- TStringOutput ---');
    StdOut := TStringOutput.Create;
    try
      Check('Empty buffer', StdOut.GetBuffer = '');
      Check('Empty LineCount', StdOut.LineCount = 0);

      StdOut.WriteLn('Hello');
      Check('Contains Hello', StdOut.Contains('Hello'));
      Check('LineCount after WriteLn', StdOut.LineCount = 1);

      StdOut.WriteLn('World');
      Check('Contains World', StdOut.Contains('World'));
      Check('LineCount after 2 WriteLn', StdOut.LineCount = 2);

      StdOut.Clear;
      Check('Empty after Clear', StdOut.GetBuffer = '');
    finally
      StdOut.Free;
    end;

    // Group 2: TStringOutput format methods
    WriteLn('');
    WriteLn('--- TStringOutput Format ---');
    StdOut := TStringOutput.Create;
    try
      StdOut.WriteFmt('%d+%d=%d', [1, 2, 3]);
      Check('WriteFmt', StdOut.Contains('1+2=3'));

      StdOut.Clear;
      StdOut.WriteLnFmt('ver=%s', ['3.2.2']);
      Check('WriteLnFmt', StdOut.Contains('ver=3.2.2'));

      StdOut.Clear;
      StdOut.WriteColored('red', ccRed);
      Check('WriteColored captures text', StdOut.Contains('red'));

      StdOut.Clear;
      StdOut.WriteSuccess('ok');
      StdOut.WriteError('err');
      StdOut.WriteWarning('warn');
      StdOut.WriteInfo('info');
      Check('Semantic helpers capture text',
        StdOut.Contains('ok') and StdOut.Contains('err') and
        StdOut.Contains('warn') and StdOut.Contains('info'));

      Check('SupportsColor is False', not StdOut.SupportsColor);
    finally
      StdOut.Free;
    end;

    // Group 3: CreateTestContext
    WriteLn('');
    WriteLn('--- CreateTestContext ---');
    Ctx := CreateTestContext(TempDir, StdOut, StdErr);
    Check('Ctx is not nil', Ctx <> nil);
    Check('Ctx.Out is not nil', Ctx.Out <> nil);
    Check('Ctx.Err is not nil', Ctx.Err <> nil);
    Check('Ctx.Config is not nil', Ctx.Config <> nil);
    Check('Ctx.Logger is not nil', Ctx.Logger <> nil);

    Ctx.Out.WriteLn('test output');
    Check('Ctx.Out captures text', StdOut.Contains('test output'));

    // Group 4: Check function behavior
    WriteLn('');
    WriteLn('--- Check Function ---');
    Check('GTestCount > 0', GTestCount > 0);
    Check('GPassCount > 0', GPassCount > 0);
    Check('GFailCount = 0 so far', GFailCount = 0);
  finally
    CleanupTempDir(TempDir);
  end;

  Halt(PrintTestSummary);
end.
