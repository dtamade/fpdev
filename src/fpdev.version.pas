unit fpdev.version;

{$mode objfpc}{$H+}

{
  FPDev Version Information

  This unit provides version constants for the FPDev application.
  Version follows Semantic Versioning (https://semver.org/):
    MAJOR.MINOR.PATCH[-SUFFIX]

  Update these values when releasing a new version.
}

interface

const
  { Version components }
  FPDEV_VERSION_MAJOR = 2;
  FPDEV_VERSION_MINOR = 0;
  FPDEV_VERSION_PATCH = 0;
  FPDEV_VERSION_SUFFIX = '';

  { Computed version strings }
  FPDEV_VERSION = '2.0.0';
  FPDEV_FULL_VERSION = '2.0.0';

  { Build information - populated at compile time }
  FPDEV_BUILD_DATE = {$I %DATE%};
  FPDEV_BUILD_TIME = {$I %TIME%};
  FPDEV_TARGET_CPU = {$I %FPCTARGETCPU%};
  FPDEV_TARGET_OS = {$I %FPCTARGETOS%};
  FPDEV_FPC_VERSION = {$I %FPCVERSION%};

  { Project information }
  FPDEV_NAME = 'FPDev';
  FPDEV_DESCRIPTION = 'FreePascal Development Environment Manager';
  FPDEV_HOMEPAGE = 'https://github.com/dtamade/fpdev';
  FPDEV_LICENSE = 'MIT';

{ Helper functions }
function GetVersionString: string;
function GetFullVersionString: string;
function GetBuildInfo: string;
function GetPlatformInfo: string;

implementation

uses
  SysUtils;

function GetVersionString: string;
begin
  Result := FPDEV_VERSION;
end;

function GetFullVersionString: string;
begin
  Result := FPDEV_FULL_VERSION;
end;

function GetBuildInfo: string;
begin
  Result := Format('Built: %s %s with FPC %s',
    [FPDEV_BUILD_DATE, FPDEV_BUILD_TIME, FPDEV_FPC_VERSION]);
end;

function GetPlatformInfo: string;
begin
  Result := Format('Platform: %s-%s', [FPDEV_TARGET_CPU, FPDEV_TARGET_OS]);
end;

end.
