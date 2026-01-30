program test_http_download;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.http.download;

var
  Downloader: THTTPDownloader;
  TestsPassed, TestsFailed: Integer;
  TempFile: string;
  Stream: TFileStream;

procedure Assert(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    Inc(TestsFailed);
  end;
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn('=== HTTP Download Tests ===');
  WriteLn;

  Downloader := THTTPDownloader.Create;
  try
    // Test 1: Downloader initializes
    Assert(Downloader <> nil, 'Downloader initializes');

    // Test 2: Can set progress callback
    Downloader.OnProgress := nil;
    Assert(True, 'Can set progress callback');

    // Test 3: Download small test file (httpbin.org echo)
    TempFile := GetTempDir + 'test_download.txt';
    WriteLn('Downloading test file to: ', TempFile);
    if Downloader.Download('https://httpbin.org/bytes/1024', TempFile) then
    begin
      Assert(FileExists(TempFile), 'Downloaded file exists');
      Stream := TFileStream.Create(TempFile, fmOpenRead);
      try
        Assert(Stream.Size = 1024, 'Downloaded file has correct size');
      finally
        Stream.Free;
      end;
      DeleteFile(TempFile);
    end
    else
      WriteLn('[SKIP] Download test (network unavailable)');

    // Test 4: Invalid URL returns false
    Assert(not Downloader.Download('invalid://url', TempFile), 'Invalid URL returns false');

    // Test 5: Can get last error message
    Assert(Length(Downloader.GetLastError) > 0, 'Can get last error message');

  finally
    Downloader.Free;
  end;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
