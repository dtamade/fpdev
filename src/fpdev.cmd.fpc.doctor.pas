unit fpdev.cmd.fpc.doctor;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.command.intf,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TFPCDoctorCommand }
  TFPCDoctorCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.command.registry, fpdev.command.utils,
  fpdev.fpc.doctor.checks,
  fpdev.fpc.doctor.view;

function TFPCDoctorCommand.Name: string; begin Result := 'doctor'; end;

function TFPCDoctorCommand.Aliases: TStringArray; begin Result := nil; end;
function TFPCDoctorCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;


function TFPCDoctorCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LIssueCount: Integer;
begin
  Result := EXIT_OK;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn(_(HELP_FPC_DOCTOR_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
    WriteFPCDoctorHelpCore(Ctx);
    Exit(EXIT_OK);
  end;

  if Length(AParams) > 0 then
  begin
    Ctx.Err.WriteLn(_(HELP_FPC_DOCTOR_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  LIssueCount := ExecuteFPCDoctorChecksCore(Ctx);
  WriteFPCDoctorSummaryCore(Ctx.Out, LIssueCount);
  if LIssueCount > 0 then
    Result := EXIT_ERROR;
end;


function FPCDoctorFactory: ICommand;
begin
  Result := TFPCDoctorCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','doctor'], @FPCDoctorFactory, []);

end.
