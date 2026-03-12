unit fpdev.cmd.system.toolchain.import_bundle;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.command.registry;

type
  TSystemToolchainImportBundleCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateSystemToolchainImportBundleCommand: ICommand;

implementation

uses
  fpdev.toolchain.commandflow;

function CreateSystemToolchainImportBundleCommand: ICommand;
begin
  Result := TSystemToolchainImportBundleCommand.Create;
end;

function TSystemToolchainImportBundleCommand.Name: string;
begin
  Result := 'import-bundle';
end;

function TSystemToolchainImportBundleCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TSystemToolchainImportBundleCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TSystemToolchainImportBundleCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := RunToolchainImportBundleCommand(AParams, Ctx.Out, Ctx.Err);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'toolchain', 'import-bundle'], @CreateSystemToolchainImportBundleCommand, []);

end.
