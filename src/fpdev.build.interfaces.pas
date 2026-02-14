unit fpdev.build.interfaces;

{
================================================================================
  fpdev.build.interfaces - Build System Interface Definitions
================================================================================

  Interface-driven design for build system components, enabling dependency
  injection and improved testability.

  Interfaces:
    - IBuildLogger: Build process logging service
    - IToolchainChecker: Toolchain validation service
    - IBuildManager: Build orchestration service

  Author: fafafaStudio
  Email: dtamade@gmail.com
  Phase: 2.1 - Architecture Refactoring
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  { IBuildLogger - Build process logging service interface }
  IBuildLogger = interface
    ['{8F3A5B2C-1D4E-4F5A-9B6C-7E8D9F0A1B2C}']

    { Core logging method - writes timestamped line to log file }
    procedure Log(const ALine: string);

    { Logs sample of directory contents (up to ALimit entries) }
    procedure LogDirSample(const ADir: string; ALimit: Integer);

    { Logs environment snapshot (OS, PATH entries) }
    procedure LogEnvSnapshot;

    { Logs test summary with version, context, result and elapsed time }
    procedure LogTestSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);

    { Log file path }
    function GetLogFileName: string;

    { Verbosity level: 0=normal, 1=verbose }
    function GetVerbosity: Integer;
    procedure SetVerbosity(AValue: Integer);

    property LogFileName: string read GetLogFileName;
    property Verbosity: Integer read GetVerbosity write SetVerbosity;
  end;

  { IToolchainChecker - Toolchain validation service interface }
  IToolchainChecker = interface
    ['{9A4B6C3D-2E5F-4A6B-8C7D-9E0F1A2B3C4D}']

    { Check if make is available in PATH }
    function IsMakeAvailable: Boolean;

    { Check if FPC compiler is available }
    function IsFPCAvailable: Boolean;

    { Check if source directory exists and is valid }
    function IsSourceDirValid(const ASourceDir: string): Boolean;

    { Check if sandbox directory is writable }
    function IsSandboxWritable(const ASandboxDir: string): Boolean;

    { Get make command path }
    function GetMakeCommand: string;

    { Get FPC compiler path }
    function GetFPCCommand: string;

    { Verbosity level: 0=normal, 1=verbose }
    function GetVerbosity: Integer;
    procedure SetVerbosity(AValue: Integer);

    property Verbosity: Integer read GetVerbosity write SetVerbosity;
  end;

  { IBuildManager - Build orchestration service interface }
  IBuildManager = interface
    ['{A5B6C7D8-3E4F-5A6B-9C7D-0E1F2A3B4C5D}']

    { Build FPC compiler from source }
    function BuildCompiler(const AVersion: string): Boolean;

    { Build FPC runtime library }
    function BuildRTL(const AVersion: string): Boolean;

    { Build FPC packages }
    function BuildPackages(const AVersion: string): Boolean;

    { Install built FPC to sandbox }
    function Install(const AVersion: string): Boolean;

    { Test build results }
    function TestResults(const AVersion: string): Boolean;

    { Run preflight checks }
    function Preflight: Boolean;

    { Get log file name }
    function GetLogFileName: string;

    { Set sandbox root directory }
    procedure SetSandboxRoot(const APath: string);

    { Set allow install flag }
    procedure SetAllowInstall(AValue: Boolean);

    { Get last error message }
    function GetLastError: string;

    property LogFileName: string read GetLogFileName;
    property LastError: string read GetLastError;
  end;

implementation

end.
