unit fpdev.utils.process;

{$mode objfpc}{$H+}

{
  Process execution utilities for FPDev.
  Consolidates duplicate TProcess patterns from multiple modules.
}

interface

uses
  SysUtils, Classes, Process;

type
  { TProcessResult - Result of process execution }
  TProcessResult = record
    Success: Boolean;
    ExitCode: Integer;
    StdOut: string;
    StdErr: string;
    ErrorMessage: string;
  end;

  { TProcessExecutor - Unified process execution }
  TProcessExecutor = class
  private
    class function ReadStream(AStream: TStream): string;
  public
    // Execute command and wait for completion
    class function Execute(const AExecutable: string;
      const AParams: array of string;
      const AWorkDir: string = ''): TProcessResult;

    // Execute command with timeout (milliseconds, 0 = no timeout)
    class function ExecuteWithTimeout(const AExecutable: string;
      const AParams: array of string;
      const AWorkDir: string;
      ATimeoutMs: Integer): TProcessResult;

    // Execute and return just success/failure
    class function Run(const AExecutable: string;
      const AParams: array of string;
      const AWorkDir: string = ''): Boolean;

    // Execute without capturing output (for long-running builds like make)
    // Output goes directly to terminal, avoids pipe blocking
    class function RunDirect(const AExecutable: string;
      const AParams: array of string;
      const AWorkDir: string = ''): TProcessResult;

    // Execute without capturing output, with custom environment variables
    // AEnvVars format: 'NAME=value' strings
    class function RunDirectWithEnv(const AExecutable: string;
      const AParams: array of string;
      const AWorkDir: string;
      const AEnvVars: array of string): TProcessResult;

    // Launch process without waiting (for GUI apps like IDE)
    // Returns True if process started successfully
    class function Launch(const AExecutable: string;
      const AParams: array of string;
      const AWorkDir: string = ''): Boolean;

    // Execute shell command (uses system shell)
    class function Shell(const ACommand: string;
      const AWorkDir: string = ''): TProcessResult;

    // Check if executable exists in PATH
    class function FindExecutable(const AName: string): string;
  end;

implementation

class function TProcessExecutor.ReadStream(AStream: TStream): string;
const
  BUFFER_SIZE = 4096;
var
  Buffer: array[0..BUFFER_SIZE-1] of Byte;
  BytesRead: LongInt;
  MS: TMemoryStream;
begin
  Result := '';
  if AStream = nil then
    Exit;

  // Initialize buffer before use
  Buffer[0] := 0;
  FillChar(Buffer, SizeOf(Buffer), 0);

  // Use memory stream to collect all data
  MS := TMemoryStream.Create;
  try
    // Read all available data from stream
    repeat
      BytesRead := AStream.Read(Buffer, BUFFER_SIZE);
      if BytesRead > 0 then
        MS.Write(Buffer, BytesRead);
    until BytesRead <= 0;

    // Convert to string
    if MS.Size > 0 then
    begin
      MS.Position := 0;
      SetLength(Result, MS.Size);
      MS.Read(Result[1], MS.Size);
      Result := Trim(Result);
    end;
  finally
    MS.Free;
  end;
end;

class function TProcessExecutor.Execute(const AExecutable: string;
  const AParams: array of string;
  const AWorkDir: string): TProcessResult;
var
  Proc: TProcess;
  i: Integer;
begin
  Result.Success := False;
  Result.ExitCode := -1;
  Result.StdOut := '';
  Result.StdErr := '';
  Result.ErrorMessage := '';

  if AExecutable = '' then
  begin
    Result.ErrorMessage := 'Executable not specified';
    Exit;
  end;

  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AExecutable;

    for i := 0 to High(AParams) do
      Proc.Parameters.Add(AParams[i]);

    if AWorkDir <> '' then
      Proc.CurrentDirectory := AWorkDir;

    Proc.Options := [poWaitOnExit, poUsePipes];

    try
      Proc.Execute;

      Result.ExitCode := Proc.ExitStatus;
      Result.Success := (Result.ExitCode = 0);

      // Read stdout - always attempt to read from pipe
      if Proc.Output <> nil then
        Result.StdOut := ReadStream(Proc.Output);

      // Read stderr - always attempt to read from pipe
      if Proc.Stderr <> nil then
        Result.StdErr := ReadStream(Proc.Stderr);

    except
      on E: Exception do
      begin
        Result.ErrorMessage := E.Message;
        Result.Success := False;
      end;
    end;
  finally
    Proc.Free;
  end;
end;

class function TProcessExecutor.ExecuteWithTimeout(const AExecutable: string;
  const AParams: array of string;
  const AWorkDir: string;
  ATimeoutMs: Integer): TProcessResult;
var
  Proc: TProcess;
  i: Integer;
  StartTime: QWord;
  TimedOut: Boolean;
begin
  Result.Success := False;
  Result.ExitCode := -1;
  Result.StdOut := '';
  Result.StdErr := '';
  Result.ErrorMessage := '';

  if AExecutable = '' then
  begin
    Result.ErrorMessage := 'Executable not specified';
    Exit;
  end;

  if ATimeoutMs <= 0 then
  begin
    Result := Execute(AExecutable, AParams, AWorkDir);
    Exit;
  end;

  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AExecutable;

    for i := 0 to High(AParams) do
      Proc.Parameters.Add(AParams[i]);

    if AWorkDir <> '' then
      Proc.CurrentDirectory := AWorkDir;

    Proc.Options := [poUsePipes];

    try
      Proc.Execute;

      StartTime := GetTickCount64;
      TimedOut := False;

      while Proc.Running do
      begin
        if (GetTickCount64 - StartTime) > QWord(ATimeoutMs) then
        begin
          TimedOut := True;
          Proc.Terminate(1);
          Break;
        end;
        Sleep(50);
      end;

      if TimedOut then
      begin
        Result.ErrorMessage := 'Process timed out after ' + IntToStr(ATimeoutMs) + 'ms';
        Result.ExitCode := -1;
        Result.Success := False;
      end
      else
      begin
        Result.ExitCode := Proc.ExitStatus;
        Result.Success := (Result.ExitCode = 0);
      end;

      // Read stdout - always attempt to read from pipe
      if Proc.Output <> nil then
        Result.StdOut := ReadStream(Proc.Output);

      // Read stderr - always attempt to read from pipe
      if Proc.Stderr <> nil then
        Result.StdErr := ReadStream(Proc.Stderr);

    except
      on E: Exception do
      begin
        Result.ErrorMessage := E.Message;
        Result.Success := False;
      end;
    end;
  finally
    Proc.Free;
  end;
end;

class function TProcessExecutor.Run(const AExecutable: string;
  const AParams: array of string;
  const AWorkDir: string): Boolean;
var
  R: TProcessResult;
begin
  R := Execute(AExecutable, AParams, AWorkDir);
  Result := R.Success;
end;

class function TProcessExecutor.RunDirect(const AExecutable: string;
  const AParams: array of string;
  const AWorkDir: string): TProcessResult;
var
  Proc: TProcess;
  i: Integer;
begin
  Result.Success := False;
  Result.ExitCode := -1;
  Result.StdOut := '';
  Result.StdErr := '';
  Result.ErrorMessage := '';

  if AExecutable = '' then
  begin
    Result.ErrorMessage := 'Executable not specified';
    Exit;
  end;

  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AExecutable;

    for i := 0 to High(AParams) do
      Proc.Parameters.Add(AParams[i]);

    if AWorkDir <> '' then
      Proc.CurrentDirectory := AWorkDir;

    // No poUsePipes - output goes directly to terminal
    // This avoids blocking when the process produces large output
    Proc.Options := [poWaitOnExit];

    try
      Proc.Execute;

      Result.ExitCode := Proc.ExitStatus;
      Result.Success := (Result.ExitCode = 0);

    except
      on E: Exception do
      begin
        Result.ErrorMessage := E.Message;
        Result.Success := False;
      end;
    end;
  finally
    Proc.Free;
  end;
end;

class function TProcessExecutor.RunDirectWithEnv(const AExecutable: string;
  const AParams: array of string;
  const AWorkDir: string;
  const AEnvVars: array of string): TProcessResult;
var
  Proc: TProcess;
  i: Integer;
begin
  Result.Success := False;
  Result.ExitCode := -1;
  Result.StdOut := '';
  Result.StdErr := '';
  Result.ErrorMessage := '';

  if AExecutable = '' then
  begin
    Result.ErrorMessage := 'Executable not specified';
    Exit;
  end;

  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AExecutable;

    for i := 0 to High(AParams) do
      Proc.Parameters.Add(AParams[i]);

    if AWorkDir <> '' then
      Proc.CurrentDirectory := AWorkDir;

    // Add environment variables
    for i := 0 to High(AEnvVars) do
      Proc.Environment.Add(AEnvVars[i]);

    // No poUsePipes - output goes directly to terminal
    Proc.Options := [poWaitOnExit];

    try
      Proc.Execute;

      Result.ExitCode := Proc.ExitStatus;
      Result.Success := (Result.ExitCode = 0);

    except
      on E: Exception do
      begin
        Result.ErrorMessage := E.Message;
        Result.Success := False;
      end;
    end;
  finally
    Proc.Free;
  end;
end;

class function TProcessExecutor.Launch(const AExecutable: string;
  const AParams: array of string;
  const AWorkDir: string): Boolean;
var
  Proc: TProcess;
  i: Integer;
begin
  Result := False;

  if AExecutable = '' then
    Exit;

  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AExecutable;

    for i := 0 to High(AParams) do
      Proc.Parameters.Add(AParams[i]);

    if AWorkDir <> '' then
      Proc.CurrentDirectory := AWorkDir;

    // No poWaitOnExit - launch and return immediately
    // No poUsePipes - let the process handle its own I/O
    Proc.Options := [];

    try
      Proc.Execute;
      Result := True;  // Process started successfully
    except
      Result := False;
    end;
  finally
    Proc.Free;
  end;
end;

class function TProcessExecutor.Shell(const ACommand: string;
  const AWorkDir: string): TProcessResult;
begin
  {$IFDEF MSWINDOWS}
  Result := Execute('cmd.exe', ['/c', ACommand], AWorkDir);
  {$ELSE}
  Result := Execute('/bin/sh', ['-c', ACommand], AWorkDir);
  {$ENDIF}
end;

class function TProcessExecutor.FindExecutable(const AName: string): string;
var
  R: TProcessResult;
begin
  Result := '';

  {$IFDEF MSWINDOWS}
  R := Execute('where', [AName], '');
  {$ELSE}
  R := Execute('which', [AName], '');
  {$ENDIF}

  if R.Success and (R.StdOut <> '') then
  begin
    // Return first line only
    Result := Trim(Copy(R.StdOut, 1, Pos(LineEnding, R.StdOut + LineEnding) - 1));
  end;
end;

end.
