unit fpdev.archive.extract;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process;

type
  TArchiveFormat = (afUnknown, afTarGz, afTarBz2, afZip);

  { TArchiveExtractor - Extract compressed archives }
  TArchiveExtractor = class
  private
    FLastError: string;
    function ExecuteCommand(const ACommand: string; const AArgs: array of string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    { Detect archive format from filename }
    function DetectFormat(const AFileName: string): TArchiveFormat;

    { Extract archive to destination directory }
    function Extract(const AArchive, ADestDir: string): Boolean;

    { Get last error message }
    function GetLastError: string;
  end;

implementation

{ TArchiveExtractor }

constructor TArchiveExtractor.Create;
begin
  inherited Create;
  FLastError := '';
end;

destructor TArchiveExtractor.Destroy;
begin
  inherited Destroy;
end;

function TArchiveExtractor.DetectFormat(const AFileName: string): TArchiveFormat;
var
  Ext: string;
begin
  Result := afUnknown;
  Ext := LowerCase(ExtractFileExt(AFileName));

  if (Ext = '.gz') and (LowerCase(ExtractFileExt(ChangeFileExt(AFileName, ''))) = '.tar') then
    Result := afTarGz
  else if (Ext = '.bz2') and (LowerCase(ExtractFileExt(ChangeFileExt(AFileName, ''))) = '.tar') then
    Result := afTarBz2
  else if Ext = '.zip' then
    Result := afZip;
end;

function TArchiveExtractor.ExecuteCommand(const ACommand: string; const AArgs: array of string): Boolean;
var
  Process: TProcess;
  I: Integer;
begin
  Result := False;
  FLastError := '';

  Process := TProcess.Create(nil);
  try
    Process.Executable := ACommand;
    for I := Low(AArgs) to High(AArgs) do
      Process.Parameters.Add(AArgs[I]);

    Process.Options := [poWaitOnExit, poUsePipes];

    try
      Process.Execute;
      Result := Process.ExitStatus = 0;

      if not Result then
        FLastError := Format('Command failed with exit code %d', [Process.ExitStatus]);
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        Result := False;
      end;
    end;
  finally
    Process.Free;
  end;
end;

function TArchiveExtractor.Extract(const AArchive, ADestDir: string): Boolean;
var
  Format: TArchiveFormat;
begin
  Result := False;
  FLastError := '';

  if not FileExists(AArchive) then
  begin
    FLastError := 'Archive file not found: ' + AArchive;
    Exit;
  end;

  // Create destination directory
  if not ForceDirectories(ADestDir) then
  begin
    FLastError := 'Failed to create destination directory: ' + ADestDir;
    Exit;
  end;

  Format := DetectFormat(AArchive);

  case Format of
    afTarGz, afTarBz2:
      Result := ExecuteCommand('tar', ['-xf', AArchive, '-C', ADestDir]);
    afZip:
      Result := ExecuteCommand('unzip', ['-q', AArchive, '-d', ADestDir]);
    else
    begin
      FLastError := 'Unsupported archive format';
      Result := False;
    end;
  end;
end;

function TArchiveExtractor.GetLastError: string;
begin
  Result := FLastError;
end;

end.
