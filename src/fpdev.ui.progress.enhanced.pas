unit fpdev.ui.progress.enhanced;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, fpdev.exitcodes,
  fpdev.ui.progress.download;

type
  { Progress stage status }
  TStageStatus = (
    ssWaiting,      // Stage not started yet
    ssRunning,      // Stage currently executing
    ssCompleted,    // Stage completed successfully
    ssFailed,       // Stage failed
    ssSkipped       // Stage skipped
  );

  { Progress stage information }
  TProgressStage = record
    Name: string;              // Stage name (e.g., "Downloading")
    Status: TStageStatus;      // Current status
    Progress: Integer;         // Progress percentage (0-100)
    StartTime: TDateTime;      // When stage started
    EndTime: TDateTime;        // When stage ended
    Message: string;           // Current status message
  end;

  { Array of progress stages }
  TProgressStages = array of TProgressStage;

  { Multi-stage progress tracker }
  TMultiStageProgress = class
  private
    FStages: TProgressStages;
    FCurrentStageIndex: Integer;
    FTotalStartTime: TDateTime;
    FShowETA: Boolean;
    FShowPercentage: Boolean;
    FShowSpinner: Boolean;

    function GetCurrentStage: TProgressStage;
    function GetOverallProgress: Integer;
    function CalculateETA: TDateTime;
    function FormatDuration(const ADuration: TDateTime): string;
    function GetStatusSymbol(AStatus: TStageStatus): string;
  public
    constructor Create;
    destructor Destroy; override;

    { Stage management }
    procedure AddStage(const AName: string);
    procedure StartStage(AIndex: Integer; const AMessage: string = '');
    procedure UpdateStage(AIndex: Integer; AProgress: Integer; const AMessage: string = '');
    procedure CompleteStage(AIndex: Integer; const AMessage: string = '');
    procedure FailStage(AIndex: Integer; const AMessage: string = '');
    procedure SkipStage(AIndex: Integer; const AMessage: string = '');

    { Display control }
    procedure Display;
    procedure DisplayCompact;
    procedure Clear;

    { Properties }
    property CurrentStage: TProgressStage read GetCurrentStage;
    property TotalProgress: Integer read GetOverallProgress;
    property ShowETA: Boolean read FShowETA write FShowETA;
    property ShowPercentage: Boolean read FShowPercentage write FShowPercentage;
    property ShowSpinner: Boolean read FShowSpinner write FShowSpinner;
    property Stages: TProgressStages read FStages;
  end;

  { TDownloadProgress is now in fpdev.ui.progress.download unit }
  { Re-exported via uses clause for backward compatibility }

  { Build progress tracker }
  TBuildProgress = class
  private
    FTotalUnits: Integer;
    FCompiledUnits: Integer;
    FCurrentUnit: string;
    FStartTime: TDateTime;

    function GetProgress: Integer;
    function GetETA: TDateTime;
    function FormatDuration(const ADuration: TDateTime): string;
  public
    constructor Create(ATotalUnits: Integer);

    { Update progress }
    procedure Update(ACompiledUnits: Integer; const ACurrentUnit: string = '');

    { Display progress }
    procedure Display;
    procedure DisplayCompact;

    { Properties }
    property TotalUnits: Integer read FTotalUnits write FTotalUnits;
    property CompiledUnits: Integer read FCompiledUnits;
    property CurrentUnit: string read FCurrentUnit;
    property Progress: Integer read GetProgress;
    property ETA: TDateTime read GetETA;
  end;

implementation

{ TMultiStageProgress }

constructor TMultiStageProgress.Create;
begin
  inherited Create;
  SetLength(FStages, 0);
  FCurrentStageIndex := -1;
  FTotalStartTime := Now;
  FShowETA := True;
  FShowPercentage := True;
  FShowSpinner := False;
end;

destructor TMultiStageProgress.Destroy;
begin
  inherited Destroy;
end;

function TMultiStageProgress.GetCurrentStage: TProgressStage;
begin
  if (FCurrentStageIndex >= 0) and (FCurrentStageIndex < Length(FStages)) then
    Result := FStages[FCurrentStageIndex]
  else
  begin
    Result.Name := '';
    Result.Status := ssWaiting;
    Result.Progress := 0;
    Result.Message := '';
  end;
end;

function TMultiStageProgress.GetOverallProgress: Integer;
var
  I: Integer;
  AccumulatedProgress: Integer;
begin
  if Length(FStages) = 0 then
    Exit(EXIT_OK);

  AccumulatedProgress := 0;
  for I := 0 to High(FStages) do
  begin
    case FStages[I].Status of
      ssCompleted: AccumulatedProgress := AccumulatedProgress + 100;
      ssRunning: AccumulatedProgress := AccumulatedProgress + FStages[I].Progress;
      ssSkipped: AccumulatedProgress := AccumulatedProgress + 100;
    end;
  end;

  Result := AccumulatedProgress div Length(FStages);
end;

function TMultiStageProgress.CalculateETA: TDateTime;
var
  ElapsedTime: TDateTime;
  ProgressPercent: Integer;
  EstimatedTotal: TDateTime;
begin
  ProgressPercent := GetOverallProgress;
  if ProgressPercent = 0 then
    Exit(EXIT_OK);

  ElapsedTime := Now - FTotalStartTime;
  EstimatedTotal := ElapsedTime * (100 / ProgressPercent);
  Result := EstimatedTotal - ElapsedTime;
end;

function TMultiStageProgress.FormatDuration(const ADuration: TDateTime): string;
var
  Seconds: Integer;
  Minutes: Integer;
  Hours: Integer;
begin
  Seconds := Round(ADuration * 24 * 60 * 60);

  if Seconds < 60 then
    Result := Format('%ds', [Seconds])
  else if Seconds < 3600 then
  begin
    Minutes := Seconds div 60;
    Seconds := Seconds mod 60;
    Result := Format('%dm %ds', [Minutes, Seconds]);
  end
  else
  begin
    Hours := Seconds div 3600;
    Minutes := (Seconds mod 3600) div 60;
    Result := Format('%dh %dm', [Hours, Minutes]);
  end;
end;

function TMultiStageProgress.GetStatusSymbol(AStatus: TStageStatus): string;
begin
  case AStatus of
    ssWaiting: Result := '○';
    ssRunning: Result := '⣾';
    ssCompleted: Result := '✓';
    ssFailed: Result := '✗';
    ssSkipped: Result := '⊘';
  else
    Result := '?';
  end;
end;

procedure TMultiStageProgress.AddStage(const AName: string);
var
  Idx: Integer;
begin
  Idx := Length(FStages);
  SetLength(FStages, Idx + 1);
  FStages[Idx].Name := AName;
  FStages[Idx].Status := ssWaiting;
  FStages[Idx].Progress := 0;
  FStages[Idx].Message := '';
end;

procedure TMultiStageProgress.StartStage(AIndex: Integer; const AMessage: string);
begin
  if (AIndex < 0) or (AIndex >= Length(FStages)) then
    Exit;

  FStages[AIndex].Status := ssRunning;
  FStages[AIndex].Progress := 0;
  FStages[AIndex].StartTime := Now;
  FStages[AIndex].Message := AMessage;
  FCurrentStageIndex := AIndex;
end;

procedure TMultiStageProgress.UpdateStage(AIndex: Integer; AProgress: Integer; const AMessage: string);
begin
  if (AIndex < 0) or (AIndex >= Length(FStages)) then
    Exit;

  FStages[AIndex].Progress := AProgress;
  if AMessage <> '' then
    FStages[AIndex].Message := AMessage;
end;

procedure TMultiStageProgress.CompleteStage(AIndex: Integer; const AMessage: string);
begin
  if (AIndex < 0) or (AIndex >= Length(FStages)) then
    Exit;

  FStages[AIndex].Status := ssCompleted;
  FStages[AIndex].Progress := 100;
  FStages[AIndex].EndTime := Now;
  if AMessage <> '' then
    FStages[AIndex].Message := AMessage;
end;

procedure TMultiStageProgress.FailStage(AIndex: Integer; const AMessage: string);
begin
  if (AIndex < 0) or (AIndex >= Length(FStages)) then
    Exit;

  FStages[AIndex].Status := ssFailed;
  FStages[AIndex].EndTime := Now;
  if AMessage <> '' then
    FStages[AIndex].Message := AMessage;
end;

procedure TMultiStageProgress.SkipStage(AIndex: Integer; const AMessage: string);
begin
  if (AIndex < 0) or (AIndex >= Length(FStages)) then
    Exit;

  FStages[AIndex].Status := ssSkipped;
  FStages[AIndex].EndTime := Now;
  if AMessage <> '' then
    FStages[AIndex].Message := AMessage;
end;

procedure TMultiStageProgress.Display;
var
  I: Integer;
  Stage: TProgressStage;
  ProgressBar: string;
  ProgressPercent: Integer;
  ETA: TDateTime;
begin
  WriteLn;

  // Display each stage
  for I := 0 to High(FStages) do
  begin
    Stage := FStages[I];
    Write('[', I + 1, '/', Length(FStages), '] ');
    Write(GetStatusSymbol(Stage.Status), ' ');
    Write(Stage.Name);

    if Stage.Status = ssRunning then
    begin
      if FShowPercentage and (Stage.Progress > 0) then
        Write(' (', Stage.Progress, '%)');

      if Stage.Message <> '' then
        WriteLn(' - ', Stage.Message)
      else
        WriteLn;
    end
    else if Stage.Message <> '' then
      WriteLn(' - ', Stage.Message)
    else
      WriteLn;
  end;

  // Display total progress
  if FShowPercentage then
  begin
    ProgressPercent := GetOverallProgress;
    WriteLn;
    Write('Overall Progress: [');

    // Progress bar
    ProgressBar := StringOfChar('#', ProgressPercent div 5);
    ProgressBar := ProgressBar + StringOfChar('-', 20 - (ProgressPercent div 5));
    Write(ProgressBar);
    Write('] ', ProgressPercent, '%');

    // ETA
    if FShowETA and (ProgressPercent > 0) and (ProgressPercent < 100) then
    begin
      ETA := CalculateETA;
      Write(' - ETA: ', FormatDuration(ETA));
    end;

    WriteLn;
  end;
end;

procedure TMultiStageProgress.DisplayCompact;
var
  Stage: TProgressStage;
  ProgressPercent: Integer;
begin
  if FCurrentStageIndex < 0 then
    Exit;

  Stage := FStages[FCurrentStageIndex];
  Write('[', FCurrentStageIndex + 1, '/', Length(FStages), '] ');
  Write(GetStatusSymbol(Stage.Status), ' ');
  Write(Stage.Name);

  if FShowPercentage and (Stage.Progress > 0) then
    Write(' (', Stage.Progress, '%)');

  if Stage.Message <> '' then
    Write(' - ', Stage.Message);

  // Total progress
  ProgressPercent := GetOverallProgress;
  Write(' [Overall: ', ProgressPercent, '%]');

  WriteLn;
end;

procedure TMultiStageProgress.Clear;
begin
  SetLength(FStages, 0);
  FCurrentStageIndex := -1;
  FTotalStartTime := Now;
end;

{ TDownloadProgress has been moved to fpdev.ui.progress.download unit }

{ TBuildProgress }

constructor TBuildProgress.Create(ATotalUnits: Integer);
begin
  inherited Create;
  FTotalUnits := ATotalUnits;
  FCompiledUnits := 0;
  FCurrentUnit := '';
  FStartTime := Now;
end;

function TBuildProgress.GetProgress: Integer;
begin
  if FTotalUnits = 0 then
    Exit(EXIT_OK);
  Result := Round((FCompiledUnits / FTotalUnits) * 100);
end;

function TBuildProgress.GetETA: TDateTime;
var
  ElapsedTime: TDateTime;
  TimePerUnit: Double;
  RemainingUnits: Integer;
  ETATime: TDateTime;
begin
  if FCompiledUnits = 0 then
    Exit(EXIT_OK);

  ElapsedTime := Now - FStartTime;
  TimePerUnit := ElapsedTime / FCompiledUnits;
  RemainingUnits := FTotalUnits - FCompiledUnits;
  ETATime := TimePerUnit * RemainingUnits;
  Result := ETATime;
end;

function TBuildProgress.FormatDuration(const ADuration: TDateTime): string;
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

procedure TBuildProgress.Update(ACompiledUnits: Integer; const ACurrentUnit: string);
begin
  FCompiledUnits := ACompiledUnits;
  if ACurrentUnit <> '' then
    FCurrentUnit := ACurrentUnit;
end;

procedure TBuildProgress.Display;
var
  ProgressBar: string;
  ProgressPercent: Integer;
  EstimatedTime: TDateTime;
begin
  ProgressPercent := GetProgress;

  Write('⚙ Compiling: ', FCompiledUnits, ' / ', FTotalUnits, ' units');
  Write(' (', ProgressPercent, '%)');

  if FCurrentUnit <> '' then
    WriteLn(' - ', FCurrentUnit)
  else
    WriteLn;

  // Progress bar
  Write('[');
  ProgressBar := StringOfChar('#', ProgressPercent div 5);
  ProgressBar := ProgressBar + StringOfChar('-', 20 - (ProgressPercent div 5));
  Write(ProgressBar);
  Write(']');

  if (ProgressPercent > 0) and (ProgressPercent < 100) then
  begin
    EstimatedTime := GetETA;
    if EstimatedTime > 0 then
      Write(' - ETA: ', FormatDuration(EstimatedTime));
  end;

  WriteLn;
end;

procedure TBuildProgress.DisplayCompact;
var
  ProgressPercent: Integer;
begin
  ProgressPercent := GetProgress;

  Write('⚙ ', FCompiledUnits, ' / ', FTotalUnits, ' units (', ProgressPercent, '%)');

  if FCurrentUnit <> '' then
    Write(' - ', FCurrentUnit);

  WriteLn;
end;

end.
