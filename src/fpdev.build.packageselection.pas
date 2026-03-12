unit fpdev.build.packageselection;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function BuildDefaultPackageListCore: TStringArray;
function CopyBuildPackageSelectionCore(const APackages: TStringArray): TStringArray;
function ResolveBuildPackageOrderCore(
  const ASelectedPackages, ADefaultPackages: TStringArray
): TStringArray;

implementation

function BuildDefaultPackageListCore: TStringArray;
begin
  Result := nil;
  SetLength(Result, 15);
  Result[0] := 'rtl';
  Result[1] := 'rtl-extra';
  Result[2] := 'rtl-unicode';
  Result[3] := 'rtl-objpas';
  Result[4] := 'fcl-base';
  Result[5] := 'fcl-db';
  Result[6] := 'fcl-fpcunit';
  Result[7] := 'fcl-image';
  Result[8] := 'fcl-json';
  Result[9] := 'fcl-net';
  Result[10] := 'fcl-passrc';
  Result[11] := 'fcl-process';
  Result[12] := 'fcl-registry';
  Result[13] := 'fcl-xml';
  Result[14] := 'paszlib';
end;

function CopyBuildPackageSelectionCore(const APackages: TStringArray): TStringArray;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(APackages));
  for I := 0 to High(APackages) do
    Result[I] := APackages[I];
end;

function ResolveBuildPackageOrderCore(
  const ASelectedPackages, ADefaultPackages: TStringArray
): TStringArray;
begin
  if Length(ASelectedPackages) > 0 then
    Result := CopyBuildPackageSelectionCore(ASelectedPackages)
  else
    Result := CopyBuildPackageSelectionCore(ADefaultPackages);
end;

end.
