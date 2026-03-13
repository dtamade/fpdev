unit fpdev.perf.monitor;

{
================================================================================
  fpdev.perf.monitor - Performance Monitoring System
================================================================================

  Provides lightweight performance monitoring for build operations:
  - Operation timing with millisecond precision
  - Memory usage tracking (when available)
  - Hierarchical operation tracking (parent-child)
  - JSON report generation
  - Integration with existing logging system

  Usage:
    PerfMon.StartOperation('BuildCompiler');
    // ... do work ...
    PerfMon.EndOperation('BuildCompiler');
    PerfMon.SaveReport('perf_report.json');

  Thread-safe for basic operations.

  Author: FPDev Team
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, fpjson, jsonparser, StrUtils;

type
  { TPerfOperation - Single performance operation record }
  TPerfOperation = record
    Name: string;
    StartTime: TDateTime;
    EndTime: TDateTime;
    ElapsedMs: Int64;
    Success: Boolean;
    ParentName: string;
    MemoryBefore: Int64;
    MemoryAfter: Int64;
    Metadata: string;
  end;
  PPerfOperation = ^TPerfOperation;

  { TPerfOperations - Dynamic array of operations }
  TPerfOperations = array of TPerfOperation;

  { TPerfMonitor - Performance monitoring class }
  TPerfMonitor = class
  private
    FOperations: TPerfOperations;
    FActiveOps: TStringList;
    FEnabled: Boolean;
    FStartTime: TDateTime;

    function FindOperation(const AName: string): Integer;
    function GetCurrentMemory: Int64;
    function GetElapsedMs(AStart, AEnd: TDateTime): Int64;
  public
    constructor Create;
    destructor Destroy; override;

    { Operation tracking }
    procedure StartOperation(const AName: string; const AParent: string = '');
    procedure EndOperation(const AName: string; ASuccess: Boolean = True);
    procedure SetMetadata(const AName, AMetadata: string);

    { Timing helpers }
    procedure Mark(const AName: string);
    function GetOperationTime(const AName: string): Int64;
    function GetTotalTime: Int64;

    { Reporting }
    function GetReport: string;
    function GetSummary: string;
    procedure SaveReport(const AFileName: string);
    procedure Clear;

    { Properties }
    property Enabled: Boolean read FEnabled write FEnabled;
    property Operations: TPerfOperations read FOperations;
    property TotalTimeMs: Int64 read GetTotalTime;
  end;

{ Global performance monitor instance }
function PerfMon: TPerfMonitor;

{ Utility: Format milliseconds as human-readable string }
function FormatElapsedTime(AMs: Int64): string;

implementation

{$IFDEF MSWINDOWS}
uses
  Windows;
{$ENDIF}

{$IFDEF MSWINDOWS}
type
  { Minimal PROCESS_MEMORY_COUNTERS struct for GetProcessMemoryInfo }
  TProcessMemoryCounters = record
    cb: DWORD;
    PageFaultCount: DWORD;
    PeakWorkingSetSize: NativeUInt;
    WorkingSetSize: NativeUInt;
    QuotaPeakPagedPoolUsage: NativeUInt;
    QuotaPagedPoolUsage: NativeUInt;
    QuotaPeakNonPagedPoolUsage: NativeUInt;
    QuotaNonPagedPoolUsage: NativeUInt;
    PagefileUsage: NativeUInt;
    PeakPagefileUsage: NativeUInt;
  end;
  PProcessMemoryCounters = ^TProcessMemoryCounters;

function GetProcessMemoryInfo(hProcess: THandle; ppsmemCounters: PProcessMemoryCounters;
  cb: DWORD): BOOL; stdcall; external 'psapi.dll';
{$ENDIF}

const
  PROC_SELF_STATUS_PATH = '/proc/self/status';

var
  GlobalPerfMon: TPerfMonitor = nil;

function PerfMon: TPerfMonitor;
begin
  if GlobalPerfMon = nil then
    GlobalPerfMon := TPerfMonitor.Create;
  Result := GlobalPerfMon;
end;

function FormatElapsedTime(AMs: Int64): string;
var
  Secs, Mins, Hours: Int64;
begin
  if AMs < 1000 then
    Result := IntToStr(AMs) + 'ms'
  else if AMs < 60000 then
  begin
    Secs := AMs div 1000;
    Result := IntToStr(Secs) + '.' + Format('%.3d', [AMs mod 1000]) + 's';
  end
  else if AMs < 3600000 then
  begin
    Mins := AMs div 60000;
    Secs := (AMs mod 60000) div 1000;
    Result := IntToStr(Mins) + 'm ' + IntToStr(Secs) + 's';
  end
  else
  begin
    Hours := AMs div 3600000;
    Mins := (AMs mod 3600000) div 60000;
    Secs := (AMs mod 60000) div 1000;
    Result := IntToStr(Hours) + 'h ' + IntToStr(Mins) + 'm ' + IntToStr(Secs) + 's';
  end;
end;

{ TPerfMonitor }

constructor TPerfMonitor.Create;
begin
  inherited Create;
  FActiveOps := TStringList.Create;
  FEnabled := True;
  FStartTime := Now;
  SetLength(FOperations, 0);
end;

destructor TPerfMonitor.Destroy;
begin
  FActiveOps.Free;
  SetLength(FOperations, 0);
  inherited Destroy;
end;

function TPerfMonitor.FindOperation(const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := High(FOperations) downto 0 do
    if FOperations[I].Name = AName then
    begin
      Result := I;
      Exit;
    end;
end;

function TPerfMonitor.GetCurrentMemory: Int64;
{$IFDEF LINUX}
var
  F: TextFile;
  Line: string;
  Parts: TStringArray;
{$ENDIF}
{$IFDEF MSWINDOWS}
var
  Counters: TProcessMemoryCounters;
{$ENDIF}
begin
  Result := 0;
  {$IFDEF LINUX}
  try
    AssignFile(F, PROC_SELF_STATUS_PATH);
    Reset(F);
    try
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        if Pos('VmRSS:', Line) = 1 then
        begin
          // Format: VmRSS:    12345 kB
          Line := Trim(Copy(Line, 7, Length(Line)));
          Parts := Line.Split([' '], TStringSplitOptions.ExcludeEmpty);
          if Length(Parts) > 0 then
            Result := StrToInt64Def(Parts[0], 0) * 1024; // Convert KB to bytes
          Break;
        end;
      end;
    finally
      CloseFile(F);
    end;
  except
    Result := 0;
  end;
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  FillChar(Counters, SizeOf(Counters), 0);
  Counters.cb := SizeOf(Counters);
  if GetProcessMemoryInfo(GetCurrentProcess, @Counters, Counters.cb) then
    Result := Int64(Counters.WorkingSetSize);
  {$ENDIF}
end;

function TPerfMonitor.GetElapsedMs(AStart, AEnd: TDateTime): Int64;
begin
  Result := MilliSecondsBetween(AEnd, AStart);
end;

procedure TPerfMonitor.StartOperation(const AName: string; const AParent: string);
var
  Idx: Integer;
begin
  if not FEnabled then Exit;

  // Check if already started
  if FActiveOps.IndexOf(AName) >= 0 then Exit;

  Idx := Length(FOperations);
  SetLength(FOperations, Idx + 1);

  FOperations[Idx].Name := AName;
  FOperations[Idx].StartTime := Now;
  FOperations[Idx].EndTime := 0;
  FOperations[Idx].ElapsedMs := 0;
  FOperations[Idx].Success := False;
  FOperations[Idx].ParentName := AParent;
  FOperations[Idx].MemoryBefore := GetCurrentMemory;
  FOperations[Idx].MemoryAfter := 0;
  FOperations[Idx].Metadata := '';

  FActiveOps.Add(AName);
end;

procedure TPerfMonitor.EndOperation(const AName: string; ASuccess: Boolean);
var
  Idx, ActiveIdx: Integer;
begin
  if not FEnabled then Exit;

  ActiveIdx := FActiveOps.IndexOf(AName);
  if ActiveIdx < 0 then Exit;

  Idx := FindOperation(AName);
  if Idx < 0 then Exit;

  FOperations[Idx].EndTime := Now;
  FOperations[Idx].ElapsedMs := GetElapsedMs(FOperations[Idx].StartTime, FOperations[Idx].EndTime);
  FOperations[Idx].Success := ASuccess;
  FOperations[Idx].MemoryAfter := GetCurrentMemory;

  FActiveOps.Delete(ActiveIdx);
end;

procedure TPerfMonitor.SetMetadata(const AName, AMetadata: string);
var
  Idx: Integer;
begin
  if not FEnabled then Exit;

  Idx := FindOperation(AName);
  if Idx >= 0 then
    FOperations[Idx].Metadata := AMetadata;
end;

procedure TPerfMonitor.Mark(const AName: string);
begin
  StartOperation(AName);
  EndOperation(AName, True);
end;

function TPerfMonitor.GetOperationTime(const AName: string): Int64;
var
  Idx: Integer;
begin
  Result := 0;
  Idx := FindOperation(AName);
  if Idx >= 0 then
    Result := FOperations[Idx].ElapsedMs;
end;

function TPerfMonitor.GetTotalTime: Int64;
begin
  Result := GetElapsedMs(FStartTime, Now);
end;

function TPerfMonitor.GetReport: string;
var
  JArr: TJSONArray;
  JObj: TJSONObject;
  I: Integer;
  Op: TPerfOperation;
begin
  JArr := TJSONArray.Create;
  try
    for I := 0 to High(FOperations) do
    begin
      Op := FOperations[I];
      JObj := TJSONObject.Create;
      JObj.Add('name', Op.Name);
      JObj.Add('elapsed_ms', Op.ElapsedMs);
      JObj.Add('success', Op.Success);
      if Op.ParentName <> '' then
        JObj.Add('parent', Op.ParentName);
      if Op.MemoryBefore > 0 then
        JObj.Add('memory_before_kb', Op.MemoryBefore div 1024);
      if Op.MemoryAfter > 0 then
        JObj.Add('memory_after_kb', Op.MemoryAfter div 1024);
      if Op.Metadata <> '' then
        JObj.Add('metadata', Op.Metadata);
      JObj.Add('start_time', FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Op.StartTime));
      if Op.EndTime > 0 then
        JObj.Add('end_time', FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Op.EndTime));
      JArr.Add(JObj);
    end;

    Result := JArr.FormatJSON([foSingleLineArray]);
  finally
    JArr.Free;
  end;
end;

function TPerfMonitor.GetSummary: string;
var
  I: Integer;
  Op: TPerfOperation;
  TotalMs: Int64;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('=== Performance Summary ===');
    Lines.Add('');

    TotalMs := 0;
    for I := 0 to High(FOperations) do
    begin
      Op := FOperations[I];
      if Op.EndTime > 0 then
      begin
        Lines.Add(Format('  %-30s %10s  %s',
          [Op.Name, FormatElapsedTime(Op.ElapsedMs),
           IfThen(Op.Success, '[OK]', '[FAIL]')]));
        Inc(TotalMs, Op.ElapsedMs);
      end
      else
        Lines.Add(Format('  %-30s %10s  [RUNNING]', [Op.Name, '...']));
    end;

    Lines.Add('');
    Lines.Add(Format('  %-30s %10s', ['Total', FormatElapsedTime(TotalMs)]));
    Lines.Add('===========================');

    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

procedure TPerfMonitor.SaveReport(const AFileName: string);
var
  JRoot: TJSONObject;
  JOps: TJSONArray;
  JObj: TJSONObject;
  I: Integer;
  Op: TPerfOperation;
  SL: TStringList;
begin
  JRoot := TJSONObject.Create;
  try
    JRoot.Add('generated_at', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    JRoot.Add('total_time_ms', GetTotalTime);

    JOps := TJSONArray.Create;
    for I := 0 to High(FOperations) do
    begin
      Op := FOperations[I];
      JObj := TJSONObject.Create;
      JObj.Add('name', Op.Name);
      JObj.Add('elapsed_ms', Op.ElapsedMs);
      JObj.Add('elapsed_human', FormatElapsedTime(Op.ElapsedMs));
      JObj.Add('success', Op.Success);
      if Op.ParentName <> '' then
        JObj.Add('parent', Op.ParentName);
      if Op.MemoryBefore > 0 then
        JObj.Add('memory_before_kb', Op.MemoryBefore div 1024);
      if Op.MemoryAfter > 0 then
        JObj.Add('memory_after_kb', Op.MemoryAfter div 1024);
      if Op.Metadata <> '' then
        JObj.Add('metadata', Op.Metadata);
      JOps.Add(JObj);
    end;
    JRoot.Add('operations', JOps);

    SL := TStringList.Create;
    try
      SL.Text := JRoot.FormatJSON;
      SL.SaveToFile(AFileName);
    finally
      SL.Free;
    end;
  finally
    JRoot.Free;
  end;
end;

procedure TPerfMonitor.Clear;
begin
  SetLength(FOperations, 0);
  FActiveOps.Clear;
  FStartTime := Now;
end;

initialization

finalization
  if GlobalPerfMon <> nil then
    GlobalPerfMon.Free;

end.
