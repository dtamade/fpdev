unit fpdev.output.console;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  {$IFDEF MSWINDOWS}
  Windows,
  {$ENDIF}
  {$IFDEF UNIX}
  termio,
  {$ENDIF}
  fpdev.output.intf;

type
  TConsoleOutput = class(TInterfacedObject, IOutput)
  private
    FUseStdErr: Boolean;
    FColorEnabled: Boolean;
    function GetAnsiColorCode(const AColor: TConsoleColor): string;
    function GetAnsiStyleCode(const AStyle: TConsoleStyle): string;
    function GetAnsiReset: string;
    procedure WriteRaw(const S: string);
  public
    constructor Create(const AUseStdErr: Boolean = False);
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    { Color support }
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    { Semantic output helpers }
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
  end;

implementation

const
  { ANSI escape sequences }
  ESC = #27;
  CSI = ESC + '[';

{$IFDEF MSWINDOWS}
var
  ConsoleInitialized: Boolean = False;
  ConsoleColorEnabled: Boolean = False;
  ConsoleSupportsUTF8: Boolean = False;

{ Detect if running in a modern terminal that supports UTF-8 properly.
  Modern terminals: Windows Terminal, VSCode integrated terminal, etc.
  Legacy terminals: cmd.exe, PowerShell in conhost may have issues with UTF-8. }
function IsModernWindowsTerminal: Boolean;
var
  EnvWT, EnvTerm, EnvVSCode: string;
begin
  Result := False;

  // Windows Terminal sets WT_SESSION environment variable
  EnvWT := GetEnvironmentVariable('WT_SESSION');
  if EnvWT <> '' then
  begin
    Result := True;
    Exit;
  end;

  // VSCode integrated terminal sets TERM_PROGRAM
  EnvVSCode := GetEnvironmentVariable('TERM_PROGRAM');
  if (EnvVSCode = 'vscode') or (Pos('vscode', LowerCase(EnvVSCode)) > 0) then
  begin
    Result := True;
    Exit;
  end;

  // Check for other modern terminal indicators
  EnvTerm := GetEnvironmentVariable('TERM');
  if (EnvTerm = 'xterm-256color') or (EnvTerm = 'xterm') then
  begin
    Result := True;
    Exit;
  end;

  // ConEmu/Cmder sets ConEmuANSI
  if GetEnvironmentVariable('ConEmuANSI') = 'ON' then
  begin
    Result := True;
    Exit;
  end;
end;

procedure InitConsole;
var
  hOut: THandle;
  dwMode: DWORD;
  VTEnabled: Boolean;
begin
  if ConsoleInitialized then Exit;
  ConsoleInitialized := True;
  VTEnabled := False;

  // Enable ANSI escape sequences on Windows 10+ first
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);
  if hOut <> INVALID_HANDLE_VALUE then
  begin
    if GetConsoleMode(hOut, dwMode) then
    begin
      // ENABLE_VIRTUAL_TERMINAL_PROCESSING = $0004
      if SetConsoleMode(hOut, dwMode or $0004) then
      begin
        ConsoleColorEnabled := True;
        VTEnabled := True;
      end;
    end;
  end;

  // Only set UTF-8 code page if:
  // 1. Running in a modern terminal (Windows Terminal, VSCode, etc.), OR
  // 2. Virtual Terminal Processing was successfully enabled (Windows 10+)
  // This prevents I/O errors when outputting non-ASCII characters in legacy terminals
  if IsModernWindowsTerminal or VTEnabled then
  begin
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
    ConsoleSupportsUTF8 := True;
  end
  else
  begin
    // Keep system default code page for legacy terminals
    // This avoids "Disk Full" I/O errors when outputting Chinese/Unicode
    ConsoleSupportsUTF8 := False;
  end;
end;
{$ENDIF}

{$IFDEF UNIX}
function IsTerminal(fd: LongInt): Boolean;
begin
  Result := IsATTY(fd) = 1;
end;
{$ENDIF}

constructor TConsoleOutput.Create(const AUseStdErr: Boolean);
begin
  inherited Create;
  FUseStdErr := AUseStdErr;

  {$IFDEF MSWINDOWS}
  InitConsole;
  FColorEnabled := ConsoleColorEnabled;
  {$ELSE}
  // On Unix, check if stdout/stderr is a terminal
  if AUseStdErr then
    FColorEnabled := IsTerminal(2)  // stderr
  else
    FColorEnabled := IsTerminal(1); // stdout

  // Also check TERM and NO_COLOR environment variables
  if GetEnvironmentVariable('NO_COLOR') <> '' then
    FColorEnabled := False
  else if GetEnvironmentVariable('TERM') = 'dumb' then
    FColorEnabled := False;
  {$ENDIF}
end;

function TConsoleOutput.GetAnsiColorCode(const AColor: TConsoleColor): string;
begin
  case AColor of
    ccDefault:       Result := '39';
    ccBlack:         Result := '30';
    ccRed:           Result := '31';
    ccGreen:         Result := '32';
    ccYellow:        Result := '33';
    ccBlue:          Result := '34';
    ccMagenta:       Result := '35';
    ccCyan:          Result := '36';
    ccWhite:         Result := '37';
    ccBrightBlack:   Result := '90';
    ccBrightRed:     Result := '91';
    ccBrightGreen:   Result := '92';
    ccBrightYellow:  Result := '93';
    ccBrightBlue:    Result := '94';
    ccBrightMagenta: Result := '95';
    ccBrightCyan:    Result := '96';
    ccBrightWhite:   Result := '97';
  end;
end;

function TConsoleOutput.GetAnsiStyleCode(const AStyle: TConsoleStyle): string;
begin
  case AStyle of
    csNone:      Result := '0';
    csBold:      Result := '1';
    csDim:       Result := '2';
    csItalic:    Result := '3';
    csUnderline: Result := '4';
  end;
end;

function TConsoleOutput.GetAnsiReset: string;
begin
  Result := CSI + '0m';
end;

procedure TConsoleOutput.WriteRaw(const S: string);
begin
  if FUseStdErr then
    System.Write(ErrOutput, S)
  else
    System.Write(Output, S);
end;

procedure TConsoleOutput.Write(const S: string);
begin
  WriteRaw(S);
end;

procedure TConsoleOutput.WriteLn;
begin
  if FUseStdErr then
    System.WriteLn(ErrOutput)
  else
    System.WriteLn(Output);
end;

procedure TConsoleOutput.WriteLn(const S: string);
begin
  Write(S);
  WriteLn;
end;

procedure TConsoleOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TConsoleOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TConsoleOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  if FColorEnabled and (AColor <> ccDefault) then
  begin
    WriteRaw(CSI + GetAnsiColorCode(AColor) + 'm');
    WriteRaw(S);
    WriteRaw(GetAnsiReset);
  end
  else
    WriteRaw(S);
end;

procedure TConsoleOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteColored(S, AColor);
  WriteLn;
end;

procedure TConsoleOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  if FColorEnabled then
  begin
    if AStyle <> csNone then
      WriteRaw(CSI + GetAnsiStyleCode(AStyle) + ';' + GetAnsiColorCode(AColor) + 'm')
    else
      WriteRaw(CSI + GetAnsiColorCode(AColor) + 'm');
    WriteRaw(S);
    WriteRaw(GetAnsiReset);
  end
  else
    WriteRaw(S);
end;

procedure TConsoleOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteStyled(S, AColor, AStyle);
  WriteLn;
end;

procedure TConsoleOutput.WriteSuccess(const S: string);
begin
  if FColorEnabled then
  begin
    WriteRaw(CSI + '32m');  // Green
    WriteRaw('✓ ');
    WriteRaw(S);
    WriteRaw(GetAnsiReset);
    WriteLn;
  end
  else
    WriteLn('[OK] ' + S);
end;

procedure TConsoleOutput.WriteError(const S: string);
begin
  if FColorEnabled then
  begin
    WriteRaw(CSI + '1;31m');  // Bold Red
    WriteRaw('✗ ');
    WriteRaw(S);
    WriteRaw(GetAnsiReset);
    WriteLn;
  end
  else
    WriteLn('[ERROR] ' + S);
end;

procedure TConsoleOutput.WriteWarning(const S: string);
begin
  if FColorEnabled then
  begin
    WriteRaw(CSI + '33m');  // Yellow
    WriteRaw('⚠ ');
    WriteRaw(S);
    WriteRaw(GetAnsiReset);
    WriteLn;
  end
  else
    WriteLn('[WARN] ' + S);
end;

procedure TConsoleOutput.WriteInfo(const S: string);
begin
  if FColorEnabled then
  begin
    WriteRaw(CSI + '36m');  // Cyan
    WriteRaw('ℹ ');
    WriteRaw(S);
    WriteRaw(GetAnsiReset);
    WriteLn;
  end
  else
    WriteLn('[INFO] ' + S);
end;

function TConsoleOutput.SupportsColor: Boolean;
begin
  Result := FColorEnabled;
end;

initialization
  {$IFDEF MSWINDOWS}
  InitConsole;
  {$ENDIF}

end.
