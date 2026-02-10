program test_fpc_bootstrap;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.fpc.bootstrap;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Test(const AName: string; ACondition: Boolean);
begin
  Inc(GTestCount);
  if ACondition then
  begin
    Inc(GPassCount);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('[FAIL] ', AName);
  end;
end;

procedure TestDetectPlatformArch;
var
  BM: TBootstrapManager;
  PI: TPlatformInfo;
begin
  BM := TBootstrapManager.Create('/tmp/test');
  try
    PI := BM.DetectPlatformArch;

    // Platform should be non-empty on supported platforms
    {$IFDEF MSWINDOWS}
    Test('DetectPlatformArch: Platform is Win32 or Win64',
         (PI.Platform = 'Win32') or (PI.Platform = 'Win64'));
    Test('DetectPlatformArch: Architecture contains win',
         Pos('win', PI.Architecture) > 0);
    {$ENDIF}

    {$IFDEF LINUX}
    Test('DetectPlatformArch: Platform is Linux', PI.Platform = 'Linux');
    Test('DetectPlatformArch: Architecture contains linux',
         Pos('linux', PI.Architecture) > 0);
    {$ENDIF}

    {$IFDEF DARWIN}
    Test('DetectPlatformArch: Platform is macOS', PI.Platform = 'macOS');
    Test('DetectPlatformArch: Architecture contains darwin',
         Pos('darwin', PI.Architecture) > 0);
    {$ENDIF}

    // General checks that work on all platforms
    Test('DetectPlatformArch: Platform is not empty', PI.Platform <> '');
    Test('DetectPlatformArch: Architecture is not empty', PI.Architecture <> '');
  finally
    BM.Free;
  end;
end;

procedure TestGetRequiredBootstrapVersion;
var
  BM: TBootstrapManager;
begin
  BM := TBootstrapManager.Create('/tmp/test');
  try
    // Test main/trunk requires 3.2.2
    Test('GetRequiredBootstrapVersion: main requires 3.2.2',
         BM.GetRequiredBootstrapVersion('main') = '3.2.2');
    Test('GetRequiredBootstrapVersion: 3.3.1 requires 3.2.2',
         BM.GetRequiredBootstrapVersion('3.3.1') = '3.2.2');

    // Test 3.2.x requires 3.0.4
    Test('GetRequiredBootstrapVersion: 3.2.2 requires 3.0.4',
         BM.GetRequiredBootstrapVersion('3.2.2') = '3.0.4');
    Test('GetRequiredBootstrapVersion: 3.2.0 requires 3.0.4',
         BM.GetRequiredBootstrapVersion('3.2.0') = '3.0.4');

    // Test 3.0.x requires 2.6.4
    Test('GetRequiredBootstrapVersion: 3.0.4 requires 2.6.4',
         BM.GetRequiredBootstrapVersion('3.0.4') = '2.6.4');
    Test('GetRequiredBootstrapVersion: 3.0.2 requires 2.6.4',
         BM.GetRequiredBootstrapVersion('3.0.2') = '2.6.4');

    // Test unknown version defaults to 3.2.2
    Test('GetRequiredBootstrapVersion: unknown defaults to 3.2.2',
         BM.GetRequiredBootstrapVersion('unknown') = '3.2.2');
    Test('GetRequiredBootstrapVersion: empty defaults to 3.2.2',
         BM.GetRequiredBootstrapVersion('') = '3.2.2');
  finally
    BM.Free;
  end;
end;

procedure TestGetBootstrapPath;
var
  BM: TBootstrapManager;
  Path: string;
begin
  BM := TBootstrapManager.Create('/home/test/sources');
  try
    Path := BM.GetBootstrapPath('3.2.2');

    // Path should contain source root
    Test('GetBootstrapPath: contains source root',
         Pos('/home/test/sources', Path) > 0);

    // Path should contain bootstrap directory
    Test('GetBootstrapPath: contains bootstrap directory',
         Pos('bootstrap', Path) > 0);

    // Path should contain version
    Test('GetBootstrapPath: contains version',
         Pos('fpc-3.2.2', Path) > 0);

    // Path should end with fpc executable
    {$IFDEF MSWINDOWS}
    Test('GetBootstrapPath: ends with fpc.exe on Windows',
         Copy(Path, Length(Path) - 6, 7) = 'fpc.exe');
    {$ELSE}
    Test('GetBootstrapPath: ends with fpc on Unix',
         Copy(Path, Length(Path) - 2, 3) = 'fpc');
    {$ENDIF}
  finally
    BM.Free;
  end;
end;

procedure TestGetBootstrapDownloadURL;
var
  BM: TBootstrapManager;
  URL: string;
begin
  BM := TBootstrapManager.Create('/tmp/test');
  try
    URL := BM.GetBootstrapDownloadURL('3.2.2');

    // URL should contain SourceForge base
    Test('GetBootstrapDownloadURL: contains sourceforge',
         Pos('sourceforge.net', URL) > 0);

    // URL should contain version
    Test('GetBootstrapDownloadURL: contains version',
         Pos('3.2.2', URL) > 0);

    // URL should end with /download
    Test('GetBootstrapDownloadURL: ends with /download',
         Copy(URL, Length(URL) - 8, 9) = '/download');
  finally
    BM.Free;
  end;
end;

procedure TestSourceRootProperty;
var
  BM: TBootstrapManager;
begin
  BM := TBootstrapManager.Create('/initial/path');
  try
    Test('SourceRoot: initial value correct',
         BM.SourceRoot = '/initial/path');

    BM.SourceRoot := '/new/path';
    Test('SourceRoot: can be changed',
         BM.SourceRoot = '/new/path');
  finally
    BM.Free;
  end;
end;

procedure TestIsCompatibleBootstrap_NonExistentFile;
var
  BM: TBootstrapManager;
begin
  BM := TBootstrapManager.Create('/tmp/test');
  try
    // Non-existent file should return false
    Test('IsCompatibleBootstrap: non-existent file returns false',
         BM.IsCompatibleBootstrap('/nonexistent/path/fpc', '3.2.2') = False);

    // Empty path should return false
    Test('IsCompatibleBootstrap: empty path returns false',
         BM.IsCompatibleBootstrap('', '3.2.2') = False);
  finally
    BM.Free;
  end;
end;

begin
  WriteLn('=== TBootstrapManager Tests ===');
  WriteLn;

  TestDetectPlatformArch;
  TestGetRequiredBootstrapVersion;
  TestGetBootstrapPath;
  TestGetBootstrapDownloadURL;
  TestSourceRootProperty;
  TestIsCompatibleBootstrap_NonExistentFile;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Total:  ', GTestCount);
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);

  if GFailCount > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
