unit fpdev.toolchain.manifest;
{$CODEPAGE UTF8}
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
    URLs: TStringDynArray; // 候选下载地址（含镜像）
    Sha256: string;        // 可选：完整性校验
  end;

  TManifest = record
    Components: array of TManifestComponent;
  end;

// 解析 JSON 文本为清单；成功返回 True
function ParseManifestJSON(const AText: string; out AM: TManifest): boolean;
// 根据 name/version/os/arch 查找组件；成功返回 True
function FindComponent(const AM: TManifest; const AName, AVersion, AOS, AArch: string; out AC: TManifestComponent): boolean;

implementation

function ParseManifestJSON(const AText: string; out AM: TManifest): boolean;
var
  Data: TJSONData;
  Obj, Comps: TJSONObject;
  Arr: TJSONArray;
  i, j, N: Integer;
  C: TManifestComponent;
  It: TJSONObject;
  Urls: TJSONArray;
begin
  Result := False;
  SetLength(AM.Components, 0);
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
        FillChar(C, SizeOf(C), 0);
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
    Data.Free;
  end;
end;

function FindComponent(const AM: TManifest; const AName, AVersion, AOS, AArch: string; out AC: TManifestComponent): boolean;
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

