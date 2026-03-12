unit fpdev.toolchain.commandflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf;

function RunToolchainFetchCommand(
  const AParams: array of string;
  const AOut, AErr: IOutput
): Integer;
function RunToolchainExtractCommand(
  const AParams: array of string;
  const AOut, AErr: IOutput
): Integer;
function RunToolchainEnsureSourceCommand(
  const AParams: array of string;
  const AOut, AErr: IOutput
): Integer;
function RunToolchainImportBundleCommand(
  const AParams: array of string;
  const AOut, AErr: IOutput
): Integer;

implementation

uses
  Classes,
  fpdev.exitcodes,
  fpdev.paths,
  fpdev.source,
  fpdev.toolchain.extract,
  fpdev.toolchain.fetcher,
  fpdev.toolchain.manifest;

function HasHelpOnly(const AParams: array of string): Boolean;
begin
  Result :=
    (Length(AParams) = 1) and
    ((AParams[0] = '--help') or (AParams[0] = '-h'));
end;

function RunToolchainFetchCommand(
  const AParams: array of string;
  const AOut, AErr: IOutput
): Integer;
var
  Name, Ver, OS, Arch: string;
  ManifestPath, Dest: string;
  Manifest: TManifest;
  Component: TManifestComponent;
  Ok: Boolean;
  Err: string;
  JsonText: TStringList;
  Opt: TFetchOptions;
  Index: Integer;
const
  USAGE_TEXT =
    'Usage: fpdev system toolchain fetch <name> <version> <os> <arch> [--manifest <path>] [--dest <zip>]';
begin
  Result := EXIT_OK;

  if HasHelpOnly(AParams) then
  begin
    if AOut <> nil then
      AOut.WriteLn(USAGE_TEXT);
    Exit;
  end;

  if Length(AParams) < 4 then
  begin
    if AErr <> nil then
      AErr.WriteLn(USAGE_TEXT);
    Exit(EXIT_USAGE_ERROR);
  end;

  Name := AParams[0];
  Ver := AParams[1];
  OS := AParams[2];
  Arch := AParams[3];
  ManifestPath := '';
  Dest := '';
  Index := 4;
  while Index <= High(AParams) do
  begin
    if (AParams[Index] = '--manifest') and (Index + 1 <= High(AParams)) then
      ManifestPath := AParams[Index + 1];
    if (AParams[Index] = '--dest') and (Index + 1 <= High(AParams)) then
      Dest := AParams[Index + 1];
    Inc(Index);
  end;

  JsonText := TStringList.Create;
  try
    if ManifestPath = '' then
    begin
      if AErr <> nil then
        AErr.WriteLn('--manifest not specified');
      Exit(EXIT_USAGE_ERROR);
    end;

    if not FileExists(ManifestPath) then
    begin
      if AErr <> nil then
        AErr.WriteLn('Manifest not found: ' + ManifestPath);
      Exit(EXIT_USAGE_ERROR);
    end;

    JsonText.LoadFromFile(ManifestPath);
    if not ParseManifestJSON(JsonText.Text, Manifest) then
    begin
      if AErr <> nil then
        AErr.WriteLn('Manifest parse failed');
      Exit(EXIT_USAGE_ERROR);
    end;

    if not FindComponent(Manifest, Name, Ver, OS, Arch, Component) then
    begin
      if AErr <> nil then
        AErr.WriteLn('Component not found');
      Exit(EXIT_USAGE_ERROR);
    end;

    if Dest = '' then
      Dest := IncludeTrailingPathDelimiter(GetCacheDir) + 'toolchain' + PathDelim + Name + '-' + Ver + '.zip';

    Opt.DestDir := ExtractFileDir(Dest);
    Opt.Hash := Component.Sha256;
    Opt.HashAlgorithm := haSHA256;
    Opt.HashDigest := Component.Sha256;
    Opt.TimeoutMS := DEFAULT_DOWNLOAD_TIMEOUT_MS;
    Opt.ExpectedSize := 0;
    Ok := FetchWithMirrors(Component.URLs, Dest, Opt, Err);
    if Ok then
    begin
      if AOut <> nil then
        AOut.WriteLn('Download successful: ' + Dest);
      Exit(EXIT_OK);
    end;

    if AErr <> nil then
      AErr.WriteLn('Download failed: ' + Err);
    Result := EXIT_USAGE_ERROR;
  finally
    JsonText.Free;
  end;
end;

function RunToolchainExtractCommand(
  const AParams: array of string;
  const AOut, AErr: IOutput
): Integer;
var
  DestPath: string;
  ExtractError: string;
  ZipPath: string;
const
  USAGE_TEXT = 'Usage: fpdev system toolchain extract <zip> <dest>';
begin
  Result := EXIT_OK;

  if HasHelpOnly(AParams) then
  begin
    if AOut <> nil then
      AOut.WriteLn(USAGE_TEXT);
    Exit;
  end;

  if Length(AParams) < 2 then
  begin
    if AErr <> nil then
      AErr.WriteLn(USAGE_TEXT);
    Exit(EXIT_USAGE_ERROR);
  end;

  ZipPath := AParams[0];
  DestPath := AParams[1];
  if ZipExtract(ZipPath, DestPath, ExtractError) then
  begin
    if AOut <> nil then
      AOut.WriteLn('Extract successful: ' + DestPath);
    Exit(EXIT_OK);
  end;

  if AErr <> nil then
    AErr.WriteLn('Extract failed: ' + ExtractError);
  Result := EXIT_USAGE_ERROR;
end;

function RunToolchainEnsureSourceCommand(
  const AParams: array of string;
  const AOut, AErr: IOutput
): Integer;
var
  Name, Ver: string;
  Ok: Boolean;
  Err: string;
  LocalPath, Sha: string;
  Strict: Boolean;
  DestPath: string;
  Index: Integer;
const
  USAGE_TEXT =
    'Usage: fpdev system toolchain ensure-source <name> <version> --local <dir|zip> [--sha256 <hex>] [--strict]';
begin
  Result := EXIT_OK;

  if HasHelpOnly(AParams) then
  begin
    if AOut <> nil then
      AOut.WriteLn(USAGE_TEXT);
    Exit;
  end;

  if Length(AParams) < 3 then
  begin
    if AErr <> nil then
      AErr.WriteLn(USAGE_TEXT);
    Exit(EXIT_USAGE_ERROR);
  end;

  Name := AParams[0];
  Ver := AParams[1];
  LocalPath := '';
  Sha := '';
  Strict := False;
  Index := 2;
  while Index <= High(AParams) do
  begin
    if AParams[Index] = '--local' then
    begin
      Inc(Index);
      if Index <= High(AParams) then
        LocalPath := AParams[Index];
    end
    else if AParams[Index] = '--sha256' then
    begin
      Inc(Index);
      if Index <= High(AParams) then
        Sha := AParams[Index];
    end
    else if AParams[Index] = '--strict' then
      Strict := True;
    Inc(Index);
  end;

  if (LocalPath <> '') and DirectoryExists(LocalPath) then
    Ok := EnsureSourceLocalDir(Name, Ver, LocalPath, Strict, DestPath, Err)
  else if (LocalPath <> '') and FileExists(LocalPath) then
    Ok := EnsureSourceLocalZip(Name, Ver, LocalPath, Sha, DestPath, Err)
  else
  begin
    if AErr <> nil then
      AErr.WriteLn(USAGE_TEXT);
    Exit(EXIT_USAGE_ERROR);
  end;

  if Ok then
  begin
    if AOut <> nil then
      AOut.WriteLn('Source ready at: ' + DestPath);
    Exit(EXIT_OK);
  end;

  if AErr <> nil then
    AErr.WriteLn('Ensure source failed: ' + Err);
  Result := EXIT_USAGE_ERROR;
end;

function RunToolchainImportBundleCommand(
  const AParams: array of string;
  const AOut, AErr: IOutput
): Integer;
var
  Err: string;
const
  USAGE_TEXT = 'Usage: fpdev system toolchain import-bundle <dir|zip>';
begin
  Result := EXIT_OK;

  if HasHelpOnly(AParams) then
  begin
    if AOut <> nil then
      AOut.WriteLn(USAGE_TEXT);
    Exit;
  end;

  if Length(AParams) < 1 then
  begin
    if AErr <> nil then
      AErr.WriteLn(USAGE_TEXT);
    Exit(EXIT_USAGE_ERROR);
  end;

  if ImportBundle(AParams[0], Err) then
  begin
    if AOut <> nil then
      AOut.WriteLn('Bundle imported.');
    Exit(EXIT_OK);
  end;

  if AErr <> nil then
    AErr.WriteLn('Import bundle failed: ' + Err);
  Result := EXIT_USAGE_ERROR;
end;

end.
