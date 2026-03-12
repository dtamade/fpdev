unit fpdev.cmd.env.vars;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.exitcodes;

type
  TEnvVarsCommand = class(TInterfacedObject, ICommand)
  private
    function GetEnvVar(const AName: string): string;
    procedure ShowVars(const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateEnvVarsCommand: ICommand;

implementation

function CreateEnvVarsCommand: ICommand;
begin
  Result := TEnvVarsCommand.Create;
end;

function TEnvVarsCommand.Name: string;
begin
  Result := 'vars';
end;

function TEnvVarsCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TEnvVarsCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TEnvVarsCommand.GetEnvVar(const AName: string): string;
begin
  Result := GetEnvironmentVariable(AName);
  if Result = '' then
    Result := '(not set)';
end;

procedure TEnvVarsCommand.ShowVars(const Ctx: IContext);
begin
  Ctx.Out.WriteLn('FPC/Lazarus Environment Variables');
  Ctx.Out.WriteLn('==================================');
  Ctx.Out.WriteLn('');

  Ctx.Out.WriteLn('FPC Variables:');
  Ctx.Out.WriteLn('  FPCDIR:       ' + GetEnvVar('FPCDIR'));
  Ctx.Out.WriteLn('  FPCSRCDIR:    ' + GetEnvVar('FPCSRCDIR'));
  Ctx.Out.WriteLn('  FPCVER:       ' + GetEnvVar('FPCVER'));
  Ctx.Out.WriteLn('  FPCOPT:       ' + GetEnvVar('FPCOPT'));
  Ctx.Out.WriteLn('  PP:           ' + GetEnvVar('PP'));
  Ctx.Out.WriteLn('  FPCMAKE:      ' + GetEnvVar('FPCMAKE'));
  Ctx.Out.WriteLn('');

  Ctx.Out.WriteLn('Lazarus Variables:');
  Ctx.Out.WriteLn('  LAZARUSDIR:   ' + GetEnvVar('LAZARUSDIR'));
  Ctx.Out.WriteLn('  LAZBUILD:     ' + GetEnvVar('LAZBUILD'));
  Ctx.Out.WriteLn('  LCL_PLATFORM: ' + GetEnvVar('LCL_PLATFORM'));
  Ctx.Out.WriteLn('');

  Ctx.Out.WriteLn('Cross-Compilation Variables:');
  Ctx.Out.WriteLn('  CPU_TARGET:   ' + GetEnvVar('CPU_TARGET'));
  Ctx.Out.WriteLn('  OS_TARGET:    ' + GetEnvVar('OS_TARGET'));
  Ctx.Out.WriteLn('  CROSSOPT:     ' + GetEnvVar('CROSSOPT'));
  Ctx.Out.WriteLn('  BINUTILSDIR:  ' + GetEnvVar('BINUTILSDIR'));
end;

function TEnvVarsCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := EXIT_OK;

  if Length(AParams) > 0 then
  begin
    if (Length(AParams) = 1) and ((AParams[0] = '--help') or (AParams[0] = '-h')) then
    begin
      Ctx.Out.WriteLn('Usage: fpdev system env vars');
      Exit;
    end;

    Ctx.Err.WriteLn('Usage: fpdev system env vars');
    Exit(EXIT_USAGE_ERROR);
  end;

  ShowVars(Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'env', 'vars'], @CreateEnvVarsCommand, []);

end.
