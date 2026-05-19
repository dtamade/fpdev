unit fpdev.cross.verifyflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process, fpjson, jsonparser,
  fpdev.cross.downloader.downloadflow;

function VerifyCrossBinutilsInstallationCore(
  const AInstallDir, ATarget, AVersion, ASHA256: string
): TCrossVerificationResult;
function ExecuteCrossVersionCheckCore(const ABinaryPath: string): string;
procedure UpdateCrossVerificationMetadataCore(
  const AInstallDir, ATarget, AVersion, ASHA256: string;
  AVerified: Boolean
);
function LoadCrossMetadataJSONCore(const APath: string): TJSONObject;

implementation

function ResolveCrossToolPrefixCore(const ATarget: string): string;
begin
  case LowerCase(ATarget) of
    'win64': Result := 'x86_64-w64-mingw32-';
    'win32': Result := 'i686-w64-mingw32-';
    'linux64': Result := 'x86_64-linux-gnu-';
    'linux32': Result := 'i686-linux-gnu-';
  else
    Result := ATarget + '-';
  end;
end;

function VerifyCrossBinutilsInstallationCore(
  const AInstallDir, ATarget, AVersion, ASHA256: string
): TCrossVerificationResult;
var
  BinDir, Prefix: string;
  RequiredBins: array[0..2] of string;
  i: Integer;
  BinPath, LdPath: string;
  VersionOutput: string;
begin
  Result.Success := False;
  Result.MissingBinaries := TStringList.Create;
  Result.VersionInfo := '';
  Result.ErrorMessage := '';

  BinDir := IncludeTrailingPathDelimiter(AInstallDir) + 'bin' + PathDelim;
  Prefix := ResolveCrossToolPrefixCore(ATarget);

  RequiredBins[0] := 'ld';
  RequiredBins[1] := 'as';
  RequiredBins[2] := 'ar';

  for i := 0 to High(RequiredBins) do
  begin
    BinPath := BinDir + Prefix + RequiredBins[i];
    {$IFDEF WINDOWS}
    BinPath := BinPath + '.exe';
    {$ENDIF}

    if not FileExists(BinPath) then
      Result.MissingBinaries.Add(Prefix + RequiredBins[i]);
  end;

  if Result.MissingBinaries.Count > 0 then
  begin
    Result.ErrorMessage := 'Missing binaries: ' + Result.MissingBinaries.CommaText;
    Exit;
  end;

  LdPath := BinDir + Prefix + 'ld';
  {$IFDEF WINDOWS}
  LdPath := LdPath + '.exe';
  {$ENDIF}

  VersionOutput := ExecuteCrossVersionCheckCore(LdPath);
  if VersionOutput <> '' then
    Result.VersionInfo := VersionOutput;

  UpdateCrossVerificationMetadataCore(AInstallDir, ATarget, AVersion, ASHA256, True);
  Result.Success := True;
end;

function ExecuteCrossVersionCheckCore(const ABinaryPath: string): string;
var
  Proc: TProcess;
  Output: TStringList;
begin
  Result := '';
  if not FileExists(ABinaryPath) then
    Exit;

  Proc := TProcess.Create(nil);
  Output := TStringList.Create;
  try
    Proc.Executable := ABinaryPath;
    Proc.Parameters.Add('--version');
    Proc.Options := [poUsePipes, poWaitOnExit, poNoConsole];
    try
      Proc.Execute;
      Output.LoadFromStream(Proc.Output);
      if Output.Count > 0 then
        Result := Output[0];
    except
      // Version probe is optional during verification.
    end;
  finally
    Output.Free;
    Proc.Free;
  end;
end;

procedure UpdateCrossVerificationMetadataCore(
  const AInstallDir, ATarget, AVersion, ASHA256: string;
  AVerified: Boolean
);
var
  MetaPath: string;
  MetaJSON: TJSONObject;
  BinutilsObj: TJSONObject;
  F: TFileStream;
  JSONStr: string;
begin
  MetaPath := IncludeTrailingPathDelimiter(AInstallDir) + '.fpdev-cross-meta.json';

  MetaJSON := TJSONObject.Create;
  try
    if FileExists(MetaPath) then
    begin
      try
        MetaJSON.Free;
        MetaJSON := LoadCrossMetadataJSONCore(MetaPath);
      except
        MetaJSON := TJSONObject.Create;
      end;
    end;

    MetaJSON.Strings['target'] := ATarget;
    if MetaJSON.IndexOfName('installedAt') < 0 then
      MetaJSON.Strings['installedAt'] := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now);

    if MetaJSON.IndexOfName('binutils') >= 0 then
      BinutilsObj := MetaJSON.Objects['binutils']
    else
    begin
      BinutilsObj := TJSONObject.Create;
      MetaJSON.Objects['binutils'] := BinutilsObj;
    end;

    BinutilsObj.Strings['version'] := AVersion;
    BinutilsObj.Strings['sha256'] := ASHA256;
    BinutilsObj.Booleans['verified'] := AVerified;
    BinutilsObj.Strings['verifiedAt'] := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now);

    ForceDirectories(ExtractFileDir(MetaPath));
    JSONStr := MetaJSON.FormatJSON;
    F := TFileStream.Create(MetaPath, fmCreate);
    try
      F.Write(JSONStr[1], Length(JSONStr));
    finally
      F.Free;
    end;
  finally
    MetaJSON.Free;
  end;
end;

function LoadCrossMetadataJSONCore(const APath: string): TJSONObject;
var
  F: TFileStream;
  Parser: TJSONParser;
  Data: TJSONData;
begin
  Result := nil;
  F := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Parser := TJSONParser.Create(F, []);
    try
      Data := Parser.Parse;
      if Data is TJSONObject then
        Result := TJSONObject(Data)
      else
      begin
        Data.Free;
        Result := TJSONObject.Create;
      end;
    finally
      Parser.Free;
    end;
  finally
    F.Free;
  end;
end;

end.
