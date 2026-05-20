unit fpdev.cmd.package.source.init;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry;

type
  TPackageSourceInitCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.command.utils,
  fpdev.i18n, fpdev.i18n.strings;

const
  EMPTY_INDEX_JSON =
    '{' + LineEnding +
    '  "packages": []' + LineEnding +
    '}' + LineEnding;

function TPackageSourceInitCommand.Name: string; begin Result := 'init'; end;
function TPackageSourceInitCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageSourceInitCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageSourceInitFactory: ICommand;
begin
  Result := TPackageSourceInitCommand.Create;
end;

function TPackageSourceInitCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  TargetDir, IndexPath: string;
  SL: TStringList;
begin
  Result := 0;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Ctx.Out <> nil then
    begin
      Ctx.Out.WriteLn('Usage: fpdev package source init [path]');
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Initialize a package source directory with an empty index.json.');
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Options:');
      Ctx.Out.WriteLn('  --help, -h       Show this help message');
    end;
    Exit(0);
  end;

  TargetDir := Trim(GetPositionalArg(AParams, 0));
  if TargetDir = '' then
    TargetDir := GetCurrentDir;

  if not DirectoryExists(TargetDir) then
    ForceDirectories(TargetDir);

  IndexPath := IncludeTrailingPathDelimiter(TargetDir) + 'index.json';

  if FileExists(IndexPath) then
  begin
    if Ctx.Err <> nil then
      Ctx.Err.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(MSG_PKG_SOURCE_INIT_EXISTS, [IndexPath]));
    Exit(1);
  end;

  SL := TStringList.Create;
  try
    SL.Text := EMPTY_INDEX_JSON;
    SL.SaveToFile(IndexPath);
  finally
    SL.Free;
  end;

  if Ctx.Out <> nil then
  begin
    Ctx.Out.WriteLn(_Fmt(MSG_PKG_SOURCE_INIT_OK, [IndexPath]));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Next steps:');
    Ctx.Out.WriteLn('  fpdev package source publish --index=' + IndexPath + ' --name=<pkg> --version=<ver> --url=<url>');
    Ctx.Out.WriteLn('  fpdev package repo add <name> file://' + IndexPath);
    Ctx.Out.WriteLn('  fpdev package repo update');
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','source','init'], @PackageSourceInitFactory, []);

end.
