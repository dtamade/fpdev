unit fpdev.cross.manifest;

{$mode objfpc}{$H+}

(*
  Cross-Compilation Manifest Parser

  Parses JSON manifest files that define available cross-compilation targets,
  including binutils and libraries download URLs for each host platform.

  See cross_manifest.json for the manifest structure.
*)

interface

uses
  SysUtils, Classes, fpjson, jsonparser;

type
  { TCrossBinutils - Binutils download info for a specific host platform }
  TCrossBinutils = record
    URLs: TStringArray;
    Sha256: string;
  end;

  { TCrossLibraries - Libraries download info }
  TCrossLibraries = record
    URLs: TStringArray;
    Sha256: string;
  end;

  { TCrossBinutilsEntry - Binutils info for a specific host platform }
  TCrossBinutilsEntry = record
    HostPlatform: string;
    Info: TCrossBinutils;
  end;

  { Array type for binutils entries }
  TCrossBinutilsArray = array of TCrossBinutilsEntry;

  { TCrossManifestTarget - A cross-compilation target definition }
  TCrossManifestTarget = record
    Name: string;
    DisplayName: string;
    CPU: string;
    OS: string;
    BinutilsPrefix: string;
    Binutils: TCrossBinutilsArray;
    Libraries: TCrossLibraries;
  end;

  { TCrossManifest - Cross-compilation manifest manager }
  TCrossManifest = class
  private
    FTargets: array of TCrossManifestTarget;
    FVersion: string;

    function ParseBinutils(ABinutilsObj: TJSONObject): TCrossBinutilsArray;
    function ParseLibraries(ALibsObj: TJSONObject): TCrossLibraries;
    function ParseURLs(AUrlsArray: TJSONArray): TStringArray;

  public
    constructor Create;
    destructor Destroy; override;

    { Load manifest from JSON string }
    function LoadFromJSON(const AJsonText: string): Boolean;

    { Load manifest from file }
    function LoadFromFile(const AFilePath: string): Boolean;

    { Get a target by name }
    function GetTarget(const AName: string; out ATarget: TCrossManifestTarget): Boolean;

    { Get list of all target names }
    function ListTargets: TStringArray;

    { Get binutils info for a specific host platform }
    function GetBinutilsForHost(const ATarget: TCrossManifestTarget;
      const AHostPlatform: string; out ABinutils: TCrossBinutils): Boolean;

    { Detect current host platform }
    function GetHostPlatform: string;

    { Number of targets in manifest }
    function TargetCount: Integer;

    { Manifest version }
    property Version: string read FVersion;
  end;

implementation

{ TCrossManifest }

constructor TCrossManifest.Create;
begin
  inherited Create;
  SetLength(FTargets, 0);
  FVersion := '';
end;

destructor TCrossManifest.Destroy;
var
  i, j: Integer;
begin
  // Clean up dynamic arrays in targets
  for i := 0 to High(FTargets) do
  begin
    SetLength(FTargets[i].Libraries.URLs, 0);
    for j := 0 to High(FTargets[i].Binutils) do
      SetLength(FTargets[i].Binutils[j].Info.URLs, 0);
    SetLength(FTargets[i].Binutils, 0);
  end;
  SetLength(FTargets, 0);
  inherited Destroy;
end;

function TCrossManifest.ParseURLs(AUrlsArray: TJSONArray): TStringArray;
var
  i: Integer;
begin
  Result := nil;
  if AUrlsArray = nil then
    Exit;

  SetLength(Result, AUrlsArray.Count);
  for i := 0 to AUrlsArray.Count - 1 do
    Result[i] := AUrlsArray.Strings[i];
end;

function TCrossManifest.ParseBinutils(ABinutilsObj: TJSONObject): TCrossBinutilsArray;
var
  i: Integer;
  HostPlatform: string;
  HostObj: TJSONObject;
  UrlsArr: TJSONArray;
begin
  Result := nil;
  if ABinutilsObj = nil then
    Exit;

  SetLength(Result, ABinutilsObj.Count);
  for i := 0 to ABinutilsObj.Count - 1 do
  begin
    HostPlatform := ABinutilsObj.Names[i];
    Result[i].HostPlatform := HostPlatform;

    if ABinutilsObj.Items[i].JSONType = jtObject then
    begin
      HostObj := TJSONObject(ABinutilsObj.Items[i]);
      Result[i].Info.Sha256 := HostObj.Get('sha256', '');

      if HostObj.Find('urls', UrlsArr) and (UrlsArr.JSONType = jtArray) then
        Result[i].Info.URLs := ParseURLs(UrlsArr)
      else
        SetLength(Result[i].Info.URLs, 0);
    end;
  end;
end;

function TCrossManifest.ParseLibraries(ALibsObj: TJSONObject): TCrossLibraries;
var
  UrlsArr: TJSONArray;
begin
  Result.Sha256 := '';
  SetLength(Result.URLs, 0);

  if ALibsObj = nil then
    Exit;

  Result.Sha256 := ALibsObj.Get('sha256', '');

  if ALibsObj.Find('urls', UrlsArr) and (UrlsArr.JSONType = jtArray) then
    Result.URLs := ParseURLs(UrlsArr);
end;

function TCrossManifest.LoadFromJSON(const AJsonText: string): Boolean;
var
  Data: TJSONData;
  RootObj: TJSONObject;
  TargetsArr: TJSONArray;
  TargetObj: TJSONObject;
  BinutilsObj, LibsObj: TJSONObject;
  i, N: Integer;
begin
  Result := False;

  // Clear existing targets
  SetLength(FTargets, 0);
  FVersion := '';

  if Trim(AJsonText) = '' then
    Exit;

  try
    Data := GetJSON(AJsonText);
  except
    Exit(False);
  end;

  try
    if Data.JSONType <> jtObject then
      Exit(False);

    RootObj := TJSONObject(Data);
    FVersion := RootObj.Get('version', '');

    // Parse targets array
    if RootObj.Find('targets', TargetsArr) and (TargetsArr.JSONType = jtArray) then
    begin
      N := TargetsArr.Count;
      SetLength(FTargets, N);

      for i := 0 to N - 1 do
      begin
        if TargetsArr.Items[i].JSONType <> jtObject then
          Continue;

        TargetObj := TJSONObject(TargetsArr.Items[i]);

        FTargets[i].Name := TargetObj.Get('name', '');
        FTargets[i].DisplayName := TargetObj.Get('displayName', '');
        FTargets[i].CPU := TargetObj.Get('cpu', '');
        FTargets[i].OS := TargetObj.Get('os', '');
        FTargets[i].BinutilsPrefix := TargetObj.Get('binutilsPrefix', '');

        // Parse binutils
        if TargetObj.Find('binutils', BinutilsObj) and (BinutilsObj.JSONType = jtObject) then
          FTargets[i].Binutils := ParseBinutils(BinutilsObj)
        else
          SetLength(FTargets[i].Binutils, 0);

        // Parse libraries
        if TargetObj.Find('libraries', LibsObj) and (LibsObj.JSONType = jtObject) then
          FTargets[i].Libraries := ParseLibraries(LibsObj)
        else
        begin
          FTargets[i].Libraries.Sha256 := '';
          SetLength(FTargets[i].Libraries.URLs, 0);
        end;
      end;

      Result := True;
    end
    else
    begin
      // Empty but valid JSON
      Result := True;
    end;

  finally
    Data.Free;
  end;
end;

function TCrossManifest.LoadFromFile(const AFilePath: string): Boolean;
var
  FileContent: TStringList;
begin
  Result := False;

  if not FileExists(AFilePath) then
    Exit;

  FileContent := TStringList.Create;
  try
    FileContent.LoadFromFile(AFilePath);
    Result := LoadFromJSON(FileContent.Text);
  finally
    FileContent.Free;
  end;
end;

function TCrossManifest.GetTarget(const AName: string; out ATarget: TCrossManifestTarget): Boolean;
var
  i: Integer;
begin
  Result := False;

  for i := 0 to High(FTargets) do
  begin
    if SameText(FTargets[i].Name, AName) then
    begin
      ATarget := FTargets[i];
      Result := True;
      Exit;
    end;
  end;
end;

function TCrossManifest.ListTargets: TStringArray;
var
  i: Integer;
begin
  Result := nil;
  SetLength(Result, Length(FTargets));
  for i := 0 to High(FTargets) do
    Result[i] := FTargets[i].Name;
end;

function TCrossManifest.GetBinutilsForHost(const ATarget: TCrossManifestTarget;
  const AHostPlatform: string; out ABinutils: TCrossBinutils): Boolean;
var
  i: Integer;
begin
  Result := False;
  ABinutils.Sha256 := '';
  SetLength(ABinutils.URLs, 0);

  for i := 0 to High(ATarget.Binutils) do
  begin
    if SameText(ATarget.Binutils[i].HostPlatform, AHostPlatform) then
    begin
      ABinutils := ATarget.Binutils[i].Info;
      Result := True;
      Exit;
    end;
  end;
end;

function TCrossManifest.GetHostPlatform: string;
begin
  {$IFDEF MSWINDOWS}
    {$IFDEF CPUX86_64}
    Result := 'win64';
    {$ELSE}
      {$IFDEF CPUI386}
      Result := 'win32';
      {$ELSE}
      Result := 'win64'; // Default to 64-bit
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}

  {$IFDEF LINUX}
    {$IFDEF CPUX86_64}
    Result := 'linux64';
    {$ELSE}
      {$IFDEF CPUI386}
      Result := 'linux32';
      {$ELSE}
        {$IFDEF CPUAARCH64}
        Result := 'linuxarm64';
        {$ELSE}
          {$IFDEF CPUARM}
          Result := 'linuxarm';
          {$ELSE}
          Result := 'linux64'; // Default to 64-bit
          {$ENDIF}
        {$ENDIF}
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}

  {$IFDEF DARWIN}
    {$IFDEF CPUAARCH64}
    Result := 'darwinarm64';
    {$ELSE}
      {$IFDEF CPUX86_64}
      Result := 'darwin64';
      {$ELSE}
      Result := 'darwin64'; // Default to 64-bit
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}

  {$IFDEF FREEBSD}
    {$IFDEF CPUX86_64}
    Result := 'freebsd64';
    {$ELSE}
    Result := 'freebsd32';
    {$ENDIF}
  {$ENDIF}
end;

function TCrossManifest.TargetCount: Integer;
begin
  Result := Length(FTargets);
end;

end.
