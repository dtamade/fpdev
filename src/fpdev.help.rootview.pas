unit fpdev.help.rootview;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf;

procedure WriteRootHelpCore(const Outp: IOutput);

implementation

uses
  fpdev.help.routing,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteRootHelpCore(const Outp: IOutput);
begin
  Outp.WriteLn('');
  Outp.WriteLn(_(HELP_GLOBAL_USAGE));
  Outp.WriteLn('');
  ListChildrenDynamicCore([], Outp);
  Outp.WriteLn('');
  Outp.WriteLn(_(HELP_MAINTENANCE_SWITCHES));
  Outp.WriteLn('  fpdev system help');
  Outp.WriteLn('  fpdev system version');
  Outp.WriteLn('  fpdev system toolchain check');
  Outp.WriteLn('  fpdev system toolchain self-test');
  Outp.WriteLn('');
  Outp.WriteLn(_(HELP_TIP));
end;

end.
