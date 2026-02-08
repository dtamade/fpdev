unit fpdev.build.cache.verify;

{$mode objfpc}{$H+}

{
  B071: SHA256 verification helpers for TBuildCache

  Extracts file integrity verification logic from build.cache.
  Pure functions that work with file paths.
}

interface

uses
  SysUtils, Classes, Process;

{ Calculate SHA256 hash of a file using sha256sum command }
function BuildCacheCalculateSHA256(const AFilePath: string): string;

{ Verify file integrity by comparing SHA256 hash }
function BuildCacheVerifyFileHash(const AFilePath, AExpectedHash: string): Boolean;

implementation

function BuildCacheCalculateSHA256(const AFilePath: string): string;
var
  P: TProcess;
  Output: TStringList;
  Line: string;
  SpacePos: Integer;
begin
  Result := '';

  if not FileExists(AFilePath) then
    Exit;

  // Use sha256sum command (available on Linux/macOS/Windows Git Bash)
  P := TProcess.Create(nil);
  try
    {$IFDEF MSWINDOWS}
    // On Windows, try certutil as fallback if sha256sum not available
    P.Executable := 'sha256sum';
    {$ELSE}
    P.Executable := 'sha256sum';
    {$ENDIF}
    P.Parameters.Add(AFilePath);
    P.Options := [poWaitOnExit, poUsePipes];

    try
      P.Execute;

      if P.ExitStatus = 0 then
      begin
        Output := TStringList.Create;
        try
          Output.LoadFromStream(P.Output);
          if Output.Count > 0 then
          begin
            Line := Output[0];
            // sha256sum output format: "hash  filename"
            SpacePos := Pos(' ', Line);
            if SpacePos > 0 then
              Result := LowerCase(Trim(Copy(Line, 1, SpacePos - 1)))
            else
              Result := LowerCase(Trim(Line));
          end;
        finally
          Output.Free;
        end;
      end;
    except
      on E: Exception do
      begin
        // Silent failure - SHA256 calculation error
        Result := '';
      end;
    end;
  finally
    P.Free;
  end;
end;

function BuildCacheVerifyFileHash(const AFilePath, AExpectedHash: string): Boolean;
var
  ActualHash: string;
begin
  // If no expected hash provided, skip verification
  if AExpectedHash = '' then
    Exit(True);

  // Calculate actual hash
  ActualHash := BuildCacheCalculateSHA256(AFilePath);

  // Compare hashes (case-insensitive)
  Result := SameText(ActualHash, AExpectedHash);
end;

end.
