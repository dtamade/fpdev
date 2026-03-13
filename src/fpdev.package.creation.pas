unit fpdev.package.creation;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.utils.fs, fpdev.package.archiver;

type
  TPackageCreateOptions = record
    Name: string;
    Version: string;
    SourcePath: string;
    ExcludePatterns: TStringArray;
  end;

function IsBuildArtifactCore(const FileName: string): Boolean;
function CollectPackageSourceFilesCore(const SourceDir: string;
  const ExcludePatterns: TStringArray): TStringArray;
function GeneratePackageMetadataJsonCore(
  const Options: TPackageCreateOptions): string;
function EnsurePackageMetadataFileCore(const APackageName, ASourceDir, AMetaPath: string;
  out ACreated: Boolean; out AError: string): Boolean;
function CreatePackageZipArchiveCore(const SourceDir: string;
  const Files: TStringArray; const OutputPath: string; var Err: string): Boolean;

implementation

const
  DEFAULT_PACKAGE_VERSION = '1.0.0';

function IsBuildArtifactCore(const FileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  Result := (Ext = '.o') or (Ext = '.ppu') or (Ext = '.a') or
            (Ext = '.exe') or (Ext = '.dll') or (Ext = '.so') or
            (Ext = '.dylib') or (Ext = '.compiled') or (Ext = '.res') or
            (Ext = '.or') or (Ext = '.dcu') or (Ext = '.bpl') or (Ext = '.dcp');
end;

function CollectPackageSourceFilesCore(const SourceDir: string;
  const ExcludePatterns: TStringArray): TStringArray;
var
  Files: TStringList;
  i: Integer;
  Excluded: Boolean;
  j: Integer;
  RelPath: string;

  procedure ScanDirectory(const Dir: string);
  var
    SearchRec: TSearchRec;
    FullPath: string;
    Ext: string;
  begin
    if FindFirst(Dir + PathDelim + '*', faAnyFile, SearchRec) = 0 then
    begin
      repeat
        if (SearchRec.Name = '.') or (SearchRec.Name = '..') then
          Continue;

        FullPath := Dir + PathDelim + SearchRec.Name;

        if (SearchRec.Attr and faDirectory) <> 0 then
        begin
          ScanDirectory(FullPath);
        end
        else
        begin
          Ext := LowerCase(ExtractFileExt(SearchRec.Name));
          if (Ext = '.pas') or (Ext = '.pp') or (Ext = '.inc') or (Ext = '.lpr') or (Ext = '.lpi') or (Ext = '.lpk') or
             (Ext = '.md') or (Ext = '.txt') or (Ext = '.rst') or (Ext = '.json') then
          begin
            if not IsBuildArtifactCore(SearchRec.Name) then
              Files.Add(FullPath);
          end;
        end;
      until FindNext(SearchRec) <> 0;
      FindClose(SearchRec);
    end;
  end;

begin
  Result := nil;
  Files := TStringList.Create;
  try
    ScanDirectory(SourceDir);

    SetLength(Result, 0);
    for i := 0 to Files.Count - 1 do
    begin
      RelPath := ExtractRelativePath(IncludeTrailingPathDelimiter(SourceDir), Files[i]);
      Excluded := False;

      for j := 0 to High(ExcludePatterns) do
      begin
        if Pos(ExcludePatterns[j], RelPath) > 0 then
        begin
          Excluded := True;
          Break;
        end;
      end;

      if not Excluded then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Files[i];
      end;
    end;
  finally
    Files.Free;
  end;
end;

function GeneratePackageMetadataJsonCore(
  const Options: TPackageCreateOptions): string;
begin
  Result := '{' +
            '"name":"' + Options.Name + '",' +
            '"version":"' + Options.Version + '",' +
            '"description":"A FreePascal package",' +
            '"author":"",' +
            '"license":"MIT",' +
            '"homepage":"",' +
            '"repository":"",' +
            '"dependencies":[],' +
            '"keywords":[]' +
            '}';
end;

function EnsurePackageMetadataFileCore(const APackageName, ASourceDir, AMetaPath: string;
  out ACreated: Boolean; out AError: string): Boolean;
var
  Options: TPackageCreateOptions;
  MetaDir: string;
  MetaText: TStringList;
begin
  ACreated := False;
  AError := '';

  if FileExists(AMetaPath) then
    Exit(True);

  MetaDir := ExtractFileDir(AMetaPath);
  if (MetaDir <> '') and (not DirectoryExists(MetaDir)) then
    EnsureDir(MetaDir);

    MetaText := TStringList.Create;
  try
    Initialize(Options);
    Options.Name := APackageName;
    Options.Version := DEFAULT_PACKAGE_VERSION;
    Options.SourcePath := ASourceDir;
    MetaText.Text := GeneratePackageMetadataJsonCore(Options);
    MetaText.SaveToFile(AMetaPath);
    ACreated := True;
    Result := True;
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;
  MetaText.Free;
end;

function CreatePackageZipArchiveCore(const SourceDir: string;
  const Files: TStringArray; const OutputPath: string; var Err: string): Boolean;
var
  Archiver: TPackageArchiver;
begin
  Result := False;
  Err := '';

  if not DirectoryExists(ExtractFileDir(OutputPath)) then
    EnsureDir(ExtractFileDir(OutputPath));

  if Length(Files) = -1 then
    Err := '';

  Archiver := TPackageArchiver.Create(SourceDir);
  try
    if not Archiver.CreateArchive(OutputPath) then
    begin
      Err := Archiver.GetLastError;
      Exit;
    end;
    Result := True;
  finally
    Archiver.Free;
  end;
end;

end.
