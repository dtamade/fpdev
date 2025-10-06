program example_manifest_fetch;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.toolchain.manifest, fpdev.toolchain.fetcher;

const
  SAMPLE_JSON = '{"components":[{"name":"make","version":"4.4","os":"windows","arch":"x86_64","urls":["https://example.com/mingw32-make.zip","https://mirror.example.com/mingw32-make.zip"],"sha256":""}]}' ;

var
  M: TManifest;
  C: TManifestComponent;
  Ok: Boolean;
  Err: string;
  Opt: TFetchOptions;
  Dest: string;
begin
  if not ParseManifestJSON(SAMPLE_JSON, M) then
  begin
    WriteLn('Manifest parse failed');
    Halt(2);
  end;
  if not FindComponent(M, 'make', '4.4', 'windows', 'x86_64', C) then
  begin
    WriteLn('Component not found');
    Halt(2);
  end;
  Dest := 'plays'+PathDelim+'.cache'+PathDelim+'toolchain'+PathDelim+'mingw32-make.zip';
  Opt.DestDir := ExtractFileDir(Dest);
  Opt.SHA256 := C.Sha256;
  Opt.TimeoutMS := 20000;

  Ok := FetchWithMirrors(C.URLs, Dest, Opt, Err);
  if Ok then WriteLn('Downloaded to: ', Dest) else WriteLn('Download failed: ', Err);
end.

