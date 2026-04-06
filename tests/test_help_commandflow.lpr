program test_help_commandflow;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.command.imports,
  fpdev.help.commandflow,
  fpdev.output.intf,
  test_cli_helpers;

var
  OutBuf: TStringOutput;
  Outp: IOutput;

begin
  WriteLn('=== Help Commandflow Tests ===');
  WriteLn;

  OutBuf := TStringOutput.Create;
  Outp := OutBuf as IOutput;
  try
    OutBuf.Clear;
    ExecuteHelpCore(['system', 'env'], Outp);
    Check('system help env prints system env usage',
      OutBuf.Contains('Usage: fpdev system env [command]'));

    OutBuf.Clear;
    ExecuteHelpCore(['system', 'toolchain'], Outp);
    Check('system help toolchain prints namespace usage',
      OutBuf.Contains('Usage: fpdev system toolchain <command>'));
    Check('system help toolchain lists registered subcommands',
      Pos('check', LowerCase(OutBuf.GetBuffer)) > 0);

    OutBuf.Clear;
    ExecuteHelpCore(['fpc', 'cache'], Outp);
    Check('fpc help cache prints domain usage',
      OutBuf.Contains('Usage: fpdev fpc cache <subcommand>'));
  finally
    Outp := nil;
  end;

  Halt(PrintTestSummary);
end.
