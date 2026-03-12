unit fpdev.build.cache.artifactmeta;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

procedure BuildCacheSaveArtifactMeta(const AMetaPath, AVersion, ACPU, AOS,
  AArchivePath: string; ACreatedAt: TDateTime);

implementation

uses
  Classes;

procedure BuildCacheSaveArtifactMeta(const AMetaPath, AVersion, ACPU, AOS,
  AArchivePath: string; ACreatedAt: TDateTime);
var
  MetaFile: TStringList;
begin
  MetaFile := TStringList.Create;
  try
    MetaFile.Add('version=' + AVersion);
    MetaFile.Add('cpu=' + ACPU);
    MetaFile.Add('os=' + AOS);
    MetaFile.Add('archive_path=' + AArchivePath);
    MetaFile.Add('created_at=' + FormatDateTime('yyyy-mm-dd hh:nn:ss', ACreatedAt));
    MetaFile.SaveToFile(AMetaPath);
  finally
    MetaFile.Free;
  end;
end;

end.
