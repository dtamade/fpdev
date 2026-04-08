unit fpdev.cmd.fpc.verify;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  fpdev.command.intf,
  fpdev.exitcodes;

type
  { TFPCVerifyCommand - Verify FPC installation }
  TFPCVerifyCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateFPCVerifyCommand: ICommand;

implementation

uses
  fpdev.command.registry, fpdev.command.utils, fpdev.fpc.manager,
  fpdev.fpc.validator, fpdev.fpc.metadata, fpdev.fpc.installversionflow;

function CreateFPCVerifyCommand: ICommand;
begin
  Result := TFPCVerifyCommand.Create;
end;

{ TFPCVerifyCommand }

function TFPCVerifyCommand.Name: string;
begin
  Result := 'verify';
end;

function TFPCVerifyCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCVerifyCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then; // Suppress unused parameter hint
end;

function TFPCVerifyCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  Manager: fpdev.fpc.manager.TFPCManager;
  InstallPath: string;
  Version: string;
  VerifResult: fpdev.fpc.validator.TVerificationResult;
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_ERROR;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn('Usage: fpdev fpc verify <version>');
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn('Usage: fpdev fpc verify <version>');
    Ctx.Out.WriteLn('Example: fpdev fpc verify 3.2.2');
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    Ctx.Err.WriteLn('Usage: fpdev fpc verify <version>');
    Exit(EXIT_USAGE_ERROR);
  end;

  PositionalCount := CountPositionalArgs(AParams);
  if PositionalCount <> 1 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev fpc verify <version>');
    Ctx.Err.WriteLn('Example: fpdev fpc verify 3.2.2');
    Exit(EXIT_USAGE_ERROR);
  end;

  Version := GetPositionalArg(AParams, 0);

  Manager := fpdev.fpc.manager.TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
  try
    Ctx.Out.WriteLn('Verifying FPC ' + Version + '...');
    Ctx.Out.WriteLn('');

    Ctx.Out.WriteLn('[1/3] Checking version...');
    if not Manager.VerifyInstallation(Version, VerifResult) then
    begin
      if not VerifResult.ExecutableExists then
      begin
        Ctx.Err.WriteLn('FAIL: Version check failed')
      end
      else if (VerifResult.DetectedVersion <> '') and SameText(VerifResult.DetectedVersion, Version) then
      begin
        Ctx.Out.WriteLn('PASS: Version verified');
        Ctx.Out.WriteLn('');
        Ctx.Out.WriteLn('[2/3] Compiling hello world test...');
        Ctx.Err.WriteLn('FAIL: Hello world compilation failed');
      end
      else
      begin
        Ctx.Err.WriteLn('FAIL: Version check failed');
      end;
      if not VerifResult.ExecutableExists then
        Ctx.Err.WriteLn('Please install it first using: fpdev fpc install ' + Version);
      if VerifResult.ErrorMessage <> '' then
        Ctx.Err.WriteLn('Error: ' + VerifResult.ErrorMessage);
      Exit;
    end;
    Ctx.Out.WriteLn('PASS: Version verified');
    Ctx.Out.WriteLn('');

    Ctx.Out.WriteLn('[2/3] Compiling hello world test...');
    Ctx.Out.WriteLn('PASS: Hello world compiled successfully');
    Ctx.Out.WriteLn('');

    Ctx.Out.WriteLn('[3/3] Checking metadata...');
    InstallPath := ResolveInstalledFPCInstallPathCore(
      Manager.GetVersionInstallPath(Version),
      Version
    );
    if HasFPCMetadata(InstallPath) then
      Ctx.Out.WriteLn('PASS: Metadata file exists')
    else
      Ctx.Out.WriteLn('WARN: Metadata file not found (non-critical)');

    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Verification complete: FPC ' + Version + ' is working correctly');
    Result := EXIT_OK;

  finally
    Manager.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc', 'verify'], @CreateFPCVerifyCommand, []);

end.
