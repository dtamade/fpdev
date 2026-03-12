unit fpdev.package.query.installed;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.package.types;

type
  TInstalledPackageInfoReader = function(const APackageName: string): TPackageInfo of object;

function GetInstalledPackagesCore(const APackageRegistry: string;
  APackageInfoReader: TInstalledPackageInfoReader): TPackageArray;

implementation

function GetInstalledPackagesCore(const APackageRegistry: string;
  APackageInfoReader: TInstalledPackageInfoReader): TPackageArray;
var
  SearchRec: TSearchRec;
  Count: Integer;
begin
  Initialize(Result);
  SetLength(Result, 0);
  Count := 0;

  if FindFirst(APackageRegistry + PathDelim + '*', faDirectory, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory <> 0) and
         (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        SetLength(Result, Count + 1);
        Result[Count] := APackageInfoReader(SearchRec.Name);
        Inc(Count);
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;
end;

end.
