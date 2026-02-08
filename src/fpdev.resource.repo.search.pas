{
  fpdev.resource.repo.search.pas

  Helper unit for package search and filtering.
  Extracted from fpdev.resource.repo.pas (B048).

  Part of FPDev project - Phase 4 autonomous batch refactoring.
}
unit fpdev.resource.repo.search;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

{ Check if a package matches keyword (name or description) }
function ResourceRepoPackageMatchesKeyword(
  const AName, ADescription, AKeyword: string): Boolean;

implementation

function ResourceRepoPackageMatchesKeyword(
  const AName, ADescription, AKeyword: string): Boolean;
var
  LowerKeyword: string;
begin
  LowerKeyword := LowerCase(AKeyword);
  Result := (Pos(LowerKeyword, LowerCase(AName)) > 0) or
            (Pos(LowerKeyword, LowerCase(ADescription)) > 0);
end;

end.
