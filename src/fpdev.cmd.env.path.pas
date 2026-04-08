unit fpdev.cmd.env.path;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.exitcodes, fpdev.utils;

type
  TEnvPathCommand = class(TInterfacedObject, ICommand)
  private
    procedure ShowPathEnv(const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateEnvPathCommand: ICommand;

implementation

function CreateEnvPathCommand: ICommand;
begin
  Result := TEnvPathCommand.Create;
end;

function TEnvPathCommand.Name: string;
begin
  Result := 'path';
end;

function TEnvPathCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TEnvPathCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

procedure TEnvPathCommand.ShowPathEnv(const Ctx: IContext);
var
  PathEnv: string;
  Paths: TStringList;
  I: Integer;
  P: string;
begin
  Ctx.Out.WriteLn('PATH Configuration');
  Ctx.Out.WriteLn('==================');
  Ctx.Out.WriteLn('');

  PathEnv := get_env('PATH');
  if PathEnv = '' then
  begin
    Ctx.Out.WriteLn('PATH is empty');
    Exit;
  end;

  Paths := TStringList.Create;
  try
    {$IFDEF WINDOWS}
    Paths.Delimiter := ';';
    {$ELSE}
    Paths.Delimiter := ':';
    {$ENDIF}
    Paths.StrictDelimiter := True;
    Paths.DelimitedText := PathEnv;

    Ctx.Out.WriteLnFmt('Total entries: %d', [Paths.Count]);
    Ctx.Out.WriteLn('');

    for I := 0 to Paths.Count - 1 do
    begin
      P := Paths[I];
      if DirectoryExists(P) then
        Ctx.Out.WriteLnFmt('  [%3d] %s', [I + 1, P])
      else
        Ctx.Out.WriteLnFmt('  [%3d] %s (missing)', [I + 1, P]);
    end;
  finally
    Paths.Free;
  end;
end;

function TEnvPathCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := EXIT_OK;

  if Length(AParams) > 0 then
  begin
    if (Length(AParams) = 1) and ((AParams[0] = '--help') or (AParams[0] = '-h')) then
    begin
      Ctx.Out.WriteLn('Usage: fpdev system env path');
      Exit;
    end;

    Ctx.Err.WriteLn('Usage: fpdev system env path');
    Exit(EXIT_USAGE_ERROR);
  end;

  ShowPathEnv(Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'env', 'path'], @CreateEnvPathCommand, []);

end.
