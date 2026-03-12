unit fpdev.project.execflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf,
  fpdev.utils.process;

type
  TProjectProcessRunner = function(
    const AExecutable: string;
    const AParams: SysUtils.TStringArray;
    const AWorkDir: string
  ): TProcessResult of object;

function FindProjectExecutableCore(const ADir: string): string;
function FindProjectTestExecutableCore(const ADir: string): string;
function ParseProjectRunArgsCore(const AArgs: string): SysUtils.TStringArray;

function ExecuteProjectBuildCore(
  const AProjectDir, ATarget: string;
  ARunProcess: TProjectProcessRunner
): Boolean;

function ExecuteProjectTestCore(
  const AProjectDir: string;
  Outp, Errp: IOutput;
  ARunProcess: TProjectProcessRunner
): Boolean;

function ExecuteProjectRunCore(
  const AProjectDir, AArgs: string;
  Outp, Errp: IOutput;
  ARunProcess: TProjectProcessRunner
): Boolean;

implementation

uses
  Classes,
  fpdev.i18n,
  fpdev.i18n.strings;

function FindFirstProjectFile(const ADir, APattern: string): string;
var
  SR: TSearchRec;
begin
  Result := '';

  if FindFirst(ADir + PathDelim + APattern, faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        Result := ADir + PathDelim + SR.Name;
        Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function FindProjectTestExecutableCore(const ADir: string): string;
var
  SR: TSearchRec;
  TestPattern: string;
begin
  Result := '';

  if not DirectoryExists(ADir) then
    Exit;

  {$IFDEF MSWINDOWS}
  TestPattern := ADir + PathDelim + 'test*.exe';
  {$ELSE}
  TestPattern := ADir + PathDelim + 'test*';
  {$ENDIF}

  if FindFirst(TestPattern, faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        Result := ADir + PathDelim + SR.Name;
        {$IFNDEF MSWINDOWS}
        if (ExtractFileExt(SR.Name) = '') or (ExtractFileExt(SR.Name) = '.lpr') then
        begin
          if ExtractFileExt(SR.Name) = '.lpr' then
            Result := ADir + PathDelim + ChangeFileExt(SR.Name, '');

          if FileExists(Result) then
            Break
          else
            Result := '';
        end;
        {$ELSE}
        Break;
        {$ENDIF}
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function FindProjectExecutableCore(const ADir: string): string;
var
  SR: TSearchRec;
begin
  Result := '';

  if not DirectoryExists(ADir) then
    Exit;

  {$IFDEF MSWINDOWS}
  if FindFirst(ADir + PathDelim + '*.exe', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        Result := ADir + PathDelim + SR.Name;
        Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  {$ELSE}
  if FindFirst(ADir + PathDelim + '*.lpr', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        Result := ADir + PathDelim + ChangeFileExt(SR.Name, '');
        if FileExists(Result) then
          Break
        else
          Result := '';
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  {$ENDIF}
end;

function ParseProjectRunArgsCore(const AArgs: string): SysUtils.TStringArray;
var
  Args: TStringList;
  Index: Integer;
begin
  Result := Default(SysUtils.TStringArray);
  SetLength(Result, 0);
  if Trim(AArgs) = '' then
    Exit;

  Args := TStringList.Create;
  try
    ExtractStrings([' '], [], PChar(AArgs), Args);
    SetLength(Result, Args.Count);
    for Index := 0 to Args.Count - 1 do
      Result[Index] := Args[Index];
  finally
    Args.Free;
  end;
end;

function ExecuteProjectBuildCore(
  const AProjectDir, ATarget: string;
  ARunProcess: TProjectProcessRunner
): Boolean;
var
  FoundLPI: string;
  FoundLPR: string;
  Params: SysUtils.TStringArray;
  LResult: TProcessResult;
begin
  Result := False;

  if (not DirectoryExists(AProjectDir)) or (not Assigned(ARunProcess)) then
    Exit;

  FoundLPI := FindFirstProjectFile(AProjectDir, '*.lpi');
  if FoundLPI <> '' then
  begin
    SetLength(Params, 0);
    if ATarget <> '' then
    begin
      SetLength(Params, 2);
      Params[0] := FoundLPI;
      Params[1] := '--cpu=' + ATarget;
    end
    else
    begin
      SetLength(Params, 1);
      Params[0] := FoundLPI;
    end;

    LResult := ARunProcess('lazbuild', Params, AProjectDir);
    Exit(LResult.Success);
  end;

  FoundLPR := FindFirstProjectFile(AProjectDir, '*.lpr');
  if FoundLPR <> '' then
  begin
    SetLength(Params, 1);
    Params[0] := ExtractFileName(FoundLPR);
    LResult := ARunProcess('fpc', Params, AProjectDir);
    Exit(LResult.Success);
  end;

  if FileExists(AProjectDir + PathDelim + 'Makefile') then
  begin
    SetLength(Params, 0);
    LResult := ARunProcess('make', Params, AProjectDir);
    Exit(LResult.Success);
  end;
end;

function ExecuteProjectTestCore(
  const AProjectDir: string;
  Outp, Errp: IOutput;
  ARunProcess: TProjectProcessRunner
): Boolean;
var
  FoundExe: string;
  Params: SysUtils.TStringArray;
  LResult: TProcessResult;
begin
  Result := False;

  if not DirectoryExists(AProjectDir) then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_DIR_NOT_FOUND, [AProjectDir]));
    Exit;
  end;

  if not Assigned(ARunProcess) then
    Exit;

  FoundExe := FindProjectTestExecutableCore(AProjectDir);
  if FoundExe = '' then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_NO_TEST_FOUND, [AProjectDir]));
    WriteLine(Errp, _(CMD_PROJECT_TEST_NOTE));
    Exit;
  end;

  WriteLine(Outp, _Fmt(CMD_PROJECT_RUNNING_TESTS, [ExtractFileName(FoundExe)]));
  SetLength(Params, 0);
  LResult := ARunProcess(ExpandFileName(FoundExe), Params, AProjectDir);
  Result := LResult.Success;

  if Result then
    WriteLine(Outp, _(CMD_PROJECT_TEST_PASSED))
  else
    WriteLine(Errp, _Fmt(CMD_PROJECT_TEST_FAILED, [IntToStr(LResult.ExitCode)]));
end;

function ExecuteProjectRunCore(
  const AProjectDir, AArgs: string;
  Outp, Errp: IOutput;
  ARunProcess: TProjectProcessRunner
): Boolean;
var
  FoundExe: string;
  Params: SysUtils.TStringArray;
  LResult: TProcessResult;
begin
  Result := False;

  if not DirectoryExists(AProjectDir) then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_DIR_NOT_FOUND, [AProjectDir]));
    Exit;
  end;

  if not Assigned(ARunProcess) then
    Exit;

  FoundExe := FindProjectExecutableCore(AProjectDir);
  if FoundExe = '' then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_NO_EXECUTABLE, [AProjectDir]));
    Exit;
  end;

  Params := ParseProjectRunArgsCore(AArgs);
  LResult := ARunProcess(ExpandFileName(FoundExe), Params, AProjectDir);
  Result := LResult.Success;

  if not Result then
    WriteLine(Errp, _(MSG_WARNING) + ': ' + _Fmt(CMD_PROJECT_EXIT_CODE, [IntToStr(LResult.ExitCode)]));

  if Outp = nil then;
end;

end.
