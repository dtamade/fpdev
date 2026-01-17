unit fpdev.cmd.version;

{
  FPDev Version Command

  Displays detailed version and system information.
  Uses centralized version constants from fpdev.version.pas.
}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  sysutils,
  Classes,
  fpdev.utils,
  fpdev.version,
  fpdev.command.intf,
  fpdev.command.registry;

resourcestring
  S_PLATFORM     = 'Platform:    ';
  S_VERSION      = 'Version:     ';
  S_BUILD_TIME   = 'Build Time:  ';
  S_COMPILER     = 'Compiler:    ';
  S_PATH         = 'Executable:  ';
  S_LICENSE      = 'License:     ';
  S_HOMEPAGE     = 'Homepage:    ';

type
  TVersionCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TVersionCommand.Name: string;
begin
  Result := 'version';
end;

function TVersionCommand.Aliases: TStringArray;
begin
  Result := nil; // Aliases registered via GlobalCommandRegistry
end;

function TVersionCommand.FindSub(const AName: string): ICommand;
begin
  // AName parameter not used - no subcommands
  Result := nil; // No subcommands
end;

function TVersionCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := 0;
  // AParams parameter not used - version command ignores arguments

  Ctx.Out.WriteLn;
  Ctx.Out.WriteLn(FPDEV_NAME + ' - ' + FPDEV_DESCRIPTION);
  Ctx.Out.WriteLn('================================================');
  Ctx.Out.WriteLn;
  Ctx.Out.WriteLnFmt(S_VERSION + '%s', [GetFullVersionString]);
  Ctx.Out.WriteLnFmt(S_BUILD_TIME + '%s %s', [FPDEV_BUILD_DATE, FPDEV_BUILD_TIME]);
  Ctx.Out.WriteLnFmt(S_COMPILER + 'Free Pascal %s', [FPDEV_FPC_VERSION]);
  Ctx.Out.WriteLnFmt(S_PLATFORM + '%s-%s', [FPDEV_TARGET_CPU, FPDEV_TARGET_OS]);
  Ctx.Out.WriteLnFmt(S_PATH + '%s', [exepath]);
  Ctx.Out.WriteLn;
  Ctx.Out.WriteLnFmt(S_LICENSE + '%s', [FPDEV_LICENSE]);
  Ctx.Out.WriteLnFmt(S_HOMEPAGE + '%s', [FPDEV_HOMEPAGE]);
  Ctx.Out.WriteLn;
end;

function VersionFactory: ICommand;
begin
  Result := TVersionCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['version'], @VersionFactory, ['-v', '--version']);
end.
