unit fpdev.doctor.runtime;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

function RunDoctorToolVersionCore(
  const AExe: string;
  const AArg: string;
  out AOut: string
): Boolean;
function CheckDoctorWriteableDirCore(
  const ADir: string;
  out AErr: string
): Boolean;

implementation

uses
  fpdev.utils.fs,
  fpdev.utils.process;

function RunDoctorToolVersionCore(
  const AExe: string;
  const AArg: string;
  out AOut: string
): Boolean;
var
  LResult: TProcessResult;
begin
  AOut := '';
  if AArg <> '' then
    LResult := TProcessExecutor.Execute(AExe, [AArg], '')
  else
    LResult := TProcessExecutor.Execute(AExe, [], '');

  if LResult.Success then
  begin
    AOut := LResult.StdOut;
    Result := True;
  end
  else
  begin
    AOut := LResult.ErrorMessage;
    Result := False;
  end;
end;

function CheckDoctorWriteableDirCore(
  const ADir: string;
  out AErr: string
): Boolean;
var
  LPath: string;
  LTest: string;
  LStrings: TStringList;
begin
  Result := False;
  AErr := '';
  LPath := IncludeTrailingPathDelimiter(ADir);
  try
    if not DirectoryExists(LPath) then
      EnsureDir(LPath);
    if not DirectoryExists(LPath) then
    begin
      AErr := 'Cannot create directory';
      Exit(False);
    end;

    LTest := LPath + '.fpdev_write_test.tmp';
    LStrings := TStringList.Create;
    try
      LStrings.Text := 'ok';
      LStrings.SaveToFile(LTest);
      Result := FileExists(LTest);
      DeleteFile(LTest);
    finally
      LStrings.Free;
    end;
  except
    on E: Exception do
    begin
      AErr := E.Message;
      Result := False;
    end;
  end;
end;

end.
