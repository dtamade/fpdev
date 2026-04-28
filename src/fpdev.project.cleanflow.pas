unit fpdev.project.cleanflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

function ExecuteProjectCleanCore(
  const AProjectDir: string;
  Outp, Errp: IOutput
): Boolean;

implementation

uses
  SysUtils,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.utils.fs;

function ExecuteProjectCleanCore(
  const AProjectDir: string;
  Outp, Errp: IOutput
): Boolean;
var
  DeletedCount: Integer;
begin
  Result := False;

  if not DirectoryExists(AProjectDir) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_DIR_NOT_FOUND, [AProjectDir]));
    Exit;
  end;

  try
    DeletedCount := CleanBuildArtifacts(AProjectDir, nil, True);
    if Outp <> nil then
      Outp.WriteLn(_Fmt(CMD_PROJECT_CLEANED, [DeletedCount, AProjectDir]));
    Result := True;
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
