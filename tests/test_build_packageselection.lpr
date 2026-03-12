program test_build_packageselection;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.packageselection;

var
  Passed: Integer = 0;
  Failed: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(Passed);
    WriteLn('[PASS] ', AMessage);
  end
  else
  begin
    Inc(Failed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

procedure TestBuildDefaultPackageListCore;
var
  Packages: TStringArray;
begin
  Packages := BuildDefaultPackageListCore;
  Check(Length(Packages) = 15, 'default package list has 15 entries');
  Check(Packages[0] = 'rtl', 'default package list starts with rtl');
  Check(Packages[High(Packages)] = 'paszlib', 'default package list ends with paszlib');
end;

procedure TestCopyBuildPackageSelectionCore;
var
  SourcePackages: TStringArray;
  CopiedPackages: TStringArray;
begin
  SetLength(SourcePackages, 2);
  SourcePackages[0] := 'fcl-base';
  SourcePackages[1] := 'fcl-json';

  CopiedPackages := CopyBuildPackageSelectionCore(SourcePackages);
  SourcePackages[0] := 'changed';

  Check(Length(CopiedPackages) = 2, 'copied selection preserves length');
  Check(CopiedPackages[0] = 'fcl-base', 'copied selection is independent from source');
  Check(CopiedPackages[1] = 'fcl-json', 'copied selection preserves values');
end;

procedure TestResolveBuildPackageOrderCore;
var
  DefaultPackages: TStringArray;
  SelectedPackages: TStringArray;
  Order: TStringArray;
begin
  DefaultPackages := BuildDefaultPackageListCore;
  SetLength(SelectedPackages, 2);
  SelectedPackages[0] := 'fcl-xml';
  SelectedPackages[1] := 'fcl-json';

  Order := ResolveBuildPackageOrderCore(SelectedPackages, DefaultPackages);
  Check(Length(Order) = 2, 'selected package order wins over defaults');
  Check(Order[0] = 'fcl-xml', 'build order keeps selected package ordering');
  Check(Order[1] = 'fcl-json', 'build order keeps selected package tail');

  SetLength(SelectedPackages, 0);
  Order := ResolveBuildPackageOrderCore(SelectedPackages, DefaultPackages);
  Check(Length(Order) = Length(DefaultPackages), 'default order used when no packages selected');
  Check(Order[0] = 'rtl', 'default build order starts with rtl');
end;

begin
  WriteLn('=== Build Package Selection Helper Tests ===');
  TestBuildDefaultPackageListCore;
  TestCopyBuildPackageSelectionCore;
  TestResolveBuildPackageOrderCore;

  WriteLn('Passed: ', Passed);
  WriteLn('Failed: ', Failed);
  if Failed > 0 then
    Halt(1);
end.
