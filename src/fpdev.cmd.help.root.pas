unit fpdev.cmd.help.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry, fpdev.command.intf, fpdev.cmd.help, git2.types;

type
  { THelpCommand }
  THelpCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const AContext: ICommandContext);
  end;

function HelpFactory: IFpdevCommand;

implementation

{ THelpCommand }

function THelpCommand.Name: string;
begin
  Result := 'help';
end;

function THelpCommand.Aliases: TStringArray;
begin
  SetLength(Result, 2);
  Result[0] := 'h';
  Result[1] := '?';
end;

function THelpCommand.FindSub(const AName: string): IFpdevCommand;
begin
  Result := nil; // help命令没有子命令
end;

procedure THelpCommand.Execute(const AParams: array of string; const AContext: ICommandContext);
begin
  fpdev.cmd.help.execute(AParams);
end;

function HelpFactory: IFpdevCommand;
begin
  Result := THelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['help'], @HelpFactory, ['h', '?']);

end.
