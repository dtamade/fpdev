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
  SysUtils, Classes, StrUtils, Process, fpdev.hash;

type
  { TPackageArchiver }
  TPackageArchiver = class
  private
    FSourceDir: string;
    FOutputFile: string;
    FChecksum: string;
    FIgnorePatterns: TStringList;

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

    property SourceDir: string read FSourceDir;
    property OutputFile: string read FOutputFile;
  end;

implementation

{ TPackageArchiver }

constructor TPackageArchiver.Create(const ASourceDir: string);
begin
  inherited Create;
  FSourceDir := ExpandFileName(ASourceDir);
  FOutputFile := '';
  FChecksum := '';
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
      // Ignore errors loading .fpdevignore
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

  // Get relative path from source directory
  RelPath := ExtractRelativePath(IncludeTrailingPathDelimiter(FSourceDir), AFilePath);

  for I := 0 to FIgnorePatterns.Count - 1 do
  begin
    Pattern := Trim(FIgnorePatterns[I]);

    // Skip empty lines and comments
    if (Pattern = '') or (Pattern[1] = '#') then
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

  // Collect all source files
  Files := DetectSourceFiles(True);
  try
    if Files.Count = 0 then
      Exit;

    // Create tar.gz archive using external tar command
    Process := TProcess.Create(nil);
    try
      Process.Executable := 'tar';
      Process.Parameters.Add('-czf');
      Process.Parameters.Add(FOutputFile);
      Process.Parameters.Add('-C');
      Process.Parameters.Add(FSourceDir);

      // Add all files as relative paths
      for I := 0 to Files.Count - 1 do
      begin
        RelPath := ExtractRelativePath(IncludeTrailingPathDelimiter(FSourceDir), Files[I]);
        Process.Parameters.Add(RelPath);
      end;

      Process.Options := [poWaitOnExit, poUsePipes];

      try
        Process.Execute;
        ExitCode := Process.ExitStatus;
        Result := (ExitCode = 0) and FileExists(FOutputFile);

        // Generate checksum if archive was created successfully
        if Result then
          FChecksum := SHA256FileHex(FOutputFile);
      except
        Result := False;
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

end.
