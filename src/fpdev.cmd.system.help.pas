unit fpdev.cmd.system.help;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.exitcodes;

type
  TSystemHelpCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateSystemHelpCommand: ICommand;

implementation

uses
  fpdev.help.commandflow;

function CreateSystemHelpCommand: ICommand;
begin
  Result := TSystemHelpCommand.Create;
end;

function TSystemHelpCommand.Name: string;
begin
  Result := 'help';
end;

function TSystemHelpCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TSystemHelpCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TSystemHelpCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  HelpParams: TStringArray;
  Index: Integer;
begin
  HelpParams := nil;
  if Length(AParams) = 0 then
    ExecuteHelpCore(AParams, Ctx.Out)
  else
  begin
    SetLength(HelpParams, Length(AParams) + 1);
    HelpParams[0] := 'system';
    for Index := 0 to High(AParams) do
      HelpParams[Index + 1] := AParams[Index];
    ExecuteHelpCore(HelpParams, Ctx.Out);
  end;
  Result := EXIT_OK;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'help'], @CreateSystemHelpCommand, []);

end.
