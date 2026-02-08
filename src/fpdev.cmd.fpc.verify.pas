unit fpdev.cmd.fpc.verify;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpdev.command.intf, fpdev.fpc.verify;

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
  fpdev.command.registry, fpdev.cmd.utils;

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
  if AName <> '' then;  // Unused parameter
end;

function TFPCVerifyCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  Verifier: TFPCVerifier;
  FPCPath, Version: string;
begin
  Result := 1;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if (Ctx <> nil) and (Ctx.Out <> nil) then
    begin
      Ctx.Out.WriteLn('Usage: fpdev fpc verify <version>');
      Ctx.Out.WriteLn('Example: fpdev fpc verify 3.2.2');
    end
    else
    begin
      WriteLn('Usage: fpdev fpc verify <version>');
      WriteLn('Example: fpdev fpc verify 3.2.2');
    end;
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    if (Ctx <> nil) and (Ctx.Err <> nil) then
    begin
      Ctx.Err.WriteLn('Usage: fpdev fpc verify <version>');
      Ctx.Err.WriteLn('Example: fpdev fpc verify 3.2.2');
    end
    else
    begin
      WriteLn('Usage: fpdev fpc verify <version>');
      WriteLn('Example: fpdev fpc verify 3.2.2');
    end;
    Exit;
  end;

  Version := AParams[0];

  // Assume FPC is in standard location
  FPCPath := GetUserDir + '.fpdev' + PathDelim + 'fpc' + PathDelim + Version + PathDelim + 'bin' + PathDelim + 'fpc';
  {$IFDEF WINDOWS}
  FPCPath := FPCPath + '.exe';
  {$ENDIF}

  if not FileExists(FPCPath) then
  begin
    WriteLn('Error: FPC ', Version, ' not found at: ', FPCPath);
    WriteLn('Please install it first using: fpdev fpc install ', Version);
    Exit;
  end;

  Verifier := TFPCVerifier.Create;
  try
    WriteLn('Verifying FPC ', Version, '...');
    WriteLn;

    // Verify version
    WriteLn('[1/3] Checking version...');
    if not Verifier.VerifyVersion(FPCPath, Version) then
    begin
      WriteLn('FAIL: Version check failed');
      WriteLn('Error: ', Verifier.GetLastError);
      Exit;
    end;
    WriteLn('PASS: Version verified');
    WriteLn;

    // Compile hello world
    WriteLn('[2/3] Compiling hello world test...');
    if not Verifier.CompileHelloWorld(FPCPath) then
    begin
      WriteLn('FAIL: Hello world compilation failed');
      WriteLn('Error: ', Verifier.GetLastError);
      Exit;
    end;
    WriteLn('PASS: Hello world compiled successfully');
    WriteLn;

    // Check metadata
    WriteLn('[3/3] Checking metadata...');
    if FileExists(GetUserDir + '.fpdev' + PathDelim + 'fpc' + PathDelim + Version + PathDelim + '.fpdev-meta.json') then
      WriteLn('PASS: Metadata file exists')
    else
      WriteLn('WARN: Metadata file not found (non-critical)');

    WriteLn;
    WriteLn('Verification complete: FPC ', Version, ' is working correctly');
    Result := 0;

  finally
    Verifier.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc', 'verify'], @CreateFPCVerifyCommand, []);

end.
