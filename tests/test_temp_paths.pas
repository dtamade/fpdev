unit test_temp_paths;

{$mode objfpc}{$H+}

interface

function CreateUniqueTempDir(const APrefix: string = ''): string;
function PathUsesSystemTempRoot(const APath: string): Boolean;
procedure CleanupTempDir(const APath: string);

implementation

uses
  SysUtils, fpdev.utils.fs;

var
  GTempPathSequence: Int64 = 0;

function NormalizePrefix(const APrefix: string): string;
begin
  Result := Trim(APrefix);
  if Result = '' then
    Result := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
end;

function CreateUniqueTempDir(const APrefix: string): string;
var
  Prefix: string;
begin
  Prefix := NormalizePrefix(APrefix);
  Inc(GTempPathSequence);
  Result := IncludeTrailingPathDelimiter(GetTempDir(False))
    + Prefix + '_' + IntToStr(GetTickCount64) + '_' + IntToStr(GTempPathSequence);
  ForceDirectories(Result);
end;

function PathUsesSystemTempRoot(const APath: string): Boolean;
begin
  Result := Pos(IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False))),
    ExpandFileName(APath)) = 1;
end;

procedure CleanupTempDir(const APath: string);
begin
  if (APath <> '') and DirectoryExists(APath) then
    DeleteDirRecursive(APath);
end;

end.
