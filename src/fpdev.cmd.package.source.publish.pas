unit fpdev.cmd.package.source.publish;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry;

type
  TPackageSourcePublishCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.command.utils,
  fpdev.package.source.publishflow,
  fpdev.i18n, fpdev.i18n.strings;

function TPackageSourcePublishCommand.Name: string; begin Result := 'publish'; end;
function TPackageSourcePublishCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageSourcePublishCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageSourcePublishFactory: ICommand;
begin
  Result := TPackageSourcePublishCommand.Create;
end;

function TPackageSourcePublishCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  Plan: TPackageSourcePublishPlan;
  UnknownOption, DepsStr: string;
  DepParts: TStringArray;
  I: Integer;
begin
  Result := 0;
  Initialize(Plan);

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Ctx.Out <> nil then
    begin
      Ctx.Out.WriteLn('Usage: fpdev package source publish --index=<path> --name=<name> --version=<ver> --url=<url>');
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Publish a package entry to a source index.json.');
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Required:');
      Ctx.Out.WriteLn('  --index=<path>       Path to index.json');
      Ctx.Out.WriteLn('  --name=<name>        Package name');
      Ctx.Out.WriteLn('  --version=<ver>      Package version');
      Ctx.Out.WriteLn('  --url=<url>          Download URL');
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Optional:');
      Ctx.Out.WriteLn('  --description=<text> Package description');
      Ctx.Out.WriteLn('  --author=<name>      Author name');
      Ctx.Out.WriteLn('  --license=<id>       License identifier');
      Ctx.Out.WriteLn('  --homepage=<url>     Homepage URL');
      Ctx.Out.WriteLn('  --sha256=<hash>      Expected SHA256 hash');
      Ctx.Out.WriteLn('  --deps=<a,b,c>       Comma-separated dependencies');
    end;
    Exit(0);
  end;

  if FindUnknownOption(AParams,
    ['--index=', '--name=', '--version=', '--url=',
     '--description=', '--author=', '--license=',
     '--homepage=', '--sha256=', '--deps='],
    UnknownOption) then
  begin
    if Ctx.Err <> nil then
      Ctx.Err.WriteLn(_(MSG_ERROR) + ': unknown option: ' + UnknownOption);
    Exit(1);
  end;

  GetFlagValue(AParams, 'index', Plan.IndexPath);
  GetFlagValue(AParams, 'name', Plan.PackageName);
  GetFlagValue(AParams, 'version', Plan.Version);
  GetFlagValue(AParams, 'url', Plan.URL);
  GetFlagValue(AParams, 'description', Plan.Description);
  GetFlagValue(AParams, 'author', Plan.Author);
  GetFlagValue(AParams, 'license', Plan.License);
  GetFlagValue(AParams, 'homepage', Plan.Homepage);
  GetFlagValue(AParams, 'sha256', Plan.Sha256);

  DepsStr := '';
  GetFlagValue(AParams, 'deps', DepsStr);
  if DepsStr <> '' then
  begin
    DepParts := DepsStr.Split(',');
    SetLength(Plan.Dependencies, Length(DepParts));
    for I := 0 to High(DepParts) do
      Plan.Dependencies[I] := Trim(DepParts[I]);
  end;

  if Plan.IndexPath = '' then
  begin
    if Ctx.Err <> nil then
      Ctx.Err.WriteLn(_(MSG_ERROR) + ': --index is required');
    Exit(1);
  end;
  if Plan.PackageName = '' then
  begin
    if Ctx.Err <> nil then
      Ctx.Err.WriteLn(_(MSG_ERROR) + ': --name is required');
    Exit(1);
  end;
  if Plan.Version = '' then
  begin
    if Ctx.Err <> nil then
      Ctx.Err.WriteLn(_(MSG_ERROR) + ': --version is required');
    Exit(1);
  end;
  if Plan.URL = '' then
  begin
    if Ctx.Err <> nil then
      Ctx.Err.WriteLn(_(MSG_ERROR) + ': --url is required');
    Exit(1);
  end;

  Result := ExecutePackageSourcePublishCore(Plan, Ctx.Out, Ctx.Err);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','source','publish'], @PackageSourcePublishFactory, []);

end.
