unit fpdev.ui.progress;

{$mode objfpc}{$H+}
// acq:allow-debug-output-file

interface

uses
  SysUtils, Classes;

type
  { Progress bar interface }
  IProgressBar = interface
    ['{E5A7B3C1-9F2D-4E8A-A1C3-5D6E7F8A9B0C}']
    procedure Start(const ATitle: string; ATotal: Int64);
    procedure Update(ACurrent: Int64);
    procedure UpdateWithMessage(ACurrent: Int64; const AMessage: string);
    procedure Finish;
    procedure FinishWithMessage(const AMessage: string);
    function GetCurrent: Int64;
    function GetTotal: Int64;
    function GetPercentage: Integer;
  end;

  { Console progress bar implementation }
  TConsoleProgressBar = class(TInterfacedObject, IProgressBar)
  private
    FTitle: string;
    FTotal: Int64;
    FCurrent: Int64;
    FStartTime: QWord;
    FLastUpdate: QWord;
    FUpdateInterval: Cardinal; // milliseconds
    FBarWidth: Integer;
    FShowETA: Boolean;
    FShowSpeed: Boolean;
    procedure DrawBar;
    function FormatSize(ASize: Int64): string;
    function FormatTime(ASeconds: Int64): string;
    function CalculateETA: Int64;
    function CalculateSpeed: Double; // bytes per second
  public
    constructor Create;

    // IProgressBar interface
    procedure Start(const ATitle: string; ATotal: Int64);
    procedure Update(ACurrent: Int64);
    procedure UpdateWithMessage(ACurrent: Int64; const AMessage: string);
    procedure Finish;
    procedure FinishWithMessage(const AMessage: string);
    function GetCurrent: Int64;
    function GetTotal: Int64;
    function GetPercentage: Integer;

    // Configuration
    property UpdateInterval: Cardinal read FUpdateInterval write FUpdateInterval;
    property BarWidth: Integer read FBarWidth write FBarWidth;
    property ShowETA: Boolean read FShowETA write FShowETA;
    property ShowSpeed: Boolean read FShowSpeed write FShowSpeed;
  end;

  { Silent progress bar (no output) - for non-interactive mode }
  TSilentProgressBar = class(TInterfacedObject, IProgressBar)
  private
    FTotal: Int64;
    FCurrent: Int64;
  public
    procedure Start(const ATitle: string; ATotal: Int64);
    procedure Update(ACurrent: Int64);
    procedure UpdateWithMessage(ACurrent: Int64; const AMessage: string);
    procedure Finish;
    procedure FinishWithMessage(const AMessage: string);
    function GetCurrent: Int64;
    function GetTotal: Int64;
    function GetPercentage: Integer;
  end;

{ Factory function - creates appropriate progress bar based on environment }
function CreateProgressBar: IProgressBar;

implementation

uses
  {$IFDEF UNIX}
  Unix,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  fpdev.config, fpdev.utils;

function GetTickCount64: QWord;
{$IFDEF UNIX}
var
  TV: TTimeVal;
{$ENDIF}
begin
  {$IFDEF UNIX}
  fpGetTimeOfDay(@TV, nil);
  Result := QWord(TV.tv_sec) * 1000 + QWord(TV.tv_usec div 1000);
  {$ELSE}
  Result := Windows.GetTickCount64;
  {$ENDIF}
end;

function CreateProgressBar: IProgressBar;
begin
  // Check if in non-interactive mode (CI/CD)
  if (get_env('FPDEV_NONINTERACTIVE') = '1') or
     (get_env('CI') = 'true') then
    Result := TSilentProgressBar.Create
  else
    Result := TConsoleProgressBar.Create;
end;

{ TConsoleProgressBar }

constructor TConsoleProgressBar.Create;
begin
  inherited Create;
  FUpdateInterval := 100; // Update every 100ms
  FBarWidth := 40;
  FShowETA := True;
  FShowSpeed := True;
end;

procedure TConsoleProgressBar.Start(const ATitle: string; ATotal: Int64);
begin
  FTitle := ATitle;
  FTotal := ATotal;
  FCurrent := 0;
  FStartTime := GetTickCount64;
  FLastUpdate := 0;

  WriteLn(FTitle);
  DrawBar;
end;

procedure TConsoleProgressBar.Update(ACurrent: Int64);
var
  Now: QWord;
begin
  FCurrent := ACurrent;

  // Throttle updates to avoid flicker
  Now := GetTickCount64;
  if (Now - FLastUpdate) < FUpdateInterval then
    Exit;

  FLastUpdate := Now;
  DrawBar;
end;

procedure TConsoleProgressBar.UpdateWithMessage(ACurrent: Int64; const AMessage: string);
begin
  Update(ACurrent);
  if AMessage <> '' then
  begin
    Write(#13);
    Write(' ':80); // Clear line
    Write(#13);
    WriteLn(AMessage);
    DrawBar;
  end;
end;

procedure TConsoleProgressBar.Finish;
begin
  FCurrent := FTotal;
  DrawBar;
  WriteLn; // New line after progress bar
end;

procedure TConsoleProgressBar.FinishWithMessage(const AMessage: string);
begin
  Finish;
  if AMessage <> '' then
    WriteLn(AMessage);
end;

function TConsoleProgressBar.GetCurrent: Int64;
begin
  Result := FCurrent;
end;

function TConsoleProgressBar.GetTotal: Int64;
begin
  Result := FTotal;
end;

function TConsoleProgressBar.GetPercentage: Integer;
begin
  if FTotal = 0 then
    Result := 0
  else
    Result := Trunc((FCurrent * 100.0) / FTotal);
end;

procedure TConsoleProgressBar.DrawBar;
var
  Percentage: Integer;
  FilledWidth: Integer;
  I: Integer;
  Bar: string;
  Status: string;
  ETA: Int64;
  Speed: Double;
begin
  Percentage := GetPercentage;
  FilledWidth := (Percentage * FBarWidth) div 100;

  // Build progress bar
  Bar := '[';
  for I := 1 to FBarWidth do
  begin
    if I <= FilledWidth then
      Bar += '='
    else if I = FilledWidth + 1 then
      Bar += '>'
    else
      Bar += ' ';
  end;
  Bar += ']';

  // Build status string
  Status := Format(' %3d%% ', [Percentage]);

  if FTotal > 0 then
    Status += Format('(%s/%s)', [FormatSize(FCurrent), FormatSize(FTotal)]);

  if FShowSpeed and (FCurrent > 0) then
  begin
    Speed := CalculateSpeed;
    if Speed > 0 then
      Status += Format(' %s/s', [FormatSize(Trunc(Speed))]);
  end;

  if FShowETA and (Percentage > 0) and (Percentage < 100) then
  begin
    ETA := CalculateETA;
    if ETA > 0 then
      Status += Format(' ETA: %s', [FormatTime(ETA)]);
  end;

  // Output (carriage return to overwrite previous line)
  Write(#13, Bar, Status);

  // Don't flush too often
end;

function TConsoleProgressBar.FormatSize(ASize: Int64): string;
const
  KB = 1024;
  MB = KB * 1024;
  GB = MB * 1024;
begin
  if ASize < KB then
    Result := Format('%dB', [ASize])
  else if ASize < MB then
    Result := Format('%.1fKB', [ASize / KB])
  else if ASize < GB then
    Result := Format('%.1fMB', [ASize / MB])
  else
    Result := Format('%.2fGB', [ASize / GB]);
end;

function TConsoleProgressBar.FormatTime(ASeconds: Int64): string;
var
  Hours, Minutes, Seconds: Int64;
begin
  Hours := ASeconds div 3600;
  Minutes := (ASeconds mod 3600) div 60;
  Seconds := ASeconds mod 60;

  if Hours > 0 then
    Result := Format('%dh %dm', [Hours, Minutes])
  else if Minutes > 0 then
    Result := Format('%dm %ds', [Minutes, Seconds])
  else
    Result := Format('%ds', [Seconds]);
end;

function TConsoleProgressBar.CalculateETA: Int64;
var
  Elapsed: Int64;
  Rate: Double;
  Remaining: Int64;
begin
  Result := 0;

  if (FCurrent = 0) or (FTotal = 0) then
    Exit;

  Elapsed := (GetTickCount64 - FStartTime) div 1000; // seconds
  if Elapsed = 0 then
    Exit;

  Rate := FCurrent / Elapsed;
  Remaining := FTotal - FCurrent;

  if Rate > 0 then
    Result := Trunc(Remaining / Rate);
end;

function TConsoleProgressBar.CalculateSpeed: Double;
var
  Elapsed: Double;
begin
  Result := 0;

  if FCurrent = 0 then
    Exit;

  Elapsed := (GetTickCount64 - FStartTime) / 1000.0; // seconds
  if Elapsed > 0 then
    Result := FCurrent / Elapsed;
end;

{ TSilentProgressBar }

procedure TSilentProgressBar.Start(const ATitle: string; ATotal: Int64);
begin
  FTotal := ATotal;
  FCurrent := 0;
  // No output in silent mode
end;

procedure TSilentProgressBar.Update(ACurrent: Int64);
begin
  FCurrent := ACurrent;
  // No output
end;

procedure TSilentProgressBar.UpdateWithMessage(ACurrent: Int64; const AMessage: string);
begin
  FCurrent := ACurrent;
  // No output
end;

procedure TSilentProgressBar.Finish;
begin
  FCurrent := FTotal;
  // No output
end;

procedure TSilentProgressBar.FinishWithMessage(const AMessage: string);
begin
  FCurrent := FTotal;
  // No output
end;

function TSilentProgressBar.GetCurrent: Int64;
begin
  Result := FCurrent;
end;

function TSilentProgressBar.GetTotal: Int64;
begin
  Result := FTotal;
end;

function TSilentProgressBar.GetPercentage: Integer;
begin
  if FTotal = 0 then
    Result := 0
  else
    Result := Trunc((FCurrent * 100.0) / FTotal);
end;

end.
