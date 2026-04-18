unit fpdev.fpc.verifycommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.fpc.types;

type
  TFPCVerifyCommandPlan = record
    Version: string;
  end;

  TFPCVerifyCommandVerifyFunc = function(
    const AVersion: string;
    out AVerifResult: TVerificationResult
  ): Boolean of object;

  TFPCVerifyCommandGetInstallPathFunc = function(const AVersion: string): string of object;
  TFPCVerifyCommandMetadataFunc = function(const AInstallPath: string): Boolean;

function PrepareFPCVerifyCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TFPCVerifyCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteFPCVerifyCommandPlanCore(
  const APlan: TFPCVerifyCommandPlan;
  const AOut, AErr: IOutput;
  AVerifyInstallation: TFPCVerifyCommandVerifyFunc;
  AGetInstallPath: TFPCVerifyCommandGetInstallPathFunc;
  AHasMetadata: TFPCVerifyCommandMetadataFunc
): Integer;

implementation

uses
  SysUtils,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.fpc.installversionflow;

const
  VERIFY_USAGE = 'Usage: fpdev fpc verify <version>';
  VERIFY_EXAMPLE = 'Example: fpdev fpc verify 3.2.2';

procedure WriteVerifyUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(VERIFY_USAGE);
end;

procedure WriteVerifyHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(VERIFY_USAGE);
  AOut.WriteLn(VERIFY_EXAMPLE);
end;

procedure WriteBlankLine(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn('');
end;

function PrepareFPCVerifyCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TFPCVerifyCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TFPCVerifyCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    if Length(AParams) > 1 then
    begin
      WriteVerifyUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;

    WriteVerifyHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteVerifyUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  PositionalCount := CountPositionalArgs(AParams);
  if PositionalCount <> 1 then
  begin
    AShouldExit := True;
    WriteVerifyUsage(AErr);
    if AErr <> nil then
      AErr.WriteLn(VERIFY_EXAMPLE);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.Version := GetPositionalArg(AParams, 0);
end;

function ExecuteFPCVerifyCommandPlanCore(
  const APlan: TFPCVerifyCommandPlan;
  const AOut, AErr: IOutput;
  AVerifyInstallation: TFPCVerifyCommandVerifyFunc;
  AGetInstallPath: TFPCVerifyCommandGetInstallPathFunc;
  AHasMetadata: TFPCVerifyCommandMetadataFunc
): Integer;
var
  InstallPath: string;
  VerifResult: TVerificationResult;
begin
  Result := EXIT_ERROR;

  if not Assigned(AVerifyInstallation) then
    Exit(EXIT_ERROR);

  if AOut <> nil then
  begin
    AOut.WriteLn('Verifying FPC ' + APlan.Version + '...');
    WriteBlankLine(AOut);
    AOut.WriteLn('[1/3] Checking version...');
  end;

  if not AVerifyInstallation(APlan.Version, VerifResult) then
  begin
    if not VerifResult.ExecutableExists then
    begin
      if AErr <> nil then
        AErr.WriteLn('FAIL: Version check failed');
    end
    else if (VerifResult.DetectedVersion <> '') and
            SameText(VerifResult.DetectedVersion, APlan.Version) then
    begin
      if AOut <> nil then
      begin
        AOut.WriteLn('PASS: Version verified');
        WriteBlankLine(AOut);
        AOut.WriteLn('[2/3] Compiling hello world test...');
      end;
      if AErr <> nil then
        AErr.WriteLn('FAIL: Hello world compilation failed');
    end
    else
    begin
      if AErr <> nil then
        AErr.WriteLn('FAIL: Version check failed');
    end;

    if (not VerifResult.ExecutableExists) and (AErr <> nil) then
      AErr.WriteLn('Please install it first using: fpdev fpc install ' + APlan.Version);
    if (VerifResult.ErrorMessage <> '') and (AErr <> nil) then
      AErr.WriteLn('Error: ' + VerifResult.ErrorMessage);
    Exit(EXIT_ERROR);
  end;

  if AOut <> nil then
  begin
    AOut.WriteLn('PASS: Version verified');
    WriteBlankLine(AOut);
    AOut.WriteLn('[2/3] Compiling hello world test...');
    AOut.WriteLn('PASS: Hello world compiled successfully');
    WriteBlankLine(AOut);
    AOut.WriteLn('[3/3] Checking metadata...');
  end;

  InstallPath := '';
  if Assigned(AGetInstallPath) then
    InstallPath := ResolveInstalledFPCInstallPathCore(
      AGetInstallPath(APlan.Version),
      APlan.Version
    );

  if (InstallPath <> '') and Assigned(AHasMetadata) and AHasMetadata(InstallPath) then
  begin
    if AOut <> nil then
      AOut.WriteLn('PASS: Metadata file exists');
  end
  else
  begin
    if AOut <> nil then
      AOut.WriteLn('WARN: Metadata file not found (non-critical)');
  end;

  if AOut <> nil then
  begin
    WriteBlankLine(AOut);
    AOut.WriteLn('Verification complete: FPC ' + APlan.Version + ' is working correctly');
  end;

  Result := EXIT_OK;
end;

end.
