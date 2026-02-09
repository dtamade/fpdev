program test_resource_repo_search;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.resource.repo.search;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(const ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

procedure TestMatchByName;
begin
  Check(ResourceRepoPackageMatchesKeyword('jsonlib', 'A JSON library', 'json') = True,
        'MatchByName: keyword in name');
  Check(ResourceRepoPackageMatchesKeyword('mypackage', 'Some description', 'mypack') = True,
        'MatchByName: partial keyword in name');
end;

procedure TestMatchByDescription;
begin
  Check(ResourceRepoPackageMatchesKeyword('foo', 'A JSON parsing library', 'json') = True,
        'MatchByDesc: keyword in description');
  Check(ResourceRepoPackageMatchesKeyword('foo', 'handles XML and JSON data', 'json') = True,
        'MatchByDesc: keyword in middle of description');
end;

procedure TestCaseInsensitive;
begin
  Check(ResourceRepoPackageMatchesKeyword('JSONLib', 'desc', 'json') = True,
        'CaseInsensitive: uppercase name, lowercase keyword');
  Check(ResourceRepoPackageMatchesKeyword('jsonlib', 'desc', 'JSON') = True,
        'CaseInsensitive: lowercase name, uppercase keyword');
  Check(ResourceRepoPackageMatchesKeyword('foo', 'JSON Library', 'json') = True,
        'CaseInsensitive: uppercase description');
end;

procedure TestNoMatch;
begin
  Check(ResourceRepoPackageMatchesKeyword('foo', 'bar', 'baz') = False,
        'NoMatch: keyword not in name or description');
  Check(ResourceRepoPackageMatchesKeyword('', '', 'test') = False,
        'NoMatch: empty name and description');
end;

procedure TestEmptyKeyword;
begin
  // FPC: Pos('', s) returns 0, so empty keyword does NOT match
  Check(ResourceRepoPackageMatchesKeyword('foo', 'bar', '') = False,
        'EmptyKeyword: empty keyword does not match');
end;

procedure TestExactMatch;
begin
  Check(ResourceRepoPackageMatchesKeyword('json', 'desc', 'json') = True,
        'ExactMatch: name equals keyword');
end;

begin
  WriteLn('=== Resource Repo Search Unit Tests ===');
  WriteLn;

  TestMatchByName;
  TestMatchByDescription;
  TestCaseInsensitive;
  TestNoMatch;
  TestEmptyKeyword;
  TestExactMatch;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
