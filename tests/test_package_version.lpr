program test_package_version;

{$mode objfpc}{$H+}

{
  Property-Based Tests for Package Version Comparison
  
  Property 8: Version Comparison Correctness
  For any two semantic version strings, the version comparison SHALL correctly 
  determine which is higher, equal, or lower.
  
  Validates: Requirements 5.1
}

uses
  SysUtils, Classes, fpdev.cmd.package, fpdev.package.types;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TotalTests: Integer = 0;

procedure Assert(Condition: Boolean; const TestName: string);
begin
  Inc(TotalTests);
  if Condition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', TestName);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', TestName);
  end;
end;

{ Unit Tests for ParseSemanticVersion }

procedure TestParseSemanticVersion;
var
  V: TSemanticVersion;
begin
  WriteLn('');
  WriteLn('=== ParseSemanticVersion Tests ===');
  
  // Test basic version
  V := ParseSemanticVersion('1.2.3');
  Assert(V.Valid, 'Parse 1.2.3 - Valid');
  Assert(V.Major = 1, 'Parse 1.2.3 - Major');
  Assert(V.Minor = 2, 'Parse 1.2.3 - Minor');
  Assert(V.Patch = 3, 'Parse 1.2.3 - Patch');
  Assert(V.PreRelease = '', 'Parse 1.2.3 - No PreRelease');
  
  // Test version with prerelease
  V := ParseSemanticVersion('2.0.0-alpha');
  Assert(V.Valid, 'Parse 2.0.0-alpha - Valid');
  Assert(V.Major = 2, 'Parse 2.0.0-alpha - Major');
  Assert(V.Minor = 0, 'Parse 2.0.0-alpha - Minor');
  Assert(V.Patch = 0, 'Parse 2.0.0-alpha - Patch');
  Assert(V.PreRelease = 'alpha', 'Parse 2.0.0-alpha - PreRelease');
  
  // Test two-part version
  V := ParseSemanticVersion('1.0');
  Assert(V.Valid, 'Parse 1.0 - Valid');
  Assert(V.Major = 1, 'Parse 1.0 - Major');
  Assert(V.Minor = 0, 'Parse 1.0 - Minor');
  Assert(V.Patch = 0, 'Parse 1.0 - Patch');
  
  // Test single-part version
  V := ParseSemanticVersion('3');
  Assert(V.Valid, 'Parse 3 - Valid');
  Assert(V.Major = 3, 'Parse 3 - Major');
  
  // Test empty version
  V := ParseSemanticVersion('');
  Assert(not V.Valid, 'Parse empty - Invalid');
  
  // Test invalid version
  V := ParseSemanticVersion('abc');
  Assert(not V.Valid, 'Parse abc - Invalid');
end;

{ Unit Tests for CompareVersions }

procedure TestCompareVersions;
begin
  WriteLn('');
  WriteLn('=== CompareVersions Tests ===');
  
  // Equal versions
  Assert(CompareVersions('1.0.0', '1.0.0') = 0, 'Compare 1.0.0 = 1.0.0');
  Assert(CompareVersions('2.3.4', '2.3.4') = 0, 'Compare 2.3.4 = 2.3.4');
  
  // Major version difference
  Assert(CompareVersions('2.0.0', '1.0.0') = 1, 'Compare 2.0.0 > 1.0.0');
  Assert(CompareVersions('1.0.0', '2.0.0') = -1, 'Compare 1.0.0 < 2.0.0');
  
  // Minor version difference
  Assert(CompareVersions('1.2.0', '1.1.0') = 1, 'Compare 1.2.0 > 1.1.0');
  Assert(CompareVersions('1.1.0', '1.2.0') = -1, 'Compare 1.1.0 < 1.2.0');
  
  // Patch version difference
  Assert(CompareVersions('1.0.2', '1.0.1') = 1, 'Compare 1.0.2 > 1.0.1');
  Assert(CompareVersions('1.0.1', '1.0.2') = -1, 'Compare 1.0.1 < 1.0.2');
  
  // PreRelease comparison
  Assert(CompareVersions('1.0.0', '1.0.0-alpha') = 1, 'Compare 1.0.0 > 1.0.0-alpha');
  Assert(CompareVersions('1.0.0-alpha', '1.0.0') = -1, 'Compare 1.0.0-alpha < 1.0.0');
  Assert(CompareVersions('1.0.0-beta', '1.0.0-alpha') = 1, 'Compare 1.0.0-beta > 1.0.0-alpha');
  
  // Invalid versions
  Assert(CompareVersions('', '1.0.0') = -1, 'Compare empty < 1.0.0');
  Assert(CompareVersions('1.0.0', '') = 1, 'Compare 1.0.0 > empty');
  Assert(CompareVersions('', '') = 0, 'Compare empty = empty');
end;

{ Unit Tests for VersionSatisfiesConstraint }

procedure TestVersionSatisfiesConstraint;
begin
  WriteLn('');
  WriteLn('=== VersionSatisfiesConstraint Tests ===');
  
  // Empty/wildcard constraints
  Assert(VersionSatisfiesConstraint('1.0.0', ''), 'Constraint empty - any version');
  Assert(VersionSatisfiesConstraint('1.0.0', '*'), 'Constraint * - any version');
  
  // Exact match
  Assert(VersionSatisfiesConstraint('1.0.0', '1.0.0'), 'Constraint exact match');
  Assert(not VersionSatisfiesConstraint('1.0.1', '1.0.0'), 'Constraint exact no match');
  Assert(VersionSatisfiesConstraint('1.0.0', '=1.0.0'), 'Constraint =1.0.0 match');
  
  // >= constraint
  Assert(VersionSatisfiesConstraint('1.0.0', '>=1.0.0'), 'Constraint >=1.0.0 equal');
  Assert(VersionSatisfiesConstraint('1.0.1', '>=1.0.0'), 'Constraint >=1.0.0 greater');
  Assert(not VersionSatisfiesConstraint('0.9.0', '>=1.0.0'), 'Constraint >=1.0.0 less');
  
  // > constraint
  Assert(VersionSatisfiesConstraint('1.0.1', '>1.0.0'), 'Constraint >1.0.0 greater');
  Assert(not VersionSatisfiesConstraint('1.0.0', '>1.0.0'), 'Constraint >1.0.0 equal');
  Assert(not VersionSatisfiesConstraint('0.9.0', '>1.0.0'), 'Constraint >1.0.0 less');
  
  // <= constraint
  Assert(VersionSatisfiesConstraint('1.0.0', '<=1.0.0'), 'Constraint <=1.0.0 equal');
  Assert(VersionSatisfiesConstraint('0.9.0', '<=1.0.0'), 'Constraint <=1.0.0 less');
  Assert(not VersionSatisfiesConstraint('1.0.1', '<=1.0.0'), 'Constraint <=1.0.0 greater');
  
  // < constraint
  Assert(VersionSatisfiesConstraint('0.9.0', '<1.0.0'), 'Constraint <1.0.0 less');
  Assert(not VersionSatisfiesConstraint('1.0.0', '<1.0.0'), 'Constraint <1.0.0 equal');
  Assert(not VersionSatisfiesConstraint('1.0.1', '<1.0.0'), 'Constraint <1.0.0 greater');
  
  // ^ constraint (compatible - same major)
  Assert(VersionSatisfiesConstraint('1.2.3', '^1.0.0'), 'Constraint ^1.0.0 same major');
  Assert(VersionSatisfiesConstraint('1.0.0', '^1.0.0'), 'Constraint ^1.0.0 exact');
  Assert(not VersionSatisfiesConstraint('2.0.0', '^1.0.0'), 'Constraint ^1.0.0 different major');
  Assert(not VersionSatisfiesConstraint('0.9.0', '^1.0.0'), 'Constraint ^1.0.0 lower');
  
  // ~ constraint (patch - same major.minor)
  Assert(VersionSatisfiesConstraint('1.0.5', '~1.0.0'), 'Constraint ~1.0.0 same minor');
  Assert(VersionSatisfiesConstraint('1.0.0', '~1.0.0'), 'Constraint ~1.0.0 exact');
  Assert(not VersionSatisfiesConstraint('1.1.0', '~1.0.0'), 'Constraint ~1.0.0 different minor');
  Assert(not VersionSatisfiesConstraint('0.9.0', '~1.0.0'), 'Constraint ~1.0.0 lower');
end;

{ Property-Based Tests }

procedure PropertyTestVersionComparisonTransitivity;
var
  i: Integer;
  Versions: array[0..9] of string;
  j, k, l: Integer;
  cmp_jk, cmp_kl, cmp_jl: Integer;
begin
  WriteLn('');
  WriteLn('=== Property Test: Version Comparison Transitivity ===');
  WriteLn('Property 8: For any three versions A, B, C: if A < B and B < C then A < C');
  
  // Generate test versions
  Versions[0] := '0.0.1';
  Versions[1] := '0.1.0';
  Versions[2] := '0.1.1';
  Versions[3] := '1.0.0';
  Versions[4] := '1.0.1';
  Versions[5] := '1.1.0';
  Versions[6] := '1.1.1';
  Versions[7] := '2.0.0';
  Versions[8] := '2.0.0-alpha';
  Versions[9] := '2.0.0-beta';
  
  for i := 1 to 100 do
  begin
    // Pick three random versions
    j := Random(10);
    k := Random(10);
    l := Random(10);
    
    cmp_jk := CompareVersions(Versions[j], Versions[k]);
    cmp_kl := CompareVersions(Versions[k], Versions[l]);
    cmp_jl := CompareVersions(Versions[j], Versions[l]);
    
    // Test transitivity: if j < k and k < l then j < l
    if (cmp_jk < 0) and (cmp_kl < 0) then
    begin
      if cmp_jl >= 0 then
      begin
        Inc(TestsFailed);
        Inc(TotalTests);
        WriteLn('[FAIL] Transitivity violated: ', Versions[j], ' < ', Versions[k], ' < ', Versions[l], ' but ', Versions[j], ' >= ', Versions[l]);
        Exit;
      end;
    end;
    
    // Test transitivity: if j > k and k > l then j > l
    if (cmp_jk > 0) and (cmp_kl > 0) then
    begin
      if cmp_jl <= 0 then
      begin
        Inc(TestsFailed);
        Inc(TotalTests);
        WriteLn('[FAIL] Transitivity violated: ', Versions[j], ' > ', Versions[k], ' > ', Versions[l], ' but ', Versions[j], ' <= ', Versions[l]);
        Exit;
      end;
    end;
  end;
  
  Inc(TestsPassed);
  Inc(TotalTests);
  WriteLn('[PASS] Transitivity property holds for 100 random triplets');
end;

procedure PropertyTestVersionComparisonReflexivity;
var
  i: Integer;
  Versions: array[0..9] of string;
  cmp: Integer;
begin
  WriteLn('');
  WriteLn('=== Property Test: Version Comparison Reflexivity ===');
  WriteLn('Property 8: For any version V: V = V');
  
  Versions[0] := '0.0.1';
  Versions[1] := '0.1.0';
  Versions[2] := '1.0.0';
  Versions[3] := '1.2.3';
  Versions[4] := '2.0.0-alpha';
  Versions[5] := '2.0.0-beta';
  Versions[6] := '2.0.0';
  Versions[7] := '3.2.1';
  Versions[8] := '10.0.0';
  Versions[9] := '100.200.300';
  
  for i := 0 to 9 do
  begin
    cmp := CompareVersions(Versions[i], Versions[i]);
    if cmp <> 0 then
    begin
      Inc(TestsFailed);
      Inc(TotalTests);
      WriteLn('[FAIL] Reflexivity violated: ', Versions[i], ' != ', Versions[i]);
      Exit;
    end;
  end;
  
  Inc(TestsPassed);
  Inc(TotalTests);
  WriteLn('[PASS] Reflexivity property holds for all test versions');
end;

procedure PropertyTestVersionComparisonSymmetry;
var
  i: Integer;
  Versions: array[0..9] of string;
  j, k: Integer;
  cmp_jk, cmp_kj: Integer;
begin
  WriteLn('');
  WriteLn('=== Property Test: Version Comparison Anti-Symmetry ===');
  WriteLn('Property 8: For any versions A, B: if A < B then B > A');
  
  Versions[0] := '0.0.1';
  Versions[1] := '0.1.0';
  Versions[2] := '1.0.0';
  Versions[3] := '1.2.3';
  Versions[4] := '2.0.0-alpha';
  Versions[5] := '2.0.0-beta';
  Versions[6] := '2.0.0';
  Versions[7] := '3.2.1';
  Versions[8] := '10.0.0';
  Versions[9] := '100.200.300';
  
  for i := 1 to 100 do
  begin
    j := Random(10);
    k := Random(10);
    
    cmp_jk := CompareVersions(Versions[j], Versions[k]);
    cmp_kj := CompareVersions(Versions[k], Versions[j]);
    
    // Anti-symmetry: cmp(A,B) = -cmp(B,A)
    if cmp_jk <> -cmp_kj then
    begin
      Inc(TestsFailed);
      Inc(TotalTests);
      WriteLn('[FAIL] Anti-symmetry violated: cmp(', Versions[j], ',', Versions[k], ')=', cmp_jk, ' but cmp(', Versions[k], ',', Versions[j], ')=', cmp_kj);
      Exit;
    end;
  end;
  
  Inc(TestsPassed);
  Inc(TotalTests);
  WriteLn('[PASS] Anti-symmetry property holds for 100 random pairs');
end;

procedure PropertyTestConstraintConsistency;
var
  i: Integer;
  Versions: array[0..4] of string;
  BaseVersion: string;
  v: Integer;
begin
  WriteLn('');
  WriteLn('=== Property Test: Constraint Consistency ===');
  WriteLn('Property 8: >= constraint accepts version and all higher versions');
  
  Versions[0] := '1.0.0';
  Versions[1] := '1.0.1';
  Versions[2] := '1.1.0';
  Versions[3] := '2.0.0';
  Versions[4] := '3.0.0';
  
  BaseVersion := '1.0.0';
  
  // All versions >= 1.0.0 should satisfy >=1.0.0
  for v := 0 to 4 do
  begin
    if not VersionSatisfiesConstraint(Versions[v], '>=' + BaseVersion) then
    begin
      Inc(TestsFailed);
      Inc(TotalTests);
      WriteLn('[FAIL] Constraint consistency violated: ', Versions[v], ' should satisfy >=', BaseVersion);
      Exit;
    end;
  end;
  
  Inc(TestsPassed);
  Inc(TotalTests);
  WriteLn('[PASS] Constraint consistency property holds');
end;

begin
  Randomize;
  
  WriteLn('========================================');
  WriteLn('Package Version Comparison Tests');
  WriteLn('Property 8: Version Comparison Correctness');
  WriteLn('Validates: Requirements 5.1');
  WriteLn('========================================');
  
  // Unit tests
  TestParseSemanticVersion;
  TestCompareVersions;
  TestVersionSatisfiesConstraint;
  
  // Property-based tests
  PropertyTestVersionComparisonTransitivity;
  PropertyTestVersionComparisonReflexivity;
  PropertyTestVersionComparisonSymmetry;
  PropertyTestConstraintConsistency;
  
  WriteLn('');
  WriteLn('========================================');
  WriteLn('Test Results: ', TestsPassed, '/', TotalTests, ' passed');
  if TestsFailed > 0 then
    WriteLn('FAILED: ', TestsFailed, ' tests failed')
  else
    WriteLn('SUCCESS: All tests passed');
  WriteLn('========================================');
  
  if TestsFailed > 0 then
    Halt(1);
end.
