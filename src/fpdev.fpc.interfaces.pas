unit fpdev.fpc.interfaces;

{$mode objfpc}{$H+}

{
  FPC Interfaces

  This module defines interfaces for dependency injection in FPC management classes.
  These interfaces enable unit testing by allowing mock implementations.
}

interface

uses
  SysUtils, Classes;

type
  { IFileSystem - File system operations interface.
    Abstracts file system operations for dependency injection and testing.
    Implementations: TDefaultFileSystem (production), TMockFileSystem (testing). }
  IFileSystem = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    { Checks if a file exists at the specified path. }
    function FileExists(const APath: string): Boolean;

    { Checks if a directory exists at the specified path. }
    function DirectoryExists(const APath: string): Boolean;

    { Creates a directory and all parent directories as needed. }
    function ForceDirectories(const APath: string): Boolean;

    { Deletes a file at the specified path. }
    function DeleteFile(const APath: string): Boolean;

    { Deletes a directory at the specified path. }
    function DeleteDirectory(const APath: string; const ARecursive: Boolean): Boolean;

    { Removes an empty directory. }
    function RemoveDir(const APath: string): Boolean;

    { Reads entire contents of a text file. }
    function ReadTextFile(const APath: string): string;

    { Writes text content to a file, creating parent directories as needed. }
    procedure WriteTextFile(const APath, AContent: string);

    { Writes all text to a file (alias for WriteTextFile). }
    procedure WriteAllText(const APath, AContent: string);

    { Returns the system temporary directory path. }
    function GetTempDir: string;
  end;

  { TProcessResult - Result of process execution.
    Contains exit code, output streams, and success status. }
  TProcessResult = record
    ExitCode: Integer;   // Process exit code (0 typically means success)
    StdOut: string;      // Standard output content
    StdErr: string;      // Standard error content
    Success: Boolean;    // True if ExitCode = 0
  end;

  { IProcessRunner - Process execution interface.
    Abstracts external process execution for dependency injection and testing.
    Implementations: TDefaultProcessRunner (production), TMockProcessRunner (testing). }
  IProcessRunner = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    { Executes an external process and waits for completion. }
    function Execute(const AExecutable: string; const AParams: array of string;
      const AWorkDir: string = ''): TProcessResult;

    { Executes an external process in a specific directory. }
    function ExecuteInDir(const AExecutable: string; const AParams: array of string;
      const AWorkDir: string): TProcessResult;

    { Executes an external process with a timeout. }
    function ExecuteWithTimeout(const AExecutable: string; const AParams: array of string;
      const ATimeoutMs: Integer; const AWorkDir: string = ''): TProcessResult;
  end;

  { THttpResponse - HTTP response data.
    Contains status code, content, and error information. }
  THttpResponse = record
    StatusCode: Integer;     // HTTP status code (200, 404, etc.)
    Content: string;         // Response body as string
    ContentStream: TStream;  // Response body as stream (for binary data)
    Success: Boolean;        // True if status code is 2xx
    ErrorMessage: string;    // Error description if request failed
  end;

  { IHttpClient - HTTP client interface.
    Abstracts HTTP operations for dependency injection and testing.
    Implementations: TDefaultHttpClient (production), TMockHttpClient (testing). }
  IHttpClient = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    { Performs an HTTP GET request and returns response content.
      @param AURL URL to fetch.
      @returns THttpResponse with status and content. }
    function Get(const AURL: string): THttpResponse;

    { Downloads a file from URL to local path.
      @param AURL URL to download from.
      @param ADestPath Local file path to save to.
      @returns THttpResponse with status (Content is empty for downloads). }
    function Download(const AURL, ADestPath: string): THttpResponse;
  end;

implementation

end.
