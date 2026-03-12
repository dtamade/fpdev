unit fpdev.cross.doctor.view;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.intf,
  fpdev.output.intf;

procedure WriteCrossDoctorHelpCore(const Ctx: IContext);
procedure WriteCrossDoctorSummaryCore(const AOut: IOutput; AIssueCount: Integer);

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteCrossDoctorHelpCore(const Ctx: IContext);
begin
  Ctx.Out.WriteLn(_(HELP_CROSS_DOCTOR_USAGE));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_CROSS_DOCTOR_DESC));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_CROSS_DOCTOR_OPT_HELP));
end;

procedure WriteCrossDoctorSummaryCore(const AOut: IOutput; AIssueCount: Integer);
begin
  if AIssueCount >= 0 then;
  AOut.WriteLn('');
  AOut.WriteLn(_(MSG_DOCTOR_COMPLETE));
end;

end.
