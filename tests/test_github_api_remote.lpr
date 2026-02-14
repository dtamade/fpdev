program test_github_api_remote;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils,
  Classes,
  fpdev.github.api;

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
    'fpdev-gh-api-' + IntToStr(Random(1000000)) + AExt;
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

procedure TestCreateRepositoryUsesHTTPPost;
var
  Cli: TGitHubClient;
begin
  Cli := TGitHubClient.Create('http://127.0.0.1:65535');
  try
    StartTest('CreateRepository returns nil on unreachable endpoint');
    if Cli.CreateRepository('demo-repo', 'demo', False) = nil then
      Pass
    else
      Fail('Expected nil result');

    AssertNoStubError('CreateRepository', Cli.GetLastError);
  finally
    Cli.Free;
  end;
end;

procedure TestCreateReleaseUsesHTTPPost;
var
  Cli: TGitHubClient;
begin
  Cli := TGitHubClient.Create('http://127.0.0.1:65535');
  try
    StartTest('CreateRelease returns nil on unreachable endpoint');
    if Cli.CreateRelease('owner', 'repo', 'v1.0.0', 'release', 'notes', False, False) = nil then
      Pass
    else
      Fail('Expected nil result');

    AssertNoStubError('CreateRelease', Cli.GetLastError);
  finally
    Cli.Free;
  end;
end;

procedure TestUploadReleaseAssetUsesHTTPPost;
var
  Cli: TGitHubClient;
  FilePath: string;
begin
  FilePath := CreateTempFile('.bin', 'asset payload');
  Cli := TGitHubClient.Create('http://127.0.0.1:65535');
  try
    StartTest('UploadReleaseAsset returns nil on unreachable endpoint');
    if Cli.UploadReleaseAsset('owner', 'repo', 1, FilePath, 'application/octet-stream') = nil then
      Pass
    else
      Fail('Expected nil result');

    AssertNoStubError('UploadReleaseAsset', Cli.GetLastError);
  finally
    Cli.Free;
    DeleteFile(FilePath);
  end;
end;

procedure TestDeleteReleaseAssetUsesHTTPDelete;
var
  Cli: TGitHubClient;
begin
  Cli := TGitHubClient.Create('http://127.0.0.1:65535');
  try
    StartTest('DeleteReleaseAsset returns false on unreachable endpoint');
    if not Cli.DeleteReleaseAsset('owner', 'repo', 7) then
      Pass
    else
      Fail('Expected false result');

    AssertNoStubError('DeleteReleaseAsset', Cli.GetLastError);
  finally
    Cli.Free;
  end;
end;

begin
  Randomize;

  WriteLn('========================================');
  WriteLn('GitHub API Remote Tests');
  WriteLn('========================================');
  WriteLn;

  WriteLn('[1] CreateRepository POST path');
  TestCreateRepositoryUsesHTTPPost;
  WriteLn;

  WriteLn('[2] CreateRelease POST path');
  TestCreateReleaseUsesHTTPPost;
  WriteLn;

  WriteLn('[3] UploadReleaseAsset POST path');
  TestUploadReleaseAssetUsesHTTPPost;
  WriteLn;

  WriteLn('[4] DeleteReleaseAsset DELETE path');
  TestDeleteReleaseAssetUsesHTTPDelete;
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
