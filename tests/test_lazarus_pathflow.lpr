program test_lazarus_pathflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.lazarus.pathflow,
  test_temp_paths;

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

procedure MakeExecutable(const APath: string);
begin
  {$IFDEF UNIX}
  if fpchmod(APath, &755) <> 0 then
    raise Exception.Create('Failed to mark executable: ' + APath);
  {$ENDIF}
end;

procedure WriteMockExecutable(const APath: string);
begin
  ForceDirectories(ExtractFileDir(APath));
  with TStringList.Create do
  try
    {$IFDEF UNIX}
    Add('#!/bin/sh');
    Add('exit 0');
    {$ELSE}
    Add('@echo off');
    {$ENDIF}
    SaveToFile(APath);
  finally
    Free;
  end;
  MakeExecutable(APath);
end;

function PlatformExecutablePath(const AInstallPath: string): string;
begin
  {$IFDEF MSWINDOWS}
  Result := AInstallPath + PathDelim + 'lazarus.exe';
  {$ELSE}
  Result := AInstallPath + PathDelim + 'bin' + PathDelim + 'lazarus-ide';
  {$ENDIF}
end;

procedure TestBuildLazarusVersionInstallPathCore;
var
  InstallRoot: string;
begin
  InstallRoot := '/tmp/fpdev-root';
  Check(
    'build version install path',
    BuildLazarusVersionInstallPathCore(InstallRoot, '3.0') =
      InstallRoot + PathDelim + 'lazarus' + PathDelim + '3.0',
    'unexpected install path'
  );
end;

procedure TestBuildLazarusExecutablePathFromInstallPathCore;
var
  InstallPath: string;
begin
  InstallPath := '/tmp/fpdev-lazarus-3.0';
  Check(
    'build executable path from install path',
    BuildLazarusExecutablePathFromInstallPathCore(
      InstallPath,
      {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
    ) = PlatformExecutablePath(InstallPath),
    'unexpected executable path'
  );
end;

procedure TestResolveLazarusInstallPathCore;
var
  TempRoot: string;
  DefaultInstallPath: string;
  ConfiguredInstallPath: string;
begin
  TempRoot := CreateUniqueTempDir('test_lazarus_pathflow_resolve');
  try
    DefaultInstallPath := TempRoot + PathDelim + 'default';
    ConfiguredInstallPath := TempRoot + PathDelim + 'configured';

    WriteMockExecutable(PlatformExecutablePath(ConfiguredInstallPath));
    Check(
      'resolve prefers configured executable path',
      ResolveLazarusInstallPathCore(
        DefaultInstallPath,
        ConfiguredInstallPath,
        {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
      ) = ConfiguredInstallPath,
      'expected configured install path when configured executable exists'
    );

    CleanupTempDir(ConfiguredInstallPath);
    WriteMockExecutable(PlatformExecutablePath(DefaultInstallPath));
    Check(
      'resolve falls back to default executable path',
      ResolveLazarusInstallPathCore(
        DefaultInstallPath,
        ConfiguredInstallPath,
        {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
      ) = DefaultInstallPath,
      'expected default install path when configured executable is missing'
    );

    CleanupTempDir(DefaultInstallPath);
    Check(
      'resolve keeps configured path when executables are missing',
      ResolveLazarusInstallPathCore(
        DefaultInstallPath,
        ConfiguredInstallPath,
        {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
      ) = ConfiguredInstallPath,
      'expected configured install path fallback when neither executable exists'
    );
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestIsLazarusVersionInstalledCore;
var
  TempRoot: string;
  InstallPath: string;
begin
  TempRoot := CreateUniqueTempDir('test_lazarus_pathflow_installed');
  try
    InstallPath := TempRoot + PathDelim + 'installed';
    Check(
      'install state false before executable exists',
      not IsLazarusVersionInstalledCore(
        InstallPath,
        {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
      ),
      'expected install state to be false before writing executable'
    );

    WriteMockExecutable(PlatformExecutablePath(InstallPath));
    Check(
      'install state true after executable exists',
      IsLazarusVersionInstalledCore(
        InstallPath,
        {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
      ),
      'expected install state to be true after writing executable'
    );
  finally
    CleanupTempDir(TempRoot);
  end;
end;

begin
  WriteLn('=== Lazarus Pathflow Tests ===');

  TestBuildLazarusVersionInstallPathCore;
  TestBuildLazarusExecutablePathFromInstallPathCore;
  TestResolveLazarusInstallPathCore;
  TestIsLazarusVersionInstalledCore;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
