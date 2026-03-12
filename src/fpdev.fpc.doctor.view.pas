unit fpdev.fpc.doctor.view;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.intf,
  fpdev.output.intf;

procedure WriteFPCDoctorHelpCore(const Ctx: IContext);
procedure WriteFPCDoctorSummaryCore(const AOut: IOutput; AIssueCount: Integer);

implementation

uses
  SysUtils,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteFPCDoctorHelpCore(const Ctx: IContext);
begin
  Ctx.Out.WriteLn(_(HELP_FPC_DOCTOR_USAGE));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_FPC_DOCTOR_DESC));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_FPC_DOCTOR_OPT_HELP));
end;

procedure WriteFPCDoctorSummaryCore(const AOut: IOutput; AIssueCount: Integer);
begin
  AOut.WriteLn('');
  AOut.WriteLn('===========================================');
  if AIssueCount = 0 then
    AOut.WriteLn('All checks passed! Your FPC environment is healthy.')
  else
  begin
    AOut.WriteLn('Found ' + IntToStr(AIssueCount) + ' issue(s) that need attention.');
    AOut.WriteLn('');
    AOut.WriteLn('Suggested fixes:');
    AOut.WriteLn('  - Reinstall broken toolchains: fpdev fpc install <version>');
    AOut.WriteLn('  - Set default toolchain: fpdev fpc use <version>');
  end;
  AOut.WriteLn('===========================================');
end;

end.
