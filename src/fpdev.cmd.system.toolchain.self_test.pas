unit fpdev.cmd.system.toolchain.self_test;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.exitcodes;

type
  TSystemToolchainSelfTestCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateSystemToolchainSelfTestCommand: ICommand;

implementation

uses
  fpdev.toolchain;

function CreateSystemToolchainSelfTestCommand: ICommand;
begin
  Result := TSystemToolchainSelfTestCommand.Create;
end;

function TSystemToolchainSelfTestCommand.Name: string;
begin
  Result := 'self-test';
end;

function TSystemToolchainSelfTestCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TSystemToolchainSelfTestCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TSystemToolchainSelfTestCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  ReportJSON: string;
begin
  Result := EXIT_OK;

  if Length(AParams) > 0 then
  begin
    if (Length(AParams) = 1) and ((AParams[0] = '--help') or (AParams[0] = '-h')) then
    begin
      Ctx.Out.WriteLn('Usage: fpdev system toolchain self-test');
      Exit;
    end;

    Ctx.Err.WriteLn('Usage: fpdev system toolchain self-test');
    Exit(EXIT_USAGE_ERROR);
  end;

  ReportJSON := BuildToolchainReportJSON();
  Ctx.Out.WriteLn(ReportJSON);
  if Pos('"level":"FAIL"', ReportJSON) > 0 then
    Result := EXIT_USAGE_ERROR;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'toolchain', 'self-test'], @CreateSystemToolchainSelfTestCommand, []);

end.
