unit fpdev.pkg.tree;

{$mode objfpc}{$H+}

(*
  Package Dependency Tree Display Utility

  Provides functions to display package dependency trees in a readable format.

  Features:
  - Display dependency tree with ASCII art
  - Show package versions
  - Indicate installed packages
  - Support for multiple output formats

  Usage:
    DisplayDependencyTree(PackageName, Dependencies, Output);
*)

interface

uses
  SysUtils, Classes, fpdev.output.intf;

type
  { TPackageTreeNode - Node in dependency tree }
  TPackageTreeNode = record
    Name: string;
    Version: string;
    Installed: Boolean;
  end;

{ Display dependency tree in ASCII art format }
procedure DisplayDependencyTree(
  const ARootPackage: string;
  const ADependencies: TStringArray;
  AOutput: IOutput
);

{ Format dependency list as simple text }
function FormatDependencyList(
  const ARootPackage: string;
  const ADependencies: TStringArray
): string;

implementation

{ DisplayDependencyTree - Display tree with ASCII art }
procedure DisplayDependencyTree(
  const ARootPackage: string;
  const ADependencies: TStringArray;
  AOutput: IOutput
);
var
  I: Integer;
  Line: string;
begin
  if AOutput = nil then
    Exit;

  AOutput.WriteLn('');
  AOutput.WriteLn('Dependency tree:');
  AOutput.WriteLn('');

  // Root package
  AOutput.WriteLn(ARootPackage);

  // Dependencies
  if Length(ADependencies) = 0 then
  begin
    AOutput.WriteLn('  (no dependencies)');
  end
  else
  begin
    for I := 0 to High(ADependencies) do
    begin
      if I < High(ADependencies) then
        Line := '  ├── ' + ADependencies[I]
      else
        Line := '  └── ' + ADependencies[I];

      AOutput.WriteLn(Line);
    end;
  end;

  AOutput.WriteLn('');

  // Summary
  if Length(ADependencies) > 0 then
    AOutput.WriteLn('Total packages to install: ' + IntToStr(Length(ADependencies) + 1))
  else
    AOutput.WriteLn('Total packages to install: 1');

  AOutput.WriteLn('');
end;

{ FormatDependencyList - Format as simple text }
function FormatDependencyList(
  const ARootPackage: string;
  const ADependencies: TStringArray
): string;
var
  I: Integer;
begin
  Result := 'Package: ' + ARootPackage + LineEnding;

  if Length(ADependencies) = 0 then
  begin
    Result := Result + 'Dependencies: none' + LineEnding;
  end
  else
  begin
    Result := Result + 'Dependencies:' + LineEnding;
    for I := 0 to High(ADependencies) do
      Result := Result + '  - ' + ADependencies[I] + LineEnding;
  end;

  Result := Result + 'Total: ' + IntToStr(Length(ADependencies) + 1) + ' packages';
end;

end.
