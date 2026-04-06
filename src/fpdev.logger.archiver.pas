unit fpdev.logger.archiver;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils;

type
  { TArchiveConfig - Archive configuration }
  TArchiveConfig = record
    Enabled: Boolean;
    CompressionLevel: Integer;  // 0-9, 0=no compression, 9=max compression
    ArchiveDir: string;
    MaxArchiveAge: Integer;  // Days to keep archives
  end;

  { ILogArchiver - Log archiver interface }
  ILogArchiver = interface
    ['{7E8F9A0B-1C2D-3E4F-5A6B-7C8D9E0F1A2B}']
    function ShouldArchive(const ALogFile: string): Boolean;
    function Archive(const ALogFile: string): string;
    function ArchiveAll(const ALogDir: string): Integer;
    procedure CleanupOldArchives;
  end;

  { TLogArchiver - Log archiver implementation }
  TLogArchiver = class(TInterfacedObject, ILogArchiver)
  private
    FConfig: TArchiveConfig;

    function CompressFile(const ASourceFile, ADestFile: string): Boolean;
    function GetArchivePath(const ALogFile: string): string;
    function IsRotatedLogFile(const AFileName: string): Boolean;
  public
    constructor Create(const AConfig: TArchiveConfig);

    function ShouldArchive(const ALogFile: string): Boolean;
    function Archive(const ALogFile: string): string;
    function ArchiveAll(const ALogDir: string): Integer;
    procedure CleanupOldArchives;
  end;

{ Helper functions }
function CreateDefaultArchiveConfig: TArchiveConfig;

implementation

uses
  zstream;

{ Helper functions }

function CreateDefaultArchiveConfig: TArchiveConfig;
begin
  Result.Enabled := True;
  Result.CompressionLevel := 6;  // Default compression level
  Result.ArchiveDir := 'logs' + PathDelim + 'archive';
  Result.MaxArchiveAge := 30;  // 30 days
end;

{ TLogArchiver }

constructor TLogArchiver.Create(const AConfig: TArchiveConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

function TLogArchiver.IsRotatedLogFile(const AFileName: string): Boolean;
var
  Ext: string;
  LastChar: Char;
begin
  Result := False;

  // Check if file has .N extension (e.g., .1, .2, .3)
  Ext := ExtractFileExt(AFileName);
  if Ext = '' then
    Exit;

  // Remove the dot
  Ext := Copy(Ext, 2, Length(Ext));

  // Check if extension is a number
  if Ext = '' then
    Exit;

  LastChar := Ext[Length(Ext)];
  Result := (LastChar >= '0') and (LastChar <= '9');
end;

function TLogArchiver.ShouldArchive(const ALogFile: string): Boolean;
begin
  Result := False;

  if not FConfig.Enabled then
    Exit;

  if not FileExists(ALogFile) then
    Exit;

  // Only archive rotated log files (e.g., app.log.1, app.log.2)
  Result := IsRotatedLogFile(ExtractFileName(ALogFile));
end;

function TLogArchiver.GetArchivePath(const ALogFile: string): string;
var
  FileName: string;
begin
  FileName := ExtractFileName(ALogFile);
  Result := FConfig.ArchiveDir + PathDelim + FileName + '.gz';
end;

function TLogArchiver.CompressFile(const ASourceFile, ADestFile: string): Boolean;
var
  SourceStream: TFileStream;
  DestStream: TFileStream;
  CompressStream: TCompressionStream;
  Buffer: array[0..8191] of Byte;
  BytesRead: Integer;
  Level: TCompressionLevel;
begin
  Result := False;

  // Map integer compression level to TCompressionLevel enum
  case FConfig.CompressionLevel of
    0: Level := clnone;
    1..3: Level := clfastest;
    4..6: Level := cldefault;
  else
    Level := clmax;
  end;

  try
    // Open source file
    SourceStream := TFileStream.Create(ASourceFile, fmOpenRead or fmShareDenyWrite);
    try
      // Create destination file
      DestStream := TFileStream.Create(ADestFile, fmCreate);
      try
        // Create compression stream
        CompressStream := TCompressionStream.Create(Level, DestStream);
        try
          // Copy and compress data
          repeat
            BytesRead := SourceStream.Read(Buffer, SizeOf(Buffer));
            if BytesRead > 0 then
              CompressStream.Write(Buffer, BytesRead);
          until BytesRead = 0;

          Result := True;
        finally
          CompressStream.Free;
        end;
      finally
        DestStream.Free;
      end;
    finally
      SourceStream.Free;
    end;
  except
    on E: Exception do
    begin
      // If compression failed, delete partial file
      if FileExists(ADestFile) then
        DeleteFile(ADestFile);
      Result := False;
    end;
  end;
end;

function TLogArchiver.Archive(const ALogFile: string): string;
var
  ArchivePath: string;
begin
  Result := '';

  if not FConfig.Enabled then
    Exit;

  if not ShouldArchive(ALogFile) then
    Exit;

  // Ensure archive directory exists
  if not DirectoryExists(FConfig.ArchiveDir) then
    ForceDirectories(FConfig.ArchiveDir);

  // Get archive path
  ArchivePath := GetArchivePath(ALogFile);

  // Compress file
  if CompressFile(ALogFile, ArchivePath) then
  begin
    // Delete original file after successful compression
    DeleteFile(ALogFile);
    Result := ArchivePath;
  end;
end;

function TLogArchiver.ArchiveAll(const ALogDir: string): Integer;
var
  SR: TSearchRec;
  FilePath: string;
  ArchivePath: string;
  FilesToArchive: TStringList;
  i: Integer;
begin
  Result := 0;

  if not FConfig.Enabled then
    Exit;

  if not DirectoryExists(ALogDir) then
    Exit;

  // First, collect all files to archive
  FilesToArchive := TStringList.Create;
  try
    if FindFirst(ALogDir + PathDelim + '*.*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) = 0) then
        begin
          FilePath := ALogDir + PathDelim + SR.Name;

          if ShouldArchive(FilePath) then
            FilesToArchive.Add(FilePath);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    // Then, archive all collected files
    for i := 0 to FilesToArchive.Count - 1 do
    begin
      ArchivePath := Archive(FilesToArchive[i]);
      if ArchivePath <> '' then
        Inc(Result);
    end;
  finally
    FilesToArchive.Free;
  end;
end;

procedure TLogArchiver.CleanupOldArchives;
var
  SR: TSearchRec;
  FilePath: string;
  FileAge: TDateTime;
  AgeInDays: Integer;
begin
  if not FConfig.Enabled then
    Exit;

  if not DirectoryExists(FConfig.ArchiveDir) then
    Exit;

  // Find all archive files
  if FindFirst(FConfig.ArchiveDir + PathDelim + '*.gz', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) = 0) then
      begin
        FilePath := FConfig.ArchiveDir + PathDelim + SR.Name;

        // Check age
        FileAge := SR.TimeStamp;
        AgeInDays := DaysBetween(Now, FileAge);

        if AgeInDays >= FConfig.MaxArchiveAge then
          DeleteFile(FilePath);
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

end.
