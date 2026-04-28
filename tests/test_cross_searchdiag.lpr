program test_cross_searchdiag;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.cross.searchdiag;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

function ArrayContains(const AValues: TStringArray; const ANeedle: string): Boolean;
var
  Item: string;
begin
  Result := False;
  for Item in AValues do
    if Pos(ANeedle, Item) > 0 then
      Exit(True);
end;

procedure TestBuildCrossSearchLogLinesCore;
var
  Entries: TCrossSearchLogLineArray;
  Lines: TStringArray;
begin
  SetLength(Entries, 2);
  Entries[0].Layer := 1;
  Entries[0].LayerName := 'fpdev-managed';
  Entries[0].Path := '/tmp/cross/bin';
  Entries[0].Prefix := 'arm-linux-gnueabihf-';
  Entries[0].Found := True;

  Entries[1].Layer := 2;
  Entries[1].LayerName := 'system-paths';
  Entries[1].Path := '/usr/bin';
  Entries[1].Prefix := 'arm-linux-gnueabihf-';
  Entries[1].Found := False;

  Lines := BuildCrossSearchLogLinesCore(Entries);

  Check('log helper returns same number of entries',
    Length(Lines) = 2,
    'expected 2 lines, got ' + IntToStr(Length(Lines)));
  Check('log helper formats found entry',
    Lines[0] = '[L1:fpdev-managed] /tmp/cross/bin prefix=arm-linux-gnueabihf- => FOUND',
    'got=' + Lines[0]);
  Check('log helper formats miss entry',
    Lines[1] = '[L2:system-paths] /usr/bin prefix=arm-linux-gnueabihf- => miss',
    'got=' + Lines[1]);
end;

procedure TestBuildCrossDiagnoseLinesCoreFound;
var
  Libs: TStringArray;
  LogLines: TStringArray;
  Lines: TStringArray;
begin
  SetLength(Libs, 2);
  Libs[0] := '/opt/cross/lib';
  Libs[1] := '/usr/arm-linux-gnueabihf/lib';

  SetLength(LogLines, 1);
  LogLines[0] := '[L1:fpdev-managed] /tmp/cross/bin prefix=arm-linux-gnueabihf- => FOUND';

  Lines := BuildCrossDiagnoseLinesCore(
    'arm',
    'linux',
    True,
    1,
    'fpdev-managed',
    '/tmp/cross/bin',
    'arm-linux-gnueabihf-',
    Libs,
    LogLines
  );

  Check('diagnose helper includes target line',
    (Length(Lines) > 0) and (Lines[0] = 'Target: arm-linux'),
    'missing target line');
  Check('diagnose helper includes binutils status',
    ArrayContains(Lines, '[OK] Binutils found (layer 1: fpdev-managed)'),
    'missing found binutils line');
  Check('diagnose helper includes prefix line',
    ArrayContains(Lines, 'Prefix: arm-linux-gnueabihf-'),
    'missing prefix line');
  Check('diagnose helper includes library summary',
    ArrayContains(Lines, '[OK] Libraries found (2 path(s))'),
    'missing libraries summary');
  Check('diagnose helper includes search log section',
    ArrayContains(Lines, 'Search log (1 entries):'),
    'missing search log summary');
end;

procedure TestBuildCrossDiagnoseLinesCoreMissing;
var
  Libs: TStringArray;
  LogLines: TStringArray;
  Lines: TStringArray;
begin
  Libs := nil;
  SetLength(LogLines, 1);
  LogLines[0] := '[L6:config-hints] /tmp/fpc.cfg prefix=(no match) => miss';

  Lines := BuildCrossDiagnoseLinesCore(
    'x86_64',
    'win64',
    False,
    0,
    '',
    '',
    '',
    Libs,
    LogLines
  );

  Check('diagnose helper reports missing binutils',
    ArrayContains(Lines, '[X] Binutils not found'),
    'missing not-found line');
  Check('diagnose helper reports missing libraries',
    ArrayContains(Lines, '[!] No library paths found'),
    'missing no-library line');
  Check('diagnose helper still includes log payload',
    ArrayContains(Lines, '[L6:config-hints] /tmp/fpc.cfg prefix=(no match) => miss'),
    'missing log entry');
end;

begin
  WriteLn('=== Cross Searchdiag Tests ===');

  TestBuildCrossSearchLogLinesCore;
  TestBuildCrossDiagnoseLinesCoreFound;
  TestBuildCrossDiagnoseLinesCoreMissing;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
