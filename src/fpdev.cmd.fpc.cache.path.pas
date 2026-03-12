unit fpdev.cmd.fpc.cache.path;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf,
  fpdev.i18n.strings, fpdev.exitcodes;

type
  { TFPCCachePathCommand }
  TFPCCachePathCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.registry, fpdev.command.utils, fpdev.paths;

function TFPCCachePathCommand.Name: string; begin Result := 'path'; end;

function TFPCCachePathCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCCachePathCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function FPCCachePathFactory: ICommand;
begin
  Result := TFPCCachePathCommand.Create;
end;

function TFPCCachePathCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LCacheDir: string;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn('Usage: fpdev fpc cache path [options]');
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn('Usage: fpdev fpc cache path [options]');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Show the cache directory path');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Options:');
    Ctx.Out.WriteLn('  -h, --help    Show this help message');
    Exit(EXIT_OK);
  end;

  if Length(AParams) > 0 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev fpc cache path [options]');
    Exit(EXIT_USAGE_ERROR);
  end;

  // Get cache directory
  LCacheDir := GetCacheDir;

  // Output the path
  Ctx.Out.WriteLn(LCacheDir);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','cache','path'], @FPCCachePathFactory, []);

end.
