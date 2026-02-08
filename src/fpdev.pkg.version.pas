unit fpdev.pkg.version;

{$mode objfpc}{$H+}

(*
  Package Version Constraint Parser and Validator

  Supports semantic versioning constraints:
  - Exact version: "1.2.3"
  - Greater than or equal: ">=1.2.0"
  - Less than or equal: "<=2.0.0"
  - Caret (compatible): "^1.2.0" (allows 1.x.x, but not 2.0.0)
  - Tilde (patch): "~1.2.0" (allows 1.2.x, but not 1.3.0)

  Usage:
    Constraint := ParseVersionConstraint('libfoo>=1.2.0');
    if Constraint.PackageName = 'libfoo' then
      WriteLn('Constraint: ', Constraint.Operator, ' ', Constraint.Version);

    if ValidateVersion('1.2.5', '>=1.2.0') then
      WriteLn('Version 1.2.5 satisfies constraint >=1.2.0');
*)

interface

uses
  SysUtils, Classes, fpdev.exitcodes;

type
  { TVersionConstraintOperator - Version constraint operators }
  TVersionConstraintOperator = (
    vcoExact,      // Exact version match (1.2.3)
    vcoGTE,        // Greater than or equal (>=1.2.0)
    vcoLTE,        // Less than or equal (<=2.0.0)
    vcoCaret,      // Caret/compatible (^1.2.0)
    vcoTilde       // Tilde/patch (~1.2.0)
  );

  { TVersionConstraint - Parsed version constraint }
  TVersionConstraint = record
    PackageName: string;
    ConstraintOp: TVersionConstraintOperator;
    Version: string;
    Valid: Boolean;
  end;

  { TVersionParts - Semantic version parts }
  TVersionParts = record
    Major: Integer;
    Minor: Integer;
    Patch: Integer;
    Valid: Boolean;
  end;

{ Parse version constraint from dependency string }
function ParseVersionConstraint(const ADependency: string): TVersionConstraint;

{ Parse semantic version string into parts }
function ParseVersion(const AVersion: string): TVersionParts;

{ Compare two versions: -1 if V1 < V2, 0 if equal, 1 if V1 > V2 }
function CompareVersions(const AVersion1, AVersion2: string): Integer;

{ Validate if a version satisfies a constraint }
function ValidateVersion(const AVersion, AConstraint: string): Boolean;

{ Extract package name from dependency string (removes version constraint) }
function ExtractPackageName(const ADependency: string): string;

implementation

{ ParseVersionConstraint - Parse dependency string into constraint }
function ParseVersionConstraint(const ADependency: string): TVersionConstraint;
var
  Dep: string;
  Pos: Integer;
begin
  Initialize(Result);
  Result.Valid := False;
  Result.PackageName := '';
  Result.ConstraintOp := vcoExact;
  Result.Version := '';

  Dep := Trim(ADependency);
  if Dep = '' then
    Exit;

  // Check for >= operator
  Pos := System.Pos('>=', Dep);
  if Pos > 0 then
  begin
    Result.PackageName := Trim(Copy(Dep, 1, Pos - 1));
    Result.Version := Trim(Copy(Dep, Pos + 2, Length(Dep)));
    Result.ConstraintOp := vcoGTE;
    Result.Valid := (Result.Version <> '');  // Package name can be empty for constraint-only strings
    Exit;
  end;

  // Check for <= operator
  Pos := System.Pos('<=', Dep);
  if Pos > 0 then
  begin
    Result.PackageName := Trim(Copy(Dep, 1, Pos - 1));
    Result.Version := Trim(Copy(Dep, Pos + 2, Length(Dep)));
    Result.ConstraintOp := vcoLTE;
    Result.Valid := (Result.Version <> '');  // Package name can be empty for constraint-only strings
    Exit;
  end;

  // Check for ^ operator (caret)
  Pos := System.Pos('^', Dep);
  if Pos > 0 then
  begin
    Result.PackageName := Trim(Copy(Dep, 1, Pos - 1));
    Result.Version := Trim(Copy(Dep, Pos + 1, Length(Dep)));
    Result.ConstraintOp := vcoCaret;
    Result.Valid := (Result.Version <> '');  // Package name can be empty for constraint-only strings
    Exit;
  end;

  // Check for ~ operator (tilde)
  Pos := System.Pos('~', Dep);
  if Pos > 0 then
  begin
    Result.PackageName := Trim(Copy(Dep, 1, Pos - 1));
    Result.Version := Trim(Copy(Dep, Pos + 1, Length(Dep)));
    Result.ConstraintOp := vcoTilde;
    Result.Valid := (Result.Version <> '');  // Package name can be empty for constraint-only strings
    Exit;
  end;

  // No operator found - treat as package name only (no version constraint)
  Result.PackageName := Dep;
  Result.Version := '';
  Result.ConstraintOp := vcoExact;
  Result.Valid := True;
end;

{ ParseVersion - Parse semantic version string }
function ParseVersion(const AVersion: string): TVersionParts;
var
  Parts: TStringList;
  Ver: string;
begin
  Initialize(Result);
  Result.Major := 0;
  Result.Minor := 0;
  Result.Patch := 0;
  Result.Valid := False;

  Ver := Trim(AVersion);
  if Ver = '' then
    Exit;

  Parts := TStringList.Create;
  try
    Parts.Delimiter := '.';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := Ver;

    if Parts.Count >= 1 then
      Result.Major := StrToIntDef(Parts[0], 0);

    if Parts.Count >= 2 then
      Result.Minor := StrToIntDef(Parts[1], 0);

    if Parts.Count >= 3 then
      Result.Patch := StrToIntDef(Parts[2], 0);

    Result.Valid := Parts.Count >= 1;
  finally
    Parts.Free;
  end;
end;

{ CompareVersions - Compare two semantic versions }
function CompareVersions(const AVersion1, AVersion2: string): Integer;
var
  V1, V2: TVersionParts;
begin
  Result := 0;

  V1 := ParseVersion(AVersion1);
  V2 := ParseVersion(AVersion2);

  if not V1.Valid or not V2.Valid then
    Exit;

  // Compare major version
  if V1.Major > V2.Major then
    Exit(EXIT_ERROR)
  else if V1.Major < V2.Major then
    Exit(-1);

  // Compare minor version
  if V1.Minor > V2.Minor then
    Exit(EXIT_ERROR)
  else if V1.Minor < V2.Minor then
    Exit(-1);

  // Compare patch version
  if V1.Patch > V2.Patch then
    Exit(EXIT_ERROR)
  else if V1.Patch < V2.Patch then
    Exit(-1);

  // Versions are equal
  Result := 0;
end;

{ ValidateVersion - Check if version satisfies constraint }
function ValidateVersion(const AVersion, AConstraint: string): Boolean;
var
  Constraint: TVersionConstraint;
  Ver, ConstraintVer: TVersionParts;
  Cmp: Integer;
begin
  Result := False;

  // Parse constraint
  Constraint := ParseVersionConstraint(AConstraint);
  if not Constraint.Valid then
    Exit;

  // If no version constraint specified, any version is valid
  if Constraint.Version = '' then
    Exit(True);

  // Parse versions
  Ver := ParseVersion(AVersion);
  ConstraintVer := ParseVersion(Constraint.Version);

  if not Ver.Valid or not ConstraintVer.Valid then
    Exit;

  // Compare based on operator
  Cmp := CompareVersions(AVersion, Constraint.Version);

  case Constraint.ConstraintOp of
    vcoExact:
      Result := (Cmp = 0);

    vcoGTE:
      Result := (Cmp >= 0);

    vcoLTE:
      Result := (Cmp <= 0);

    vcoCaret:
      // ^1.2.0 allows 1.x.x but not 2.0.0
      Result := (Ver.Major = ConstraintVer.Major) and (Cmp >= 0);

    vcoTilde:
      // ~1.2.0 allows 1.2.x but not 1.3.0
      Result := (Ver.Major = ConstraintVer.Major) and
                (Ver.Minor = ConstraintVer.Minor) and
                (Cmp >= 0);
  end;
end;

{ ExtractPackageName - Extract package name from dependency string }
function ExtractPackageName(const ADependency: string): string;
var
  Constraint: TVersionConstraint;
begin
  Constraint := ParseVersionConstraint(ADependency);
  Result := Constraint.PackageName;
end;

end.
