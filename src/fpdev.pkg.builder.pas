unit fpdev.pkg.builder;

{
================================================================================
  fpdev.pkg.builder - Package Build Service
================================================================================

  Handles package building using lazbuild or make.
  Extracted from TPackageManager as part of Facade pattern refactoring.

  Usage:
    Builder := TPackageBuilder.Create;
    try
      if Builder.BuildPackage('/path/to/source') then
        WriteLn('Build tool: ', Builder.LastBuildTool);
    finally
      Builder.Free;
    end;

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.utils.fs, fpdev.utils.process, fpdev.paths;

type
  { TPackageBuilder - Package build service }
  TPackageBuilder = class
  private
    FLastBuildTool: string;
    FLastBuildLog: string;
    FKeepArtifacts: Boolean;

  public
    constructor Create;

    { Builds a package from source directory.
      Returns True if build succeeds or no build is needed.
      Supports: lazbuild (*.lpk), make (Makefile) }
    function BuildPackage(const ASourcePath: string): Boolean;

    { Last build tool used: 'lazbuild', 'make', or 'none' }
    property LastBuildTool: string read FLastBuildTool;

    { Path to last build log file }
    property LastBuildLog: string read FLastBuildLog;

    { Whether to keep build artifacts after build }
    property KeepArtifacts: Boolean read FKeepArtifacts write FKeepArtifacts;
  end;

implementation

{ TPackageBuilder }

constructor TPackageBuilder.Create;
begin
  inherited Create;
  FLastBuildTool := '';
  FLastBuildLog := '';
  FKeepArtifacts := False;
end;

function TPackageBuilder.BuildPackage(const ASourcePath: string): Boolean;
var
  LResult: TProcessResult;
  FoundLPK: string;
  SR: TSearchRec;
  LogPath: string;
  Log: TStringList;
  Executable: string;
  Params: array of string;
begin
  Result := False;

  if not DirectoryExists(ASourcePath) then
    Exit;

  try
    // Find and compile package: prefer lazbuild for Lazarus packages
    FoundLPK := '';
    if FindFirst(ASourcePath + PathDelim + '*.lpk', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Attr and faDirectory) = 0 then
        begin
          FoundLPK := ASourcePath + PathDelim + SR.Name;
          Break;
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    if FoundLPK <> '' then
    begin
      Executable := 'lazbuild';
      Params := nil;
      SetLength(Params, 1);
      Params[0] := FoundLPK;
      FLastBuildTool := 'lazbuild';
    end
    else if FileExists(ASourcePath + PathDelim + 'Makefile') then
    begin
      // Fall back to make
      Executable := 'make';
      SetLength(Params, 1);
      Params[0] := 'install';
      FLastBuildTool := 'make';
    end
    else
    begin
      FLastBuildTool := 'none';
      Exit(True);  // No build needed
    end;

    // Execute and capture output
    LResult := TProcessExecutor.Execute(Executable, Params, ASourcePath);

    // Write build log
    Log := TStringList.Create;
    try
      if LResult.StdOut <> '' then
        Log.Text := LResult.StdOut;
      if LResult.StdErr <> '' then
      begin
        Log.Add('--- STDERR ---');
        Log.Add(LResult.StdErr);
      end;

      // Write build log to logs directory
      LogPath := IncludeTrailingPathDelimiter(GetLogsDir) + 'build_' + IntToStr(GetTickCount64) + '.log';
      EnsureDir(ExtractFileDir(LogPath));
      Log.SaveToFile(LogPath);
      FLastBuildLog := LogPath;
    finally
      Log.Free;
    end;

    Result := LResult.Success;
  except
    Result := False;
  end;
end;

end.
