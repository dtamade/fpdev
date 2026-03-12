unit fpdev.toolchain.manifest;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser;

type
  TStringDynArray = array of string;

  TManifestComponent = record
    Name: string;
    Version: string;
    OS: string;
    Arch: string;
    URLs: TStringDynArray; // Candidate download URLs (including mirrors)
    Sha256: string;        // Optional: integrity verification
  end;

  TManifest = record
    Components: array of TManifestComponent;
  end;

// Parse JSON text to manifest; returns True on success
function ParseManifestJSON(const AText: string; out AM: TManifest): boolean;
// Find component by name/version/os/arch; returns True on success
function FindComponent(
  const AM: TManifest;
  const AName, AVersion, AOS, AArch: string;
  out AC: TManifestComponent
): boolean;

implementation

function ParseManifestJSON(const AText: string; out AM: TManifest): boolean;
var
  Data: TJSONData;
  Obj: TJSONObject;
  Arr: TJSONArray;
  i, j, N: Integer;
  C: TManifestComponent;
  It: TJSONObject;
  Urls: TJSONArray;
begin
  Result := False;
  Initialize(AM);
  SetLength(AM.Components, 0);
  Initialize(C);
  try
    Data := GetJSON(AText);
  except
    Exit(False);
  end;
  try
    if (Data.JSONType <> jtObject) then Exit(False);
    Obj := TJSONObject(Data);
    if Obj.Find('components', Arr) then
    begin
      N := Arr.Count;
      SetLength(AM.Components, N);
      for i := 0 to N-1 do
      begin
        It := Arr.Objects[i];
        Finalize(C);
        Initialize(C);
        C.Name := It.Get('name','');
        C.Version := It.Get('version','');
        C.OS := LowerCase(It.Get('os',''));
        C.Arch := LowerCase(It.Get('arch',''));
        C.Sha256 := LowerCase(It.Get('sha256',''));
        // urls
        SetLength(C.URLs, 0);
        if It.Find('urls', Urls) and (Urls.JSONType=jtArray) then
        begin
          SetLength(C.URLs, Urls.Count);
          for j := 0 to Urls.Count-1 do
            C.URLs[j] := Urls.Strings[j];
        end;
        AM.Components[i] := C;
      end;
      Result := True;
    end;
  finally
    Finalize(C);
    Data.Free;
  end;
end;

function FindComponent(
  const AM: TManifest;
  const AName, AVersion, AOS, AArch: string;
  out AC: TManifestComponent
): boolean;
var
  i: Integer;
  C: TManifestComponent;
  OSNorm, ArchNorm: string;
begin
  Result := False;
  OSNorm := LowerCase(AOS);
  ArchNorm := LowerCase(AArch);
  for i := 0 to High(AM.Components) do
  begin
    C := AM.Components[i];
    if (SameText(C.Name, AName)) and (C.Version = AVersion) and
       ((C.OS='') or (C.OS = OSNorm)) and ((C.Arch='') or (C.Arch = ArchNorm)) then
    begin
      AC := C;
      Exit(True);
    end;
  end;
end;

end.
