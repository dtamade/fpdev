unit fpdev.toolchain.extract;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, zipper, fpdev.utils.fs;

// Extract ZIP to target directory (auto-create directory), returns True on success
function ZipExtract(const AArchive, ADestDir: string; out AErr: string): boolean;

implementation

function ZipExtract(const AArchive, ADestDir: string; out AErr: string): boolean;
var
  Z: TUnZipper;
begin
  Result := False;
  AErr := '';
  if (AArchive='') or (not FileExists(AArchive)) then
  begin
    AErr := 'archive not found';
    Exit(False);
  end;
  if ADestDir='' then
  begin
    AErr := 'dest dir is empty';
    Exit(False);
  end;
  if not DirectoryExists(ADestDir) then
    if not EnsureDir(ADestDir) then
    begin
      AErr := 'cannot create dest dir';
      Exit(False);
    end;
  Z := TUnZipper.Create;
  try
    Z.FileName := AArchive;
    Z.OutputPath := IncludeTrailingPathDelimiter(ADestDir);
    try
      Z.Examine;
      Z.UnZipAllFiles;
      Result := True;
    except
      on E: Exception do begin AErr := E.Message; Result := False; end;
    end;
  finally
    Z.Free;
  end;
end;

end.

