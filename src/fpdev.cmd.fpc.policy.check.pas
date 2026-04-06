unit fpdev.cmd.fpc.policy.check;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.exitcodes;

type
  TFPCPolicyCheckCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateFPCPolicyCheckCommand: ICommand;

implementation

uses
  fpdev.toolchain,
  fpdev.command.utils;

function CreateFPCPolicyCheckCommand: ICommand;
begin
  Result := TFPCPolicyCheckCommand.Create;
end;

function TFPCPolicyCheckCommand.Name: string;
begin
  Result := 'check';
end;

function TFPCPolicyCheckCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCPolicyCheckCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TFPCPolicyCheckCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  StatusText: string;
  ReasonText: string;
  MinVersion: string;
  RecommendedVersion: string;
  CurrentVersion: string;
  SourceVersion: string;
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_OK;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn('Usage: fpdev fpc policy check [source-version]');
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn('Usage: fpdev fpc policy check [source-version]');
    Exit;
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    Ctx.Err.WriteLn('Usage: fpdev fpc policy check [source-version]');
    Exit(EXIT_USAGE_ERROR);
  end;

  PositionalCount := CountPositionalArgs(AParams);
  if PositionalCount > 1 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev fpc policy check [source-version]');
    Exit(EXIT_USAGE_ERROR);
  end;

  if PositionalCount = 1 then
    SourceVersion := GetPositionalArg(AParams, 0)
  else
    SourceVersion := 'main';

  if not CheckFPCVersionPolicy(
    SourceVersion,
    StatusText,
    ReasonText,
    MinVersion,
    RecommendedVersion,
    CurrentVersion
  ) then
    Result := EXIT_USAGE_ERROR;

  Ctx.Out.WriteLnFmt(
    'Policy %s: src=%s current=%s min=%s rec=%s reason=%s',
    [StatusText, SourceVersion, CurrentVersion, MinVersion, RecommendedVersion, ReasonText]
  );
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc', 'policy', 'check'], @CreateFPCPolicyCheckCommand, []);

end.
