unit fpdev.cmd.fpc.verify;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  fpdev.command.intf,
  fpdev.config.interfaces,
  fpdev.fpc.verify,
  fpdev.paths,
  fpdev.constants,
  fpdev.fpc.utils,
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
  fpdev.command.registry, fpdev.command.utils;

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
  Verifier: TFPCVerifier;
  InstallRoot: string;
  InstallPath: string;
  RootDir: string;
  LegacyInstallPath: string;
  ProjectRoot: string;
  FPCPath: string;
  LegacyFPCPath: string;
  MetaPath: string;
  Version: string;
  Settings: TFPDevSettings;
begin
  Result := EXIT_ERROR;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn('Usage: fpdev fpc verify <version>');
    Ctx.Out.WriteLn('Example: fpdev fpc verify 3.2.2');
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev fpc verify <version>');
    Ctx.Err.WriteLn('Example: fpdev fpc verify 3.2.2');
    Exit;
  end;

  Version := AParams[0];

  // Resolve install path (project scope prefers .fpdev/toolchains; otherwise use install_root/toolchains).
  ProjectRoot := fpdev.fpc.utils.FindProjectRoot(GetCurrentDir);
  if ProjectRoot <> '' then
    InstallPath := ProjectRoot + PathDelim + FPDEV_CONFIG_DIR + PathDelim +
      'toolchains' + PathDelim + 'fpc' + PathDelim + Version
  else
  begin
    InstallRoot := '';
    if (Ctx <> nil) and (Ctx.Config <> nil) then
    begin
      Settings := Ctx.Config.GetSettingsManager.GetSettings;
      InstallRoot := Settings.InstallRoot;
    end;
    if InstallRoot = '' then
      InstallRoot := GetDataRoot;
    InstallPath := BuildFPCInstallDirFromInstallRoot(InstallRoot, Version);
  end;

  FPCPath := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
  {$IFDEF WINDOWS}
  FPCPath := FPCPath + '.exe';
  {$ENDIF}

  if not FileExists(FPCPath) then
  begin
    // Legacy fallback: <root>/fpc/<version>/bin/fpc(.exe)
    RootDir := ExtractFileDir(ExtractFileDir(ExtractFileDir(InstallPath)));
    if RootDir <> '' then
    begin
      LegacyInstallPath := RootDir + PathDelim + 'fpc' + PathDelim + Version;
      LegacyFPCPath := LegacyInstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
      {$IFDEF WINDOWS}
      LegacyFPCPath := LegacyFPCPath + '.exe';
      {$ENDIF}
      if FileExists(LegacyFPCPath) then
      begin
        InstallPath := LegacyInstallPath;
        FPCPath := LegacyFPCPath;
      end;
    end;
  end;

  if not FileExists(FPCPath) then
  begin
    Ctx.Err.WriteLn('Error: FPC ' + Version + ' not found at: ' + FPCPath);
    Ctx.Err.WriteLn('Please install it first using: fpdev fpc install ' + Version);
    Exit;
  end;

  Verifier := TFPCVerifier.Create;
  try
    Ctx.Out.WriteLn('Verifying FPC ' + Version + '...');
    Ctx.Out.WriteLn('');

    // Verify version
    Ctx.Out.WriteLn('[1/3] Checking version...');
    if not Verifier.VerifyVersion(FPCPath, Version) then
    begin
      Ctx.Err.WriteLn('FAIL: Version check failed');
      Ctx.Err.WriteLn('Error: ' + Verifier.GetLastError);
      Exit;
    end;
    Ctx.Out.WriteLn('PASS: Version verified');
    Ctx.Out.WriteLn('');

    // Compile hello world
    Ctx.Out.WriteLn('[2/3] Compiling hello world test...');
    if not Verifier.CompileHelloWorld(FPCPath) then
    begin
      Ctx.Err.WriteLn('FAIL: Hello world compilation failed');
      Ctx.Err.WriteLn('Error: ' + Verifier.GetLastError);
      Exit;
    end;
    Ctx.Out.WriteLn('PASS: Hello world compiled successfully');
    Ctx.Out.WriteLn('');

    // Check metadata
    Ctx.Out.WriteLn('[3/3] Checking metadata...');
    MetaPath := InstallPath + PathDelim + '.fpdev-meta.json';
    if FileExists(MetaPath) then
      Ctx.Out.WriteLn('PASS: Metadata file exists')
    else
      Ctx.Out.WriteLn('WARN: Metadata file not found (non-critical)');

    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Verification complete: FPC ' + Version + ' is working correctly');
    Result := EXIT_OK;

  finally
    Verifier.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc', 'verify'], @CreateFPCVerifyCommand, []);

end.
