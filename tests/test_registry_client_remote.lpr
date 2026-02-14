program test_registry_client_remote;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils,
  Classes,
  fpjson,
  fpdev.registry.client,
  fpdev.registry.client.intf;

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

function BuildConfig: TRegistryConfig;
begin
  Result := Default(TRegistryConfig);
  Result.BaseURL := 'http://127.0.0.1:65535';
  Result.Timeout := 500;
  Result.UserAgent := 'fpdev-registry-test';
  Result.VerifySSL := False;
  Result.MaxConcurrentDownloads := 1;
end;

procedure WriteTextFile(const APath, AText: string);
var
  FS: TFileStream;
  Buffer: RawByteString;
begin
  Buffer := AText;
  FS := TFileStream.Create(APath, fmCreate);
  try
    if Length(Buffer) > 0 then
      FS.WriteBuffer(Buffer[1], Length(Buffer));
  finally
    FS.Free;
  end;
end;

procedure TestPublishMetadataAttemptsHTTPPost;
var
  Client: TRemoteRegistryClient;
  Config: TRegistryConfig;
  Metadata: TJSONObject;
  LastErrorLower: string;
begin
  Client := TRemoteRegistryClient.Create;
  try
    Config := BuildConfig;
    if not Client.Initialize(Config) then
    begin
      StartTest('PublishMetadata setup');
      Fail('Initialize failed');
      Exit;
    end;

    Metadata := TJSONObject.Create;
    try
      Metadata.Add('name', 'demo');
      Metadata.Add('version', '1.0.0');

      StartTest('PublishMetadata returns false on unreachable endpoint');
      if not Client.PublishMetadata(Metadata) then
        Pass
      else
        Fail('Expected false for unreachable endpoint');

      LastErrorLower := LowerCase(Client.GetLastError);

      StartTest('PublishMetadata error is not hardcoded stub');
      if Pos('not yet implemented', LastErrorLower) = 0 then
        Pass
      else
        Fail('Unexpected stub error: ' + Client.GetLastError);

      StartTest('PublishMetadata sets error message');
      if LastErrorLower <> '' then
        Pass
      else
        Fail('Expected non-empty error');
    finally
      Metadata.Free;
    end;
  finally
    Client.Free;
  end;
end;

procedure TestUploadPackageAttemptsHTTPPost;
var
  Client: TRemoteRegistryClient;
  Config: TRegistryConfig;
  ArchivePath: string;
  LastErrorLower: string;
begin
  ArchivePath := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'fpdev-registry-upload-' + IntToStr(Random(1000000)) + '.tar.gz';
  WriteTextFile(ArchivePath, 'dummy archive data');

  Client := TRemoteRegistryClient.Create;
  try
    Config := BuildConfig;
    if not Client.Initialize(Config) then
    begin
      StartTest('UploadPackage setup');
      Fail('Initialize failed');
      Exit;
    end;

    StartTest('UploadPackage returns false on unreachable endpoint');
    if not Client.UploadPackage(ArchivePath) then
      Pass
    else
      Fail('Expected false for unreachable endpoint');

    LastErrorLower := LowerCase(Client.GetLastError);

    StartTest('UploadPackage error is not hardcoded stub');
    if Pos('not yet implemented', LastErrorLower) = 0 then
      Pass
    else
      Fail('Unexpected stub error: ' + Client.GetLastError);

    StartTest('UploadPackage sets error message');
    if LastErrorLower <> '' then
      Pass
    else
      Fail('Expected non-empty error');
  finally
    Client.Free;
    DeleteFile(ArchivePath);
  end;
end;

begin
  Randomize;

  WriteLn('========================================');
  WriteLn('Remote Registry Client Tests');
  WriteLn('========================================');
  WriteLn;

  WriteLn('[1] PublishMetadata POST path');
  TestPublishMetadataAttemptsHTTPPost;
  WriteLn;

  WriteLn('[2] UploadPackage POST path');
  TestUploadPackageAttemptsHTTPPost;
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
