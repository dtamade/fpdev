program test_gitlab_api_remote;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils,
  Classes,
  fpdev.gitlab.api;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure StartTest(const AName: string);
begin
  Write('  ', AName, '... ');
end;

procedure Pass;
begin
  WriteLn('PASSED');
  Inc(PassCount);
end;

procedure Fail(const AReason: string);
begin
  WriteLn('FAILED: ', AReason);
  Inc(FailCount);
end;

function CreateTempFile(const AExt, AContent: string): string;
var
  FS: TFileStream;
  B: RawByteString;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'fpdev-gl-api-' + IntToStr(Random(1000000)) + AExt;
  FS := TFileStream.Create(Result, fmCreate);
  try
    B := AContent;
    if Length(B) > 0 then
      FS.WriteBuffer(B[1], Length(B));
  finally
    FS.Free;
  end;
end;

procedure AssertNoStubError(const APrefix, AError: string);
var
  L: string;
begin
  L := LowerCase(AError);
  StartTest(APrefix + ' error is not hardcoded stub');
  if Pos('not yet implemented', L) = 0 then
    Pass
  else
    Fail('Unexpected stub error: ' + AError);
end;

procedure TestCreateProjectUsesHTTPPost;
var
  Cli: TGitLabClient;
begin
  Cli := TGitLabClient.Create('http://127.0.0.1:65535');
  try
    StartTest('CreateProject returns nil on unreachable endpoint');
    if Cli.CreateProject('demo-proj', 'demo', 'private') = nil then
      Pass
    else
      Fail('Expected nil result');

    AssertNoStubError('CreateProject', Cli.GetLastError);
  finally
    Cli.Free;
  end;
end;

procedure TestUploadPackageUsesHTTPPost;
var
  Cli: TGitLabClient;
  FilePath: string;
begin
  FilePath := CreateTempFile('.tgz', 'package payload');
  Cli := TGitLabClient.Create('http://127.0.0.1:65535');
  try
    StartTest('UploadPackage returns nil on unreachable endpoint');
    if Cli.UploadPackage('123', FilePath, 'demo-pkg', '1.0.0') = nil then
      Pass
    else
      Fail('Expected nil result');

    AssertNoStubError('UploadPackage', Cli.GetLastError);
  finally
    Cli.Free;
    DeleteFile(FilePath);
  end;
end;

procedure TestDeletePackageUsesHTTPDelete;
var
  Cli: TGitLabClient;
begin
  Cli := TGitLabClient.Create('http://127.0.0.1:65535');
  try
    StartTest('DeletePackage returns false on unreachable endpoint');
    if not Cli.DeletePackage('123', '456') then
      Pass
    else
      Fail('Expected false result');

    AssertNoStubError('DeletePackage', Cli.GetLastError);
  finally
    Cli.Free;
  end;
end;

procedure TestCreateReleaseUsesHTTPPost;
var
  Cli: TGitLabClient;
begin
  Cli := TGitLabClient.Create('http://127.0.0.1:65535');
  try
    StartTest('CreateRelease returns nil on unreachable endpoint');
    if Cli.CreateRelease('123', 'v1.0.0', 'release', 'notes') = nil then
      Pass
    else
      Fail('Expected nil result');

    AssertNoStubError('CreateRelease', Cli.GetLastError);
  finally
    Cli.Free;
  end;
end;

begin
  Randomize;

  WriteLn('========================================');
  WriteLn('GitLab API Remote Tests');
  WriteLn('========================================');
  WriteLn;

  WriteLn('[1] CreateProject POST path');
  TestCreateProjectUsesHTTPPost;
  WriteLn;

  WriteLn('[2] UploadPackage POST path');
  TestUploadPackageUsesHTTPPost;
  WriteLn;

  WriteLn('[3] DeletePackage DELETE path');
  TestDeletePackageUsesHTTPDelete;
  WriteLn;

  WriteLn('[4] CreateRelease POST path');
  TestCreateReleaseUsesHTTPPost;
  WriteLn;

  WriteLn('========================================');
  WriteLn('Test Results Summary');
  WriteLn('========================================');
  WriteLn('Total:   ', PassCount + FailCount);
  WriteLn('Passed:  ', PassCount);
  WriteLn('Failed:  ', FailCount);
  WriteLn;

  if FailCount = 0 then
    WriteLn('All tests passed!')
  else
    Halt(1);
end.
