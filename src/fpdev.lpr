program fpdev;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  fpdev.cli.global,
  fpdev.cli.runner,
  fpdev.debug.symbols,

  fpdev.output.intf,
  fpdev.output.console;

var
  RawArgs: TStringArray;
  Outp: IOutput;
  Errp: IOutput;


begin
  EnsureDebugSymbolAnchor;
  RawArgs := CollectCLIArgs;
  Outp := TConsoleOutput.Create(False) as IOutput;
  Errp := TConsoleOutput.Create(True) as IOutput;
  ExitCode := RunCLI(RawArgs, Outp, Errp);
end.
