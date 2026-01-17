unit fpdev.fpc.verify;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process;

type
  { TFPCVerifier - Verify FPC installation }
  TFPCVerifier = class
  private
    FLastError: string;
    function ExecuteCommand(const ACommand: string; const AArgs: array of string; out AOutput: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    { Parse FPC version from output string }
    function ParseVersion(const AOutput: string): string;

    { Get hello world source code }
    function GetHelloWorldSource: string;

    { Verify FPC installation at path }
    function VerifyVersion(const AFPCPath, AExpectedVersion: string): Boolean;

    { Compile hello world test }
    function CompileHelloWorld(const AFPCPath: string): Boolean;

    { Generate metadata file }
    function GenerateMetadata(const AInstallPath, AVersion: string): Boolean;

    { Get last error message }
    function GetLastError: string;
  end;

implementation

uses
  fpjson, jsonparser;

{ TFPCVerifier }

constructor TFPCVerifier.Create;
begin
  inherited Create;
  FLastError := '';
end;

destructor TFPCVerifier.Destroy;
begin
  inherited Destroy;
end;

function TFPCVerifier.ExecuteCommand(const ACommand: string; const AArgs: array of string; out AOutput: string): Boolean;
var
  Process: TProcess;
  OutputStream: TStringList;
  I: Integer;
begin
  Result := False;
  AOutput := '';
  FLastError := '';

  Process := TProcess.Create(nil);
  OutputStream := TStringList.Create;
  try
    Process.Executable := ACommand;
    for I := Low(AArgs) to High(AArgs) do
      Process.Parameters.Add(AArgs[I]);

    Process.Options := [poWaitOnExit, poUsePipes];

    try
      Process.Execute;
      
      // Read output
      while Process.Output.NumBytesAvailable > 0 do
        OutputStream.LoadFromStream(Process.Output);
      
      AOutput := OutputStream.Text;
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
    OutputStream.Free;
    Process.Free;
  end;
end;

function TFPCVerifier.ParseVersion(const AOutput: string): string;
var
  StartPos, EndPos: Integer;
begin
  Result := '';
  
  // Look for "version X.Y.Z" pattern
  StartPos := Pos('version ', LowerCase(AOutput));
  if StartPos > 0 then
  begin
    StartPos := StartPos + Length('version ');
    EndPos := StartPos;
    
    // Find end of version string (space, bracket, or end of line)
    while (EndPos <= Length(AOutput)) and 
          (AOutput[EndPos] in ['0'..'9', '.']) do
      Inc(EndPos);
    
    Result := Copy(AOutput, StartPos, EndPos - StartPos);
  end;
end;

function TFPCVerifier.GetHelloWorldSource: string;
begin
  Result := 'program hello;' + LineEnding +
            'begin' + LineEnding +
            '  WriteLn(''Hello, World!'');' + LineEnding +
            'end.' + LineEnding;
end;

function TFPCVerifier.VerifyVersion(const AFPCPath, AExpectedVersion: string): Boolean;
var
  Output, ActualVersion: string;
begin
  Result := False;
  
  if not ExecuteCommand(AFPCPath, ['-version'], Output) then
    Exit;
  
  ActualVersion := ParseVersion(Output);
  Result := ActualVersion = AExpectedVersion;
  
  if not Result then
    FLastError := Format('Version mismatch: expected %s, got %s', [AExpectedVersion, ActualVersion]);
end;

function TFPCVerifier.CompileHelloWorld(const AFPCPath: string): Boolean;
var
  TempDir, SourceFile, OutputFile: string;
  Source: TextFile;
  Output: string;
begin
  Result := False;
  
  // Create temporary directory
  TempDir := GetTempDir + 'fpdev_verify_' + IntToStr(Random(10000)) + PathDelim;
  ForceDirectories(TempDir);
  
  try
    // Write hello world source
    SourceFile := TempDir + 'hello.pas';
    AssignFile(Source, SourceFile);
    Rewrite(Source);
    Write(Source, GetHelloWorldSource);
    CloseFile(Source);
    
    // Compile
    OutputFile := TempDir + 'hello';
    Result := ExecuteCommand(AFPCPath, ['-o' + OutputFile, SourceFile], Output);
    
    if Result then
      Result := FileExists(OutputFile);
    
    if not Result then
      FLastError := 'Hello world compilation failed';
  finally
    // Cleanup
    if DirectoryExists(TempDir) then
    begin
      DeleteFile(TempDir + 'hello.pas');
      DeleteFile(TempDir + 'hello');
      DeleteFile(TempDir + 'hello.o');
      RemoveDir(TempDir);
    end;
  end;
end;

function TFPCVerifier.GenerateMetadata(const AInstallPath, AVersion: string): Boolean;
var
  MetaFile: string;
  JSON: TJSONObject;
  FileStream: TFileStream;
  JSONString: string;
begin
  Result := False;
  
  try
    MetaFile := AInstallPath + PathDelim + '.fpdev-meta.json';
    
    // Create JSON metadata
    JSON := TJSONObject.Create;
    try
      JSON.Add('version', AVersion);
      JSON.Add('install_date', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      JSON.Add('source_type', 'binary');
      JSON.Add('platform', 'linux-x86_64'); // TODO: Use actual platform detection
      
      JSONString := JSON.FormatJSON;
      
      // Write to file
      FileStream := TFileStream.Create(MetaFile, fmCreate);
      try
        FileStream.WriteBuffer(JSONString[1], Length(JSONString));
        Result := True;
      finally
        FileStream.Free;
      end;
    finally
      JSON.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to generate metadata: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TFPCVerifier.GetLastError: string;
begin
  Result := FLastError;
end;

end.
