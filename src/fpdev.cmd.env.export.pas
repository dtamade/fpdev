unit fpdev.cmd.env.export;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.paths, fpdev.exitcodes;

type
  TEnvExportCommand = class(TInterfacedObject, ICommand)
  private
    procedure ExportEnv(const Ctx: IContext; const AShell: string);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateEnvExportCommand: ICommand;

implementation

function CreateEnvExportCommand: ICommand;
begin
  Result := TEnvExportCommand.Create;
end;

function TEnvExportCommand.Name: string;
begin
  Result := 'export';
end;

function TEnvExportCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TEnvExportCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

procedure TEnvExportCommand.ExportEnv(const Ctx: IContext; const AShell: string);
var
  Shell: string;
  DataRoot, ToolchainsDir: string;
begin
  Shell := LowerCase(AShell);
  if Shell = '' then
  begin
    {$IFDEF WINDOWS}
    Shell := 'cmd';
    {$ELSE}
    Shell := 'bash';
    {$ENDIF}
  end;

  DataRoot := GetDataRoot;
  ToolchainsDir := GetToolchainsDir;

  Ctx.Out.WriteLn('# FPDev Environment Export');
  Ctx.Out.WriteLn('# Generated: ' + DateTimeToStr(Now));
  Ctx.Out.WriteLn('');

  if Shell = 'cmd' then
  begin
    Ctx.Out.WriteLn('set FPDEV_ROOT=' + DataRoot);
    Ctx.Out.WriteLn('set FPDEV_TOOLCHAINS=' + ToolchainsDir);
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('rem Add FPC to PATH (adjust version as needed)');
    Ctx.Out.WriteLn('rem set PATH=%FPDEV_TOOLCHAINS%\fpc\3.2.2\bin;%PATH%');
  end
  else if (Shell = 'ps') or (Shell = 'powershell') then
  begin
    Ctx.Out.WriteLn('$env:FPDEV_ROOT="' + DataRoot + '"');
    Ctx.Out.WriteLn('$env:FPDEV_TOOLCHAINS="' + ToolchainsDir + '"');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('# Add FPC to PATH (adjust version as needed)');
    Ctx.Out.WriteLn('# $env:PATH="$env:FPDEV_TOOLCHAINS\fpc\3.2.2\bin;$env:PATH"');
  end
  else
  begin
    Ctx.Out.WriteLn('export FPDEV_ROOT="' + DataRoot + '"');
    Ctx.Out.WriteLn('export FPDEV_TOOLCHAINS="' + ToolchainsDir + '"');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('# Add FPC to PATH (adjust version as needed)');
    Ctx.Out.WriteLn('# export PATH="$FPDEV_TOOLCHAINS/fpc/3.2.2/bin:$PATH"');
  end;
end;

function TEnvExportCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  Shell: string;
  I: Integer;
begin
  Result := EXIT_OK;

  if (Length(AParams) = 1) and ((AParams[0] = '--help') or (AParams[0] = '-h')) then
  begin
    Ctx.Out.WriteLn('Usage: fpdev system env export [--shell <sh|bash|cmd|ps>]');
    Exit;
  end;

  Shell := '';
  I := 0;
  while I <= High(AParams) do
  begin
    if AParams[I] = '--shell' then
    begin
      if I + 1 > High(AParams) then
      begin
        Ctx.Err.WriteLn('Usage: fpdev system env export [--shell <sh|bash|cmd|ps>]');
        Exit(EXIT_USAGE_ERROR);
      end;
      if AParams[I + 1] = '' then
      begin
        Ctx.Err.WriteLn('Usage: fpdev system env export [--shell <sh|bash|cmd|ps>]');
        Exit(EXIT_USAGE_ERROR);
      end;
      if (Length(AParams[I + 1]) > 0) and (AParams[I + 1][1] = '-') then
      begin
        Ctx.Err.WriteLn('Usage: fpdev system env export [--shell <sh|bash|cmd|ps>]');
        Exit(EXIT_USAGE_ERROR);
      end;
      if Shell <> '' then
      begin
        Ctx.Err.WriteLn('Usage: fpdev system env export [--shell <sh|bash|cmd|ps>]');
        Exit(EXIT_USAGE_ERROR);
      end;
      Shell := AParams[I + 1];
      Inc(I, 2);
      Continue;
    end;

    Ctx.Err.WriteLn('Usage: fpdev system env export [--shell <sh|bash|cmd|ps>]');
    Exit(EXIT_USAGE_ERROR);
  end;

  ExportEnv(Ctx, Shell);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'env', 'export'], @CreateEnvExportCommand, []);

end.
