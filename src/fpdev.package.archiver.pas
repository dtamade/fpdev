unit fpdev.package.archiver;

{$mode objfpc}{$H+}

(*
  Package Archiver Module

  Provides functionality for creating package archives:
  - Source file detection (recursive)
  - .fpdevignore support
  - tar.gz archive creation
  - SHA256 checksum generation

  Usage:
    Archiver := TPackageArchiver.Create('/path/to/package');
    try
      Files := Archiver.DetectSourceFiles;
      if Archiver.CreateArchive('mylib-1.0.0.tar.gz') then
        WriteLn('Archive created: ', Archiver.GetChecksum);
    finally
      Archiver.Free;
    end;
*)

interface

uses
  SysUtils, Classes, StrUtils, Process;

type
  { TPackageArchiver }
  TPackageArchiver = class
  private
    FSourceDir: string;
    FSourceDirWithDelim: string;
    FOutputFile: string;
    FChecksum: string;
    FIgnorePatterns: TStringList;
    FLastError: string;

    function LoadIgnorePatterns: Boolean;
    function MatchesIgnorePattern(const AFilePath: string): Boolean;
    function CollectFiles(const ADir: string; ARecursive: Boolean): TStringList;
    function IsSourceFile(const AFileName: string): Boolean;

  public
    constructor Create(const ASourceDir: string);
    destructor Destroy; override;

    { Detect source files in the package directory }
    function DetectSourceFiles(ARecursive: Boolean = True): TStringList;

    { Create tar.gz archive }
    function CreateArchive(const AOutputFile: string): Boolean;

    { Get SHA256 checksum of the archive }
    function GetChecksum: string;

    { Get last error message }
    function GetLastError: string;

    property SourceDir: string read FSourceDir;
    property OutputFile: string read FOutputFile;
  end;

implementation

uses
  fpdev.hash;

{ TPackageArchiver }

constructor TPackageArchiver.Create(const ASourceDir: string);
begin
  inherited Create;
  FSourceDir := ExpandFileName(ASourceDir);
  FSourceDirWithDelim := IncludeTrailingPathDelimiter(FSourceDir);
  FOutputFile := '';
  FChecksum := '';
  FLastError := '';
  FIgnorePatterns := TStringList.Create;
  LoadIgnorePatterns;
end;

destructor TPackageArchiver.Destroy;
begin
  FIgnorePatterns.Free;
  inherited Destroy;
end;

function TPackageArchiver.LoadIgnorePatterns: Boolean;
var
  IgnoreFile: string;
begin
  Result := False;
  IgnoreFile := FSourceDir + PathDelim + '.fpdevignore';

  if FileExists(IgnoreFile) then
  begin
    try
      FIgnorePatterns.LoadFromFile(IgnoreFile);
      Result := True;
    except
      on E: Exception do
      begin
        FLastError := 'Failed to load .fpdevignore: ' + E.Message;
        Result := False;
      end;
    end;
  end;
end;

function TPackageArchiver.MatchesIgnorePattern(const AFilePath: string): Boolean;
var
  I: Integer;
  Pattern: string;
  RelPath: string;
begin
  Result := False;

  // Get relative path from source directory (using cached path with delimiter)
  RelPath := ExtractRelativePath(FSourceDirWithDelim, AFilePath);

  for I := 0 to FIgnorePatterns.Count - 1 do
  begin
    Pattern := Trim(FIgnorePatterns[I]);

    // Skip empty lines and comments
    if (Length(Pattern) = 0) or (Pattern[1] = '#') then
      Continue;

    // Simple wildcard matching
    if Pos('*', Pattern) > 0 then
    begin
      // *.tmp pattern
      if (Pattern[1] = '*') and (Length(Pattern) > 1) then
      begin
        if AnsiEndsStr(Copy(Pattern, 2, Length(Pattern)), RelPath) then
        begin
          Result := True;
          Exit;
        end;
      end;
    end
    else
    begin
      // Exact match or directory match
      if (RelPath = Pattern) or AnsiStartsStr(Pattern, RelPath) then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;
end;

function TPackageArchiver.IsSourceFile(const AFileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  Result := (Ext = '.pas') or (Ext = '.pp') or (Ext = '.inc') or (Ext = '.lpr');
end;

function TPackageArchiver.CollectFiles(const ADir: string; ARecursive: Boolean): TStringList;
var
  SR: TSearchRec;
  FilePath: string;
  SubFiles: TStringList;
  I: Integer;
begin
  Result := TStringList.Create;

  if FindFirst(ADir + PathDelim + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then
          Continue;

        FilePath := ADir + PathDelim + SR.Name;

        // Skip if matches ignore pattern
        if MatchesIgnorePattern(FilePath) then
          Continue;

        if (SR.Attr and faDirectory) <> 0 then
        begin
          // Recursively collect files from subdirectory
          if ARecursive then
          begin
            SubFiles := CollectFiles(FilePath, True);
            try
              for I := 0 to SubFiles.Count - 1 do
                Result.Add(SubFiles[I]);
            finally
              SubFiles.Free;
            end;
          end;
        end
        else
        begin
          // Add source files
          if IsSourceFile(SR.Name) then
            Result.Add(FilePath);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

function TPackageArchiver.DetectSourceFiles(ARecursive: Boolean): TStringList;
begin
  Result := CollectFiles(FSourceDir, ARecursive);
end;

function TPackageArchiver.CreateArchive(const AOutputFile: string): Boolean;
var
  Process: TProcess;
  Files: TStringList;
  I: Integer;
  RelPath: string;
  ExitCode: Integer;
begin
  Result := False;
  FOutputFile := ExpandFileName(AOutputFile);
  FChecksum := '';
  FLastError := '';

  // Collect all source files
  Files := DetectSourceFiles(True);
  try
    if Files.Count = 0 then
    begin
      FLastError := 'No source files found to archive';
      Exit;
    end;

    // Create tar.gz archive using external tar command
    Process := TProcess.Create(nil);
    try
      Process.Executable := 'tar';
      Process.Parameters.Add('-czf');
      Process.Parameters.Add(FOutputFile);
      Process.Parameters.Add('-C');
      Process.Parameters.Add(FSourceDir);

      // Add all files as relative paths (using cached path with delimiter)
      for I := 0 to Files.Count - 1 do
      begin
        RelPath := ExtractRelativePath(FSourceDirWithDelim, Files[I]);
        Process.Parameters.Add(RelPath);
      end;

      Process.Options := [poWaitOnExit, poUsePipes];

      try
        Process.Execute;
        ExitCode := Process.ExitStatus;
        Result := (ExitCode = 0) and FileExists(FOutputFile);

        if not Result then
        begin
          if ExitCode <> 0 then
            FLastError := Format('tar command failed with exit code %d', [ExitCode])
          else
            FLastError := 'Archive file was not created';
        end
        else
        begin
          // Generate checksum if archive was created successfully
          FChecksum := SHA256FileHex(FOutputFile);
        end;
      except
        on E: Exception do
        begin
          FLastError := 'Failed to execute tar command: ' + E.Message;
          Result := False;
        end;
      end;
    finally
      Process.Free;
    end;
  finally
    Files.Free;
  end;
end;

function TPackageArchiver.GetChecksum: string;
begin
  Result := FChecksum;
end;

function TPackageArchiver.GetLastError: string;
begin
  Result := FLastError;
end;

end.
