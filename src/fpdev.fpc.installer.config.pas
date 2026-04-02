unit fpdev.fpc.installer.config;

{
================================================================================
  fpdev.fpc.installer.config - FPC Configuration Generation Utilities
================================================================================

  Provides configuration file generation for FPC installations:
  - GenerateFpcConfig: Generate fpc.cfg configuration file
  - CreateLinuxCompilerWrapper: Create Linux-specific compiler wrapper
  - GetFPCArchSuffix: Get architecture suffix for current platform

  Extracted from TFPCBinaryInstaller to reduce file size and improve modularity.

  Author: FPDev Team
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.output.intf, fpdev.utils.process;

type
  { TFPCConfigGenerator - FPC configuration file generator }
  TFPCConfigGenerator = class
  private
    FOut: IOutput;
  public
    constructor Create(AOut: IOutput);

    { Generate fpc.cfg configuration file in the installation bin directory.
      AInstallPath: FPC installation root
      AVersion: FPC version string }
    procedure GenerateFpcConfig(const AInstallPath, AVersion: string);

    { Create Linux-specific compiler wrapper script and ppcx64 symlink.
      AInstallPath: FPC installation root
      AVersion: FPC version string }
    procedure CreateLinuxCompilerWrapper(const AInstallPath, AVersion: string);
  end;

{ Returns the FPC archive architecture suffix (e.g. 'x86_64-linux').
  This matches the naming convention used in official FPC binary packages. }
function GetFPCArchSuffix: string;

{ Returns the native compiler executable name for current platform.
  e.g. 'ppcx64' for x86_64, 'ppc386' for i386, 'ppca64' for aarch64 }
function GetNativeCompilerName: string;

{ Ensures a raw FPC install tree is repaired into FPDev's managed layout.
  On Linux this creates the wrapper/symlink/config trio required for a usable
  managed compiler layout. Other platforms currently treat the layout as ready. }
function EnsureManagedFPCInstallLayout(const AInstallPath, AVersion: string;
  AOut: IOutput = nil): Boolean;

implementation

function GetFPCArchSuffix: string;
begin
  {$IFDEF CPU64}
    {$IFDEF CPUAARCH64}
    Result := 'aarch64';
    {$ELSE}
    Result := 'x86_64';
    {$ENDIF}
  {$ELSE}
  Result := 'i386';
  {$ENDIF}
  Result := Result + '-';
  {$IFDEF LINUX}
  Result := Result + 'linux';
  {$ELSE}
    {$IFDEF DARWIN}
    Result := Result + 'darwin';
    {$ELSE}
      {$IFDEF MSWINDOWS}
        {$IFDEF CPU64}
        Result := Result + 'win64';
        {$ELSE}
        Result := Result + 'win32';
        {$ENDIF}
      {$ELSE}
        {$IFDEF FREEBSD}
        Result := Result + 'freebsd';
        {$ELSE}
        Result := Result + 'unknown';
        {$ENDIF}
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
end;

function GetNativeCompilerName: string;
begin
  {$IFDEF CPUAARCH64}
  Result := 'ppca64';
  {$ELSE}
    {$IFDEF CPU64}
    Result := 'ppcx64';
    {$ELSE}
    Result := 'ppc386';
    {$ENDIF}
  {$ENDIF}
end;

function EnsureManagedFPCInstallLayout(const AInstallPath, AVersion: string;
  AOut: IOutput): Boolean;
var
  ConfigGen: TFPCConfigGenerator;
  BinDir: string;
  FPCPath: string;
  CompilerPath: string;
  ConfigPath: string;
  BackupPath: string;
  NativeCompilerPath: string;
begin
  {$IFDEF LINUX}
  Result := False;

  if (Trim(AVersion) = '') or (Trim(AInstallPath) = '') then
    Exit;

  BinDir := IncludeTrailingPathDelimiter(AInstallPath) + 'bin';
  if not DirectoryExists(BinDir) then
    Exit;

  FPCPath := BinDir + PathDelim + 'fpc';
  CompilerPath := BinDir + PathDelim + GetNativeCompilerName;
  ConfigPath := BinDir + PathDelim + 'fpc.cfg';
  BackupPath := BinDir + PathDelim + 'fpc.orig';
  NativeCompilerPath := AInstallPath + PathDelim + 'lib' + PathDelim + 'fpc' +
    PathDelim + AVersion + PathDelim + GetNativeCompilerName;

  if not FileExists(FPCPath) then
    Exit;

  if (not FileExists(BackupPath)) and (not FileExists(NativeCompilerPath)) then
    Exit;

  ConfigGen := TFPCConfigGenerator.Create(AOut);
  try
    if not FileExists(BackupPath) then
      ConfigGen.CreateLinuxCompilerWrapper(AInstallPath, AVersion)
    else if (not FileExists(CompilerPath)) and FileExists(NativeCompilerPath) then
      TProcessExecutor.Execute('ln', ['-sf', NativeCompilerPath, CompilerPath], '');

    if not FileExists(ConfigPath) then
      ConfigGen.GenerateFpcConfig(AInstallPath, AVersion);
  finally
    ConfigGen.Free;
  end;

  Result := FileExists(FPCPath) and FileExists(BackupPath) and
    FileExists(CompilerPath) and FileExists(ConfigPath);
  {$ELSE}
  if AOut <> nil then;
  Result := (Trim(AVersion) <> '') and (Trim(AInstallPath) <> '') and
    DirectoryExists(AInstallPath);
  {$ENDIF}
end;

{ TFPCConfigGenerator }

constructor TFPCConfigGenerator.Create(AOut: IOutput);
begin
  inherited Create;
  FOut := AOut;
end;

procedure TFPCConfigGenerator.GenerateFpcConfig(const AInstallPath, AVersion: string);
var
  VersionLibPath: string;
  CfgPath: string;
begin
  VersionLibPath := AInstallPath + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + AVersion;
  CfgPath := AInstallPath + PathDelim + 'bin' + PathDelim + 'fpc.cfg';

  if Assigned(FOut) then
    FOut.WriteLn('Generating fpc.cfg...');

  with TStringList.Create do
  try
    Add('# FPC configuration file generated by fpdev');
    Add('# FPC version: ' + AVersion);
    Add('');
    Add('# Compiler binary path');
    Add('-FD' + VersionLibPath);
    Add('');
    Add('# Unit search paths');
    Add('-Fu' + VersionLibPath + PathDelim + 'units' + PathDelim + '$fpctarget' + PathDelim + '*');
    Add('-Fu' + VersionLibPath + PathDelim + 'units' + PathDelim + '$fpctarget' + PathDelim + 'rtl');
    Add('');
    Add('# Library search path');
    Add('-Fl' + VersionLibPath + PathDelim + 'units' + PathDelim + '$fpctarget' + PathDelim + 'rtl');
    Add('');
    Add('# Include search path');
    Add('-Fi' + VersionLibPath + PathDelim + 'units' + PathDelim + '$fpctarget' + PathDelim + 'rtl');
    SaveToFile(CfgPath);

    if Assigned(FOut) then
      FOut.WriteLn('  fpc.cfg created');
  finally
    Free;
  end;
end;

procedure TFPCConfigGenerator.CreateLinuxCompilerWrapper(const AInstallPath, AVersion: string);
var
  CompilerName: string;
  LibPath, BinPath: string;
begin
  {$IFDEF LINUX}
  CompilerName := GetNativeCompilerName;
  LibPath := AInstallPath + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + AVersion;
  BinPath := AInstallPath + PathDelim + 'bin';

  // Create symlink to native compiler in bin directory so fpc driver can find it
  if Assigned(FOut) then
    FOut.WriteLn('Creating compiler symlink...');
  TProcessExecutor.Execute('ln', ['-sf',
    LibPath + PathDelim + CompilerName,
    BinPath + PathDelim + CompilerName], '');
  if Assigned(FOut) then
    FOut.WriteLn('  ' + CompilerName + ' symlink created');

  // Create fpc wrapper script that bypasses default config files
  // This ensures our fpc.cfg is used instead of ~/.fpc.cfg
  if Assigned(FOut) then
    FOut.WriteLn('Creating fpc wrapper script...');
  with TStringList.Create do
  try
    Add('#!/bin/sh');
    Add('# FPC wrapper script generated by fpdev');
    Add('# Calls native compiler directly with our config to bypass ~/.fpc.cfg');
    Add(
      BinPath + '/' + CompilerName + ' -n @' + BinPath + '/fpc.cfg "$@"' // acq:allow-hardcoded-constants
    );
    SaveToFile(BinPath + PathDelim + 'fpc.sh');
  finally
    Free;
  end;
  TProcessExecutor.Execute('chmod', ['+x', BinPath + PathDelim + 'fpc.sh'], '');

  // Replace the fpc binary with our wrapper
  TProcessExecutor.Execute('mv', [BinPath + PathDelim + 'fpc',
    BinPath + PathDelim + 'fpc.orig'], '');
  TProcessExecutor.Execute('mv', [BinPath + PathDelim + 'fpc.sh',
    BinPath + PathDelim + 'fpc'], '');

  if Assigned(FOut) then
    FOut.WriteLn('  fpc wrapper created');
  {$ENDIF}
end;

end.
