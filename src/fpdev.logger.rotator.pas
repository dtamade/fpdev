unit fpdev.logger.rotator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, fpdev.logger.structured;

type
  { ILogRotator - Log rotation interface }
  ILogRotator = interface
    ['{6D1E2F3A-8B9C-0D1E-2F3A-4B5C6D7E8F9A}']
    function ShouldRotate(const ACurrentFile: string): Boolean;
    procedure Rotate(const ACurrentFile: string);
    procedure CleanupOldLogs(const ALogDir: string);
  end;

  { TLogRotator - Log rotation implementation }
  TLogRotator = class(TInterfacedObject, ILogRotator)
  private
    FConfig: TRotationConfig;

    function GetFileSize(const APath: string): Int64;
    function GetFileAge(const APath: string): TDateTime;
    function ShouldRotateBySize(const ACurrentFile: string): Boolean;
    function ShouldRotateByTime(const ACurrentFile: string): Boolean;
    procedure RenameRotatedFiles(const ABasePath: string);
    procedure DeleteOldFiles(const ALogDir: string);
  public
    constructor Create(const AConfig: TRotationConfig);

    function ShouldRotate(const ACurrentFile: string): Boolean;
    procedure Rotate(const ACurrentFile: string);
    procedure CleanupOldLogs(const ALogDir: string);
  end;

{ Helper functions }
function CreateDefaultRotationConfig: TRotationConfig;

implementation

{ Helper functions }

function CreateDefaultRotationConfig: TRotationConfig;
begin
  Result.MaxFileSize := 10 * 1024 * 1024;  // 10MB
  Result.RotationInterval := 24;  // 24 hours
  Result.MaxFiles := 5;
  Result.MaxAge := 7;  // 7 days
  Result.CompressOld := False;
end;

{ TLogRotator }

constructor TLogRotator.Create(const AConfig: TRotationConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

function TLogRotator.GetFileSize(const APath: string): Int64;
var
  SR: TSearchRec;
begin
  Result := 0;
  if not FileExists(APath) then
    Exit;

  if FindFirst(APath, faAnyFile, SR) = 0 then
  begin
    Result := SR.Size;
    FindClose(SR);
  end;
end;

function TLogRotator.GetFileAge(const APath: string): TDateTime;
var
  SR: TSearchRec;
begin
  Result := Now;
  if not FileExists(APath) then
    Exit;

  if FindFirst(APath, faAnyFile, SR) = 0 then
  begin
    Result := SR.TimeStamp;
    FindClose(SR);
  end;
end;

function TLogRotator.ShouldRotateBySize(const ACurrentFile: string): Boolean;
var
  FileSize: Int64;
begin
  Result := False;
  if not FileExists(ACurrentFile) then
    Exit;

  FileSize := GetFileSize(ACurrentFile);
  Result := FileSize >= FConfig.MaxFileSize;
end;

function TLogRotator.ShouldRotateByTime(const ACurrentFile: string): Boolean;
var
  FileAge: TDateTime;
  HoursSinceUpdate: Integer;
begin
  Result := False;
  if not FileExists(ACurrentFile) then
    Exit;

  FileAge := GetFileAge(ACurrentFile);
  HoursSinceUpdate := HoursBetween(Now, FileAge);
  Result := HoursSinceUpdate >= FConfig.RotationInterval;
end;

function TLogRotator.ShouldRotate(const ACurrentFile: string): Boolean;
begin
  Result := ShouldRotateBySize(ACurrentFile) or ShouldRotateByTime(ACurrentFile);
end;

procedure TLogRotator.RenameRotatedFiles(const ABasePath: string);
var
  i: Integer;
  OldPath, NewPath: string;
begin
  // Rename existing rotated files (shift numbers up)
  // Start from MaxFiles-1 and work backwards
  for i := FConfig.MaxFiles - 1 downto 1 do
  begin
    OldPath := ABasePath + '.' + IntToStr(i);
    NewPath := ABasePath + '.' + IntToStr(i + 1);

    if FileExists(OldPath) then
    begin
      // Delete the target if it exists (it's beyond MaxFiles)
      if FileExists(NewPath) then
        DeleteFile(NewPath);

      // Rename the file
      RenameFile(OldPath, NewPath);
    end;
  end;
end;

procedure TLogRotator.Rotate(const ACurrentFile: string);
var
  RotatedPath: string;
begin
  if not FileExists(ACurrentFile) then
    Exit;

  // Rename existing rotated files first
  RenameRotatedFiles(ACurrentFile);

  // Rename current file to .1
  RotatedPath := ACurrentFile + '.1';
  if FileExists(RotatedPath) then
    DeleteFile(RotatedPath);

  RenameFile(ACurrentFile, RotatedPath);

  // Cleanup old files beyond MaxFiles
  CleanupOldLogs(ExtractFileDir(ACurrentFile));
end;

procedure TLogRotator.DeleteOldFiles(const ALogDir: string);
var
  SR: TSearchRec;
  FilePath: string;
  FileAge: TDateTime;
  AgeInDays: Integer;
begin
  if FindFirst(ALogDir + PathDelim + '*.*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) = 0) then
      begin
        FilePath := ALogDir + PathDelim + SR.Name;

        // Check if file is a rotated log (ends with .N)
        if Pos('.', SR.Name) > 0 then
        begin
          // Check age
          FileAge := SR.TimeStamp;
          AgeInDays := DaysBetween(Now, FileAge);

          if AgeInDays >= FConfig.MaxAge then
            DeleteFile(FilePath);
        end;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

procedure TLogRotator.CleanupOldLogs(const ALogDir: string);
var
  SR: TSearchRec;
  LogFiles: TStringList;
  i: Integer;
  FilePath: string;
begin
  if not DirectoryExists(ALogDir) then
    Exit;

  // First, delete files older than MaxAge
  DeleteOldFiles(ALogDir);

  // Then, collect all rotated log files
  LogFiles := TStringList.Create;
  try
    if FindFirst(ALogDir + PathDelim + '*.*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) = 0) then
        begin
          // Check if file is a rotated log (ends with .N)
          if Pos('.', SR.Name) > 0 then
          begin
            FilePath := ALogDir + PathDelim + SR.Name;
            LogFiles.Add(FilePath);
          end;
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    // Sort by modification time (newest first)
    LogFiles.Sort;

    // Delete files beyond MaxFiles
    if LogFiles.Count > FConfig.MaxFiles then
    begin
      for i := FConfig.MaxFiles to LogFiles.Count - 1 do
      begin
        if FileExists(LogFiles[i]) then
          DeleteFile(LogFiles[i]);
      end;
    end;
  finally
    LogFiles.Free;
  end;
end;

end.
