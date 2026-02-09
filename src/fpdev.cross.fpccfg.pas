unit fpdev.cross.fpccfg;

{
  TFPCCfgManager - fpc.cfg cross-compilation section manager

  Manages cross-compilation configuration sections in fpc.cfg.
  Each target gets a delimited section:

    # BEGIN fpdev-cross:arm-linux
    #IFDEF CPUARM
    #IFDEF LINUX
    -FD/usr/bin
    -XParm-linux-gnueabihf-
    -Fl/usr/arm-linux-gnueabihf/lib
    -Xd
    -CaEABIHF
    -CfVFPV3
    #ENDIF
    #ENDIF
    # END fpdev-cross:arm-linux

  This allows safe insert/update/remove without affecting other config.
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config.interfaces;

type
  { TFPCCfgManager - Manage cross-compilation sections in fpc.cfg }
  TFPCCfgManager = class
  private
    FLines: TStringList;
    FFilePath: string;
    FLastError: string;
    function GetSectionTag(const ACPU, AOS: string): string;
    function GetBeginTag(const ACPU, AOS: string): string;
    function GetEndTag(const ACPU, AOS: string): string;
    function FindSectionRange(const ACPU, AOS: string;
      out AStartLine, AEndLine: Integer): Boolean;
    function BuildSectionLines(const ATarget: TCrossTarget): TStringList;
  public
    constructor Create(const AFilePath: string);
    destructor Destroy; override;

    { LoadFromFile - Load fpc.cfg content from file }
    function LoadFromFile: Boolean;
    { LoadFromString - Load content from string (for testing) }
    procedure LoadFromString(const AContent: string);
    { SaveToFile - Write content back to fpc.cfg }
    function SaveToFile: Boolean;
    { GetContent - Get current content as string }
    function GetContent: string;

    { HasCrossTarget - Check if a cross-target section exists }
    function HasCrossTarget(const ACPU, AOS: string): Boolean;
    { InsertCrossTarget - Add a new cross-target section }
    function InsertCrossTarget(const ATarget: TCrossTarget): Boolean;
    { UpdateCrossTarget - Replace existing cross-target section }
    function UpdateCrossTarget(const ATarget: TCrossTarget): Boolean;
    { RemoveCrossTarget - Remove a cross-target section }
    function RemoveCrossTarget(const ACPU, AOS: string): Boolean;
    { InsertOrUpdate - Insert if not present, update if exists }
    function InsertOrUpdate(const ATarget: TCrossTarget): Boolean;

    { GetLastError - Last error message }
    function GetLastError: string;
    { GetLineCount - Current line count }
    function GetLineCount: Integer;
  end;

implementation

constructor TFPCCfgManager.Create(const AFilePath: string);
begin
  inherited Create;
  FFilePath := AFilePath;
  FLines := TStringList.Create;
  FLastError := '';
end;

destructor TFPCCfgManager.Destroy;
begin
  FLines.Free;
  inherited Destroy;
end;

function TFPCCfgManager.GetSectionTag(const ACPU, AOS: string): string;
begin
  Result := LowerCase(ACPU) + '-' + LowerCase(AOS);
end;

function TFPCCfgManager.GetBeginTag(const ACPU, AOS: string): string;
begin
  Result := '# BEGIN fpdev-cross:' + GetSectionTag(ACPU, AOS);
end;

function TFPCCfgManager.GetEndTag(const ACPU, AOS: string): string;
begin
  Result := '# END fpdev-cross:' + GetSectionTag(ACPU, AOS);
end;

function TFPCCfgManager.FindSectionRange(const ACPU, AOS: string;
  out AStartLine, AEndLine: Integer): Boolean;
var
  BeginTag, EndTag: string;
  I: Integer;
begin
  Result := False;
  AStartLine := -1;
  AEndLine := -1;
  BeginTag := GetBeginTag(ACPU, AOS);
  EndTag := GetEndTag(ACPU, AOS);

  for I := 0 to FLines.Count - 1 do
  begin
    if Trim(FLines[I]) = BeginTag then
    begin
      AStartLine := I;
      Break;
    end;
  end;

  if AStartLine < 0 then Exit;

  for I := AStartLine + 1 to FLines.Count - 1 do
  begin
    if Trim(FLines[I]) = EndTag then
    begin
      AEndLine := I;
      Result := True;
      Exit;
    end;
  end;

  // Found begin but no end - corrupted section
  AStartLine := -1;
end;

function TFPCCfgManager.BuildSectionLines(const ATarget: TCrossTarget): TStringList;
var
  CPUDirective, OSDirective: string;
begin
  Result := TStringList.Create;
  try
    CPUDirective := 'CPU' + UpperCase(ATarget.CPU);
    OSDirective := UpperCase(ATarget.OS);

    Result.Add(GetBeginTag(ATarget.CPU, ATarget.OS));
    Result.Add('#IFDEF ' + CPUDirective);
    Result.Add('#IFDEF ' + OSDirective);

    // Binutils path
    if ATarget.BinutilsPath <> '' then
      Result.Add('-FD' + ATarget.BinutilsPath);

    // Binutils prefix
    if ATarget.BinutilsPrefix <> '' then
      Result.Add('-XP' + ATarget.BinutilsPrefix);

    // Library path
    if ATarget.LibrariesPath <> '' then
    begin
      Result.Add('-Fl' + ATarget.LibrariesPath);
      Result.Add('-Xd');
    end;

    // Cross-compile options (from CrossOpt or generated)
    if ATarget.CrossOpt <> '' then
      Result.Add(ATarget.CrossOpt)
    else
    begin
      // ARM specific
      if ATarget.CPU = 'arm' then
      begin
        if ATarget.ABI = 'eabihf' then
        begin
          Result.Add('-CaEABIHF');
          Result.Add('-CfVFPV3');
        end
        else
          Result.Add('-CaEABI');

        if ATarget.SubArch = 'armv7' then
          Result.Add('-CpARMV7A')
        else if ATarget.SubArch = 'armv6' then
          Result.Add('-CpARMV6');
      end;
    end;

    Result.Add('#ENDIF');
    Result.Add('#ENDIF');
    Result.Add(GetEndTag(ATarget.CPU, ATarget.OS));
  except
    Result.Free;
    raise;
  end;
end;

function TFPCCfgManager.LoadFromFile: Boolean;
begin
  FLastError := '';
  if not FileExists(FFilePath) then
  begin
    FLastError := 'File not found: ' + FFilePath;
    FLines.Clear;
    Result := False;
    Exit;
  end;
  try
    FLines.LoadFromFile(FFilePath);
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to load: ' + E.Message;
      Result := False;
    end;
  end;
end;

procedure TFPCCfgManager.LoadFromString(const AContent: string);
begin
  FLines.Text := AContent;
end;

function TFPCCfgManager.SaveToFile: Boolean;
begin
  FLastError := '';
  try
    FLines.SaveToFile(FFilePath);
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to save: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TFPCCfgManager.GetContent: string;
begin
  Result := FLines.Text;
end;

function TFPCCfgManager.HasCrossTarget(const ACPU, AOS: string): Boolean;
var
  S, E: Integer;
begin
  Result := FindSectionRange(ACPU, AOS, S, E);
end;

function TFPCCfgManager.InsertCrossTarget(const ATarget: TCrossTarget): Boolean;
var
  Section: TStringList;
  I: Integer;
begin
  FLastError := '';

  if ATarget.CPU = '' then
  begin
    FLastError := 'CPU not specified';
    Exit(False);
  end;
  if ATarget.OS = '' then
  begin
    FLastError := 'OS not specified';
    Exit(False);
  end;

  if HasCrossTarget(ATarget.CPU, ATarget.OS) then
  begin
    FLastError := 'Section already exists for ' + ATarget.CPU + '-' + ATarget.OS;
    Exit(False);
  end;

  Section := BuildSectionLines(ATarget);
  try
    // Add empty line separator if file is not empty
    if FLines.Count > 0 then
      FLines.Add('');
    for I := 0 to Section.Count - 1 do
      FLines.Add(Section[I]);
    Result := True;
  finally
    Section.Free;
  end;
end;

function TFPCCfgManager.UpdateCrossTarget(const ATarget: TCrossTarget): Boolean;
var
  StartLine, EndLine, I: Integer;
  Section: TStringList;
begin
  FLastError := '';

  if not FindSectionRange(ATarget.CPU, ATarget.OS, StartLine, EndLine) then
  begin
    FLastError := 'Section not found for ' + ATarget.CPU + '-' + ATarget.OS;
    Exit(False);
  end;

  // Remove old section (inclusive)
  for I := EndLine downto StartLine do
    FLines.Delete(I);

  // Insert new section at the same position
  Section := BuildSectionLines(ATarget);
  try
    for I := Section.Count - 1 downto 0 do
      FLines.Insert(StartLine, Section[I]);
    Result := True;
  finally
    Section.Free;
  end;
end;

function TFPCCfgManager.RemoveCrossTarget(const ACPU, AOS: string): Boolean;
var
  StartLine, EndLine, I: Integer;
begin
  FLastError := '';

  if not FindSectionRange(ACPU, AOS, StartLine, EndLine) then
  begin
    FLastError := 'Section not found for ' + ACPU + '-' + AOS;
    Exit(False);
  end;

  // Remove the section lines (inclusive)
  for I := EndLine downto StartLine do
    FLines.Delete(I);

  // Remove trailing empty line if present
  if (StartLine < FLines.Count) and (Trim(FLines[StartLine]) = '') then
    FLines.Delete(StartLine)
  // Remove preceding empty line if we removed from the end
  else if (StartLine > 0) and (StartLine = FLines.Count) and
    (Trim(FLines[StartLine - 1]) = '') then
    FLines.Delete(StartLine - 1);

  Result := True;
end;

function TFPCCfgManager.InsertOrUpdate(const ATarget: TCrossTarget): Boolean;
begin
  if HasCrossTarget(ATarget.CPU, ATarget.OS) then
    Result := UpdateCrossTarget(ATarget)
  else
    Result := InsertCrossTarget(ATarget);
end;

function TFPCCfgManager.GetLastError: string;
begin
  Result := FLastError;
end;

function TFPCCfgManager.GetLineCount: Integer;
begin
  Result := FLines.Count;
end;

end.
