unit fpdev.package.semver;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.exitcodes;

type
  TPackageSemanticVersion = record
    Valid: Boolean;
    Major: Integer;
    Minor: Integer;
    Patch: Integer;
    PreRelease: string;
  end;

function ParsePackageSemanticVersion(const AVersion: string): TPackageSemanticVersion;
function ComparePackageVersions(const AVersion1, AVersion2: string): Integer;
function PackageVersionSatisfiesConstraint(const AVersion, AConstraint: string): Boolean;

implementation

function ParsePackageSemanticVersion(const AVersion: string): TPackageSemanticVersion;
var
  Parts: TStringArray;
  PreReleaseParts: TStringArray;
  VersionPart: string;
  Code: Integer;
  i, DotCount: Integer;
begin
  Parts := nil;
  PreReleaseParts := nil;

  Result.Valid := False;
  Result.Major := 0;
  Result.Minor := 0;
  Result.Patch := 0;
  Result.PreRelease := '';

  if AVersion = '' then
    Exit;

  SetLength(PreReleaseParts, 0);
  if Pos('-', AVersion) > 0 then
  begin
    SetLength(PreReleaseParts, 2);
    PreReleaseParts[0] := Copy(AVersion, 1, Pos('-', AVersion) - 1);
    PreReleaseParts[1] := Copy(AVersion, Pos('-', AVersion) + 1, Length(AVersion));
    VersionPart := PreReleaseParts[0];
    Result.PreRelease := PreReleaseParts[1];
  end
  else
    VersionPart := AVersion;

  SetLength(Parts, 0);
  DotCount := 0;
  for i := 1 to Length(VersionPart) do
    if VersionPart[i] = '.' then
      Inc(DotCount);

  SetLength(Parts, DotCount + 1);
  if DotCount = 0 then
  begin
    Parts[0] := VersionPart;
  end
  else
  begin
    i := 0;
    while Pos('.', VersionPart) > 0 do
    begin
      Parts[i] := Copy(VersionPart, 1, Pos('.', VersionPart) - 1);
      Delete(VersionPart, 1, Pos('.', VersionPart));
      Inc(i);
    end;
    Parts[i] := VersionPart;
  end;

  if Length(Parts) >= 1 then
  begin
    Val(Parts[0], Result.Major, Code);
    if Code <> 0 then
      Exit;
  end;

  if Length(Parts) >= 2 then
  begin
    Val(Parts[1], Result.Minor, Code);
    if Code <> 0 then
      Exit;
  end;

  if Length(Parts) >= 3 then
  begin
    Val(Parts[2], Result.Patch, Code);
    if Code <> 0 then
      Exit;
  end;

  Result.Valid := True;
end;

function ComparePackageVersions(const AVersion1, AVersion2: string): Integer;
var
  V1, V2: TPackageSemanticVersion;
begin
  V1 := ParsePackageSemanticVersion(AVersion1);
  V2 := ParsePackageSemanticVersion(AVersion2);

  if not V1.Valid and not V2.Valid then
    Exit(EXIT_OK);
  if not V1.Valid then
    Exit(-1);
  if not V2.Valid then
    Exit(EXIT_ERROR);

  if V1.Major < V2.Major then
    Exit(-1);
  if V1.Major > V2.Major then
    Exit(EXIT_ERROR);

  if V1.Minor < V2.Minor then
    Exit(-1);
  if V1.Minor > V2.Minor then
    Exit(EXIT_ERROR);

  if V1.Patch < V2.Patch then
    Exit(-1);
  if V1.Patch > V2.Patch then
    Exit(EXIT_ERROR);

  if (V1.PreRelease = '') and (V2.PreRelease <> '') then
    Exit(EXIT_ERROR);
  if (V1.PreRelease <> '') and (V2.PreRelease = '') then
    Exit(-1);

  if V1.PreRelease < V2.PreRelease then
    Exit(-1);
  if V1.PreRelease > V2.PreRelease then
    Exit(EXIT_ERROR);

  Result := 0;
end;

function PackageVersionSatisfiesConstraint(const AVersion, AConstraint: string): Boolean;
var
  V, ConstraintV: TPackageSemanticVersion;
  Op: string;
  ConstraintVersion: string;
  Cmp: Integer;
begin
  Result := False;

  if (AConstraint = '') or (AConstraint = '*') then
    Exit(True);

  V := ParsePackageSemanticVersion(AVersion);
  if not V.Valid then
    Exit(False);

  if (Length(AConstraint) >= 2) and (AConstraint[1] in ['>', '<', '=', '^', '~']) then
  begin
    if (AConstraint[1] = '>') and (AConstraint[2] = '=') then
    begin
      Op := '>=';
      ConstraintVersion := Copy(AConstraint, 3, Length(AConstraint));
    end
    else if (AConstraint[1] = '<') and (AConstraint[2] = '=') then
    begin
      Op := '<=';
      ConstraintVersion := Copy(AConstraint, 3, Length(AConstraint));
    end
    else if AConstraint[1] = '>' then
    begin
      Op := '>';
      ConstraintVersion := Copy(AConstraint, 2, Length(AConstraint));
    end
    else if AConstraint[1] = '<' then
    begin
      Op := '<';
      ConstraintVersion := Copy(AConstraint, 2, Length(AConstraint));
    end
    else if AConstraint[1] = '=' then
    begin
      Op := '=';
      ConstraintVersion := Copy(AConstraint, 2, Length(AConstraint));
    end
    else if AConstraint[1] = '^' then
    begin
      Op := '^';
      ConstraintVersion := Copy(AConstraint, 2, Length(AConstraint));
    end
    else if AConstraint[1] = '~' then
    begin
      Op := '~';
      ConstraintVersion := Copy(AConstraint, 2, Length(AConstraint));
    end
    else
    begin
      Op := '=';
      ConstraintVersion := AConstraint;
    end;
  end
  else
  begin
    Op := '=';
    ConstraintVersion := AConstraint;
  end;

  ConstraintV := ParsePackageSemanticVersion(ConstraintVersion);
  if not ConstraintV.Valid then
    Exit(False);

  Cmp := ComparePackageVersions(AVersion, ConstraintVersion);

  if Op = '=' then
    Result := Cmp = 0
  else if Op = '>' then
    Result := Cmp > 0
  else if Op = '<' then
    Result := Cmp < 0
  else if Op = '>=' then
    Result := Cmp >= 0
  else if Op = '<=' then
    Result := Cmp <= 0
  else if Op = '^' then
    Result := (V.Major = ConstraintV.Major) and (Cmp >= 0)
  else if Op = '~' then
    Result := (V.Major = ConstraintV.Major) and (V.Minor = ConstraintV.Minor) and (Cmp >= 0)
  else
    Result := False;
end;

end.
