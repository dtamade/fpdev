unit fpdev.package.metadataio;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson,
  fpdev.package.types,
  fpdev.utils.fs;

type
  TPackageMetadataLoadStatus = (
    pmlsOk,
    pmlsMissing,
    pmlsIOError,
    pmlsInvalidJSON,
    pmlsInvalidShape,
    pmlsSourcePathMissing
  );

function WritePackageMetadataCore(const AInstallPath: string;
  const Info: TPackageInfo; const ABuildTool, ABuildLog: string): Boolean;
function TryLoadPackageMetadataCore(const AMetaPath: string;
  out AMetadata: TJSONObject;
  out AStatus: TPackageMetadataLoadStatus;
  out AError: string): Boolean;
function ApplyPackageMetadataToInfoCore(const AMetaPath: string;
  var AInfo: TPackageInfo): Boolean;
function ResolvePackageNameFromMetadataCore(const AMetaPath,
  ADefaultName: string): string;
function ResolveMetadataSourcePathCore(const AInstallPath,
  ASourcePath: string): string;
function TryResolvePublishMetadataCore(const AInstallPath,
  ADefaultVersion: string;
  out AVersion, AArchiveSourcePath, ASourcePathFromMeta: string;
  out AStatus: TPackageMetadataLoadStatus;
  out AError: string): Boolean;

implementation

uses
  jsonparser;

function WritePackageMetadataCore(const AInstallPath: string;
  const Info: TPackageInfo; const ABuildTool, ABuildLog: string): Boolean;
var
  MetaPath: string;
  O: TJSONObject;
  SL: TStringList;
  i: Integer;
begin
  Result := False;
  try
    MetaPath := IncludeTrailingPathDelimiter(AInstallPath) + 'package.json';
    O := TJSONObject.Create;
    try
      O.Add('name', Info.Name);
      O.Add('version', Info.Version);
      O.Add('description', Info.Description);
      O.Add('author', Info.Author);
      O.Add('homepage', Info.Homepage);
      O.Add('license', Info.License);
      O.Add('repository', Info.Repository);
      O.Add('install_path', AInstallPath);
      O.Add('install_date', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now));
      O.Add('source_path', Info.SourcePath);
      if ABuildTool <> '' then
        O.Add('build_tool', ABuildTool);
      if ABuildLog <> '' then
        O.Add('build_log', ABuildLog);
      if Length(Info.URLs) > 0 then
      begin
        O.Add('url', TJSONArray.Create);
        for i := 0 to High(Info.URLs) do
          TJSONArray(O.Arrays['url']).Add(Info.URLs[i]);
      end;
      if Info.Sha256 <> '' then
        O.Add('sha256', Info.Sha256);

      SL := TStringList.Create;
      try
        SL.Text := O.FormatJSON;
        EnsureDir(AInstallPath);
        SL.SaveToFile(MetaPath);
        Result := True;
      finally
        SL.Free;
      end;
    finally
      O.Free;
    end;
  except
    on E: Exception do
      Result := False;
  end;
end;

function TryLoadPackageMetadataCore(const AMetaPath: string;
  out AMetadata: TJSONObject;
  out AStatus: TPackageMetadataLoadStatus;
  out AError: string): Boolean;
var
  SL: TStringList;
  J: TJSONData;
begin
  Result := False;
  AMetadata := nil;
  AError := '';
  AStatus := pmlsMissing;

  if not FileExists(AMetaPath) then
    Exit;

  SL := TStringList.Create;
  try
    try
      SL.LoadFromFile(AMetaPath);
    except
      on E: Exception do
      begin
        AStatus := pmlsIOError;
        AError := E.Message;
        Exit;
      end;
    end;

    try
      J := GetJSON(SL.Text);
    except
      on E: Exception do
      begin
        AStatus := pmlsInvalidJSON;
        AError := E.Message;
        Exit;
      end;
    end;
  finally
    SL.Free;
  end;

  if J.JSONType <> jtObject then
  begin
    J.Free;
    AStatus := pmlsInvalidShape;
    Exit;
  end;

  AMetadata := TJSONObject(J);
  AStatus := pmlsOk;
  Result := True;
end;

function ApplyPackageMetadataToInfoCore(const AMetaPath: string;
  var AInfo: TPackageInfo): Boolean;
var
  Metadata: TJSONObject;
  Status: TPackageMetadataLoadStatus;
  ErrorText: string;

  procedure ApplyIfPresent(const AKey: string; var ATarget: string);
  var
    Value: string;
  begin
    Value := Trim(Metadata.Get(AKey, ''));
    if Value <> '' then
      ATarget := Value;
  end;
begin
  Result := False;
  if not TryLoadPackageMetadataCore(AMetaPath, Metadata, Status, ErrorText) then
    Exit;

  try
    ApplyIfPresent('name', AInfo.Name);
    ApplyIfPresent('version', AInfo.Version);
    ApplyIfPresent('description', AInfo.Description);
    ApplyIfPresent('author', AInfo.Author);
    ApplyIfPresent('license', AInfo.License);
    ApplyIfPresent('homepage', AInfo.Homepage);
    ApplyIfPresent('repository', AInfo.Repository);
    Result := True;
  finally
    Metadata.Free;
  end;
end;

function ResolvePackageNameFromMetadataCore(const AMetaPath,
  ADefaultName: string): string;
var
  Metadata: TJSONObject;
  Status: TPackageMetadataLoadStatus;
  ErrorText: string;
  NameFromMeta: string;
begin
  Result := ADefaultName;
  if not TryLoadPackageMetadataCore(AMetaPath, Metadata, Status, ErrorText) then
    Exit;

  try
    NameFromMeta := Trim(Metadata.Get('name', ''));
    if NameFromMeta <> '' then
      Result := NameFromMeta;
  finally
    Metadata.Free;
  end;
end;

function ResolveMetadataSourcePathCore(const AInstallPath,
  ASourcePath: string): string;
begin
  Result := Trim(ASourcePath);
  if Result = '' then
    Exit;

  if (ExtractFileDrive(Result) = '') and
     ((Length(Result) = 0) or (Result[1] <> PathDelim)) then
    Result := IncludeTrailingPathDelimiter(AInstallPath) + Result;

  Result := ExpandFileName(Result);
end;

function TryResolvePublishMetadataCore(const AInstallPath,
  ADefaultVersion: string;
  out AVersion, AArchiveSourcePath, ASourcePathFromMeta: string;
  out AStatus: TPackageMetadataLoadStatus;
  out AError: string): Boolean;
var
  MetaPath: string;
  Metadata: TJSONObject;
begin
  Result := False;
  AVersion := ADefaultVersion;
  AArchiveSourcePath := AInstallPath;
  ASourcePathFromMeta := '';
  AError := '';
  AStatus := pmlsMissing;

  MetaPath := IncludeTrailingPathDelimiter(AInstallPath) + 'package.json';
  if not TryLoadPackageMetadataCore(MetaPath, Metadata, AStatus, AError) then
    Exit;

  try
    AVersion := Trim(Metadata.Get('version', ADefaultVersion));
    if AVersion = '' then
      AVersion := ADefaultVersion;

    ASourcePathFromMeta := Trim(Metadata.Get('source_path', ''));
    if ASourcePathFromMeta <> '' then
    begin
      AArchiveSourcePath := ResolveMetadataSourcePathCore(
        AInstallPath,
        ASourcePathFromMeta
      );
      if not DirectoryExists(AArchiveSourcePath) then
      begin
        AStatus := pmlsSourcePathMissing;
        AError := ASourcePathFromMeta;
        Exit;
      end;
    end;

    AStatus := pmlsOk;
    Result := True;
  finally
    Metadata.Free;
  end;
end;

end.
