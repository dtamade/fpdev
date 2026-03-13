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
  SysUtils, fpdev.resource.repo.types;

type
  TResourceRepoPackageInfoGetter = function(
    const AName, AVersion: string;
    out AInfo: TRepoPackageInfo
  ): Boolean of object;

{ Check if a package matches keyword (name or description) }
function ResourceRepoPackageMatchesKeyword(
  const AName, ADescription, AKeyword: string): Boolean;
function ResourceRepoSearchPackagesCore(const AAllPackages: SysUtils.TStringArray;
  const AKeyword: string; AInfoGetter: TResourceRepoPackageInfoGetter): SysUtils.TStringArray;

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


function ResourceRepoSearchPackagesCore(const AAllPackages: SysUtils.TStringArray;
  const AKeyword: string; AInfoGetter: TResourceRepoPackageInfoGetter): SysUtils.TStringArray;
var
  Info: TRepoPackageInfo;
  Index, Count: Integer;
  Keyword: string;
begin
  Result := nil;
  Count := 0;
  Keyword := LowerCase(AKeyword);

  for Index := 0 to High(AAllPackages) do
  begin
    Info := EmptyRepoPackageInfo;
    if Assigned(AInfoGetter) then
      AInfoGetter(AAllPackages[Index], '', Info);

    if ResourceRepoPackageMatchesKeyword(AAllPackages[Index], Info.Description, Keyword) then
    begin
      SetLength(Result, Count + 1);
      Result[Count] := AAllPackages[Index];
      Inc(Count);
    end;
  end;
end;

end.
