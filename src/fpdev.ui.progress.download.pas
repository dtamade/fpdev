unit fpdev.ui.progress.download;

{
================================================================================
  fpdev.ui.progress.download - Download Progress Tracker
================================================================================

  Provides download progress tracking with speed calculation and ETA estimation.

  Features:
  - Progress percentage calculation
  - Download speed measurement (bytes/second)
  - ETA (Estimated Time of Arrival) calculation
  - Human-readable byte/speed formatting
  - Console display methods (normal and compact)

  Extracted from fpdev.ui.progress.enhanced.pas for modularity.

  Usage:
    Progress := TDownloadProgress.Create(TotalFileSize);
    try
      while Downloading do
      begin
        Progress.Update(CurrentDownloadedBytes);
        Progress.DisplayCompact;
      end;
    finally
      Progress.Free;
    end;

  Author: FPDev Team
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, DateUtils;

type
  { TDownloadProgress - Download progress tracker with speed and ETA }
  TDownloadProgress = class
  private
    FTotalBytes: Int64;
    FDownloadedBytes: Int64;
    FStartTime: TDateTime;
    FLastUpdateTime: TDateTime;
    FLastDownloadedBytes: Int64;
    FCurrentSpeed: Double;  // Bytes per second

    function GetProgress: Integer;
    function GetETA: TDateTime;
    function FormatBytes(ABytes: Int64): string;
    function FormatSpeed(ABytesPerSecond: Double): string;
    function FormatDuration(const ADuration: TDateTime): string;
  public
    constructor Create(ATotalBytes: Int64);

    { Update progress with current downloaded bytes }
    procedure Update(ADownloadedBytes: Int64);

    { Reset progress for new download }
    procedure Reset(ATotalBytes: Int64);

    { Display progress to console }
    procedure Display;
    procedure DisplayCompact;

    { Get formatted progress string (for logging) }
    function GetProgressString: string;
    function GetCompactProgressString: string;

    { Properties }
    property TotalBytes: Int64 read FTotalBytes write FTotalBytes;
    property DownloadedBytes: Int64 read FDownloadedBytes;
    property Progress: Integer read GetProgress;
    property CurrentSpeed: Double read FCurrentSpeed;
    property ETA: TDateTime read GetETA;
    property StartTime: TDateTime read FStartTime;
  end;

implementation

{ TDownloadProgress }

constructor TDownloadProgress.Create(ATotalBytes: Int64);
begin
  inherited Create;
  FTotalBytes := ATotalBytes;
  FDownloadedBytes := 0;
  FStartTime := Now;
  FLastUpdateTime := Now;
  FLastDownloadedBytes := 0;
  FCurrentSpeed := 0;
end;

procedure TDownloadProgress.Reset(ATotalBytes: Int64);
begin
  FTotalBytes := ATotalBytes;
  FDownloadedBytes := 0;
  FStartTime := Now;
  FLastUpdateTime := Now;
  FLastDownloadedBytes := 0;
  FCurrentSpeed := 0;
end;

function TDownloadProgress.GetProgress: Integer;
begin
  if FTotalBytes = 0 then
    Exit(0);
  Result := Round((FDownloadedBytes / FTotalBytes) * 100);
end;

function TDownloadProgress.GetETA: TDateTime;
var
  RemainingBytes: Int64;
  ETASeconds: Double;
begin
  if FCurrentSpeed = 0 then
    Exit(0);

  RemainingBytes := FTotalBytes - FDownloadedBytes;
  ETASeconds := RemainingBytes / FCurrentSpeed;
  Result := ETASeconds / (24 * 60 * 60);
end;

function TDownloadProgress.FormatBytes(ABytes: Int64): string;
begin
  if ABytes < 1024 then
    Result := Format('%d B', [ABytes])
  else if ABytes < 1024 * 1024 then
    Result := Format('%.1f KB', [ABytes / 1024])
  else if ABytes < 1024 * 1024 * 1024 then
    Result := Format('%.1f MB', [ABytes / (1024 * 1024)])
  else
    Result := Format('%.2f GB', [ABytes / (1024 * 1024 * 1024)]);
end;

function TDownloadProgress.FormatSpeed(ABytesPerSecond: Double): string;
begin
  if ABytesPerSecond < 1024 then
    Result := Format('%.0f B/s', [ABytesPerSecond])
  else if ABytesPerSecond < 1024 * 1024 then
    Result := Format('%.1f KB/s', [ABytesPerSecond / 1024])
  else
    Result := Format('%.1f MB/s', [ABytesPerSecond / (1024 * 1024)]);
end;

function TDownloadProgress.FormatDuration(const ADuration: TDateTime): string;
var
  Seconds: Integer;
  Minutes: Integer;
begin
  Seconds := Round(ADuration * 24 * 60 * 60);

  if Seconds < 60 then
    Result := Format('%ds', [Seconds])
  else
  begin
    Minutes := Seconds div 60;
    Seconds := Seconds mod 60;
    Result := Format('%dm %ds', [Minutes, Seconds]);
  end;
end;

procedure TDownloadProgress.Update(ADownloadedBytes: Int64);
var
  CurrentTime: TDateTime;
  TimeDiff: Double;
  BytesDiff: Int64;
begin
  FDownloadedBytes := ADownloadedBytes;
  CurrentTime := Now;

  // Calculate speed
  TimeDiff := (CurrentTime - FLastUpdateTime) * 24 * 60 * 60;  // Convert to seconds
  if TimeDiff > 0 then
  begin
    BytesDiff := FDownloadedBytes - FLastDownloadedBytes;
    FCurrentSpeed := BytesDiff / TimeDiff;

    FLastUpdateTime := CurrentTime;
    FLastDownloadedBytes := FDownloadedBytes;
  end;
end;

function TDownloadProgress.GetProgressString: string;
var
  ProgressPercent: Integer;
  EstimatedTime: TDateTime;
  ProgressBar: string;
begin
  ProgressPercent := GetProgress;

  Result := Format('↓ %s / %s (%d%%)',
    [FormatBytes(FDownloadedBytes), FormatBytes(FTotalBytes), ProgressPercent]);

  if FCurrentSpeed > 0 then
    Result := Result + ' - ' + FormatSpeed(FCurrentSpeed);

  if (ProgressPercent > 0) and (ProgressPercent < 100) then
  begin
    EstimatedTime := GetETA;
    if EstimatedTime > 0 then
      Result := Result + ' - ETA: ' + FormatDuration(EstimatedTime);
  end;

  // Progress bar
  ProgressBar := '[' + StringOfChar('#', ProgressPercent div 5) +
                 StringOfChar('-', 20 - (ProgressPercent div 5)) + ']';
  Result := Result + LineEnding + ProgressBar;
end;

function TDownloadProgress.GetCompactProgressString: string;
var
  ProgressPercent: Integer;
begin
  ProgressPercent := GetProgress;

  Result := Format('↓ %s / %s (%d%%)',
    [FormatBytes(FDownloadedBytes), FormatBytes(FTotalBytes), ProgressPercent]);

  if FCurrentSpeed > 0 then
    Result := Result + ' - ' + FormatSpeed(FCurrentSpeed);
end;

procedure TDownloadProgress.Display;
begin
  WriteLn(GetProgressString);
end;

procedure TDownloadProgress.DisplayCompact;
begin
  WriteLn(GetCompactProgressString);
end;

end.
