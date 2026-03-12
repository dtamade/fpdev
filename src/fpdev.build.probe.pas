unit fpdev.build.probe;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function BuildManagerDirHasAnyFile(const APath: string): Boolean;
function BuildManagerDirHasAnyEntry(const APath: string): Boolean;
function BuildManagerDirHasAnySubdir(const APath: string): Boolean;
function BuildManagerHasFileLike(
  const ADir: string;
  const APrefixes: array of string;
  const AExts: array of string
): Boolean;

implementation

function BuildManagerDirHasAnyFile(const APath: string): Boolean;
var
  SR: TSearchRec;
begin
  Result := False;
  if not DirectoryExists(APath) then
    Exit(False);

  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) = 0) then
      begin
        Result := True;
        Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function BuildManagerDirHasAnyEntry(const APath: string): Boolean;
var
  SR: TSearchRec;
begin
  Result := False;
  if not DirectoryExists(APath) then
    Exit(False);

  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        Result := True;
        Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function BuildManagerDirHasAnySubdir(const APath: string): Boolean;
var
  SR: TSearchRec;
begin
  Result := False;
  if not DirectoryExists(APath) then
    Exit(False);

  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faDirectory, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) <> 0) then
      begin
        Result := True;
        Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function BuildManagerHasFileLike(
  const ADir: string;
  const APrefixes: array of string;
  const AExts: array of string
): Boolean;
var
  SR: TSearchRec;
  I, J: Integer;
  LName: string;
begin
  Result := False;
  if not DirectoryExists(ADir) then
    Exit(False);

  if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) = 0) then
      begin
        LName := LowerCase(SR.Name);
        for I := Low(APrefixes) to High(APrefixes) do
          for J := Low(AExts) to High(AExts) do
            if (Pos(LowerCase(APrefixes[I]), LName) = 1) and
               (ExtractFileExt(LName) = LowerCase(AExts[J])) then
            begin
              Result := True;
              Break;
            end;
      end;
    until Result or (FindNext(SR) <> 0);
    FindClose(SR);
  end;
end;

end.
