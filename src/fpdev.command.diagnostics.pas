unit fpdev.command.diagnostics;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf;

procedure WriteUnknownCommandSuggestion(
  const AErr: IOutput;
  const AUnknownCmd, ASuggestion: string
);
procedure WriteUnknownCommandAvailableCommands(
  const AErr: IOutput;
  const AUnknownCmd: string;
  const ACommands: TStringArray
);
procedure WriteMissingSubcommandUsage(
  const AErr: IOutput;
  const ACommandName: string;
  const ACommands: TStringArray
);

implementation

procedure WriteCommandList(const AErr: IOutput; const ACommands: TStringArray);
var
  I: Integer;
begin
  if AErr = nil then
    Exit;

  AErr.WriteLn('Available commands:');
  for I := 0 to High(ACommands) do
    AErr.WriteLn('  ' + ACommands[I]);
end;

procedure WriteUnknownCommandSuggestion(
  const AErr: IOutput;
  const AUnknownCmd, ASuggestion: string
);
begin
  if AErr = nil then
    Exit;

  AErr.WriteLn('Unknown command: ' + AUnknownCmd);
  AErr.WriteLn('');
  AErr.WriteLn('Did you mean "' + ASuggestion + '"?');
  AErr.WriteLn('');
  AErr.WriteLn('Run "fpdev system help" for available commands.');
end;

procedure WriteUnknownCommandAvailableCommands(
  const AErr: IOutput;
  const AUnknownCmd: string;
  const ACommands: TStringArray
);
begin
  if AErr = nil then
    Exit;

  AErr.WriteLn('Unknown command: ' + AUnknownCmd);
  AErr.WriteLn('');
  WriteCommandList(AErr, ACommands);
end;

procedure WriteMissingSubcommandUsage(
  const AErr: IOutput;
  const ACommandName: string;
  const ACommands: TStringArray
);
begin
  if AErr = nil then
    Exit;

  AErr.WriteLn('Usage: fpdev ' + ACommandName + ' <command>');
  AErr.WriteLn('');
  WriteCommandList(AErr, ACommands);
  AErr.WriteLn('');
  AErr.WriteLn('Use "fpdev ' + ACommandName + ' <command> --help" for more information.');
end;

end.
