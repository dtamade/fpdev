unit fpdev.help.usage;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf;

function PrintUsageCore(const Parts: array of string; const Outp: IOutput): Boolean;

implementation

uses
  fpdev.command.registry,
  fpdev.help.routing,
  fpdev.i18n,
  fpdev.i18n.strings;

function JoinCommandPathCore(const Parts: array of string): string;
var
  Index: Integer;
begin
  Result := '';
  for Index := Low(Parts) to High(Parts) do
  begin
    if Parts[Index] = '' then
      Continue;

    if Result <> '' then
      Result := Result + ' ';
    Result := Result + LowerCase(Parts[Index]);
  end;
end;

function TryWriteGlobalPseudoUsageCore(
  const Parts: array of string;
  const Outp: IOutput
): Boolean;
var
  CommandName: string;
begin
  Result := False;
  if Length(Parts) = 0 then
    Exit(False);

  CommandName := LowerCase(Parts[0]);

  if CommandName = 'help' then
  begin
    Outp.WriteLn('Usage: fpdev system help [command-path]');
    Outp.WriteLn('');
    Outp.WriteLn(_(HELP_EXAMPLES));
    Outp.WriteLn('  fpdev system help');
    Outp.WriteLn('  fpdev system help fpc');
    Exit(True);
  end;

  if CommandName = 'version' then
  begin
    Outp.WriteLn('Usage: fpdev system version');
    Exit(True);
  end;
end;

function TryWriteDynamicCommandUsageCore(
  const Parts: array of string;
  const Outp: IOutput
): Boolean;
var
  Children: TStringArray;
  Index: Integer;
  CommandPath: string;
begin
  if TryDispatchLeafHelp(Parts, Outp) then
    Exit(True);

  Children := GlobalCommandRegistry.ListChildren(Parts);
  if Length(Children) = 0 then
    Exit(False);

  CommandPath := JoinCommandPathCore(Parts);
  if CommandPath = '' then
    Exit(False);

  Outp.WriteLn('Usage: fpdev ' + CommandPath + ' <command>');
  Outp.WriteLn('');
  Outp.WriteLn(_(HELP_AVAILABLE_SUBCOMMANDS));
  for Index := 0 to High(Children) do
    Outp.WriteLn('  ' + Children[Index]);
  Result := True;
end;

function PrintUsageCore(const Parts: array of string; const Outp: IOutput): Boolean;
begin
  Result := False;
  if Length(Parts) = 0 then
    Exit(False);

  if TryWriteGlobalPseudoUsageCore(Parts, Outp) then
    Exit(True);

  Result := TryWriteDynamicCommandUsageCore(Parts, Outp);
end;

end.
