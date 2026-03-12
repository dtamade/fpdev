unit fpdev.command.rootshell;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf;

type
  TNamespaceRootShellCommand = class(TInterfacedObject, ICommand)
  private
    FPath: TStringArray;
    FPathText: string;
    FLeafName: string;
  public
    constructor Create(const APath: array of string);
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateNamespaceRootShellCommand(const APath: array of string): ICommand;

implementation

uses
  fpdev.command.diagnostics,
  fpdev.command.registry,
  fpdev.exitcodes;

function CreateNamespaceRootShellCommand(const APath: array of string): ICommand;
begin
  Result := TNamespaceRootShellCommand.Create(APath);
end;

constructor TNamespaceRootShellCommand.Create(const APath: array of string);
var
  Index: Integer;
begin
  inherited Create;
  SetLength(FPath, Length(APath));
  for Index := Low(APath) to High(APath) do
    FPath[Index] := APath[Index];

  if Length(FPath) > 0 then
    FLeafName := FPath[High(FPath)]
  else
    FLeafName := '';

  FPathText := '';
  for Index := 0 to High(FPath) do
  begin
    if FPathText <> '' then
      FPathText := FPathText + ' ';
    FPathText := FPathText + FPath[Index];
  end;
end;

function TNamespaceRootShellCommand.Name: string;
begin
  Result := FLeafName;
end;

function TNamespaceRootShellCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TNamespaceRootShellCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TNamespaceRootShellCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  if Length(AParams) <> 0 then;
  WriteMissingSubcommandUsage(Ctx.Err, FPathText, GlobalCommandRegistry.ListChildren(FPath));
  Result := EXIT_USAGE_ERROR;
end;

end.
