program test_build_cache_indexflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils,
  fpdev.build.cache.types,
  fpdev.build.cache.indexflow;

type
  TIndexFlowHarness = class
  public
    LookupCalls: Integer;
    UpdateCalls: Integer;
    SaveMetadataCalls: Integer;
    SaveIndexCalls: Integer;
    LookupOK: Boolean;
    LookupInfo: TArtifactInfo;
    UpdatedInfo: TArtifactInfo;
    SavedMetadataInfo: TArtifactInfo;
    function Lookup(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
    procedure Update(const AInfo: TArtifactInfo);
    procedure SaveMetadata(const AInfo: TArtifactInfo);
    procedure SaveIndex;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

function TIndexFlowHarness.Lookup(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
begin
  Inc(LookupCalls);
  if LookupOK and (LookupInfo.Version = AVersion) then
    AInfo := LookupInfo
  else
    Initialize(AInfo);
  Result := LookupOK and (LookupInfo.Version = AVersion);
end;

procedure TIndexFlowHarness.Update(const AInfo: TArtifactInfo);
begin
  Inc(UpdateCalls);
  UpdatedInfo := AInfo;
end;

procedure TIndexFlowHarness.SaveMetadata(const AInfo: TArtifactInfo);
begin
  Inc(SaveMetadataCalls);
  SavedMetadataInfo := AInfo;
end;

procedure TIndexFlowHarness.SaveIndex;
begin
  Inc(SaveIndexCalls);
end;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure TestLookupIndexArtifactInfoParsesJSON;
var
  Info: TArtifactInfo;
  OK: Boolean;
  CreatedAt, AccessedAt: TDateTime;
  EntryJSON: string;
begin
  CreatedAt := EncodeDateTime(2026, 3, 10, 10, 0, 0, 0);
  AccessedAt := EncodeDateTime(2026, 3, 10, 11, 30, 0, 0);
  EntryJSON :=
    '{' +
    '"version":"3.2.2",' +
    '"cpu":"x86_64",' +
    '"os":"linux",' +
    '"archive_path":"/tmp/fpc-3.2.2.tar.gz",' +
    '"archive_size":123456,' +
    '"created_at":"2026-03-10T10:00:00",' +
    '"source_type":"source",' +
    '"sha256":"abc123",' +
    '"download_url":"https://example.com/fpc.tar.gz",' +
    '"source_path":"/src/fpc-3.2.2",' +
    '"access_count":7,' +
    '"last_accessed":"2026-03-10T11:30:00"' +
    '}';

  OK := BuildCacheLookupIndexArtifactInfo(EntryJSON, Info);

  Check('lookup indexflow parses json', OK, 'expected parse success');
  Check('lookup indexflow maps version', Info.Version = '3.2.2', 'version=' + Info.Version);
  Check('lookup indexflow maps archive path', Info.ArchivePath = '/tmp/fpc-3.2.2.tar.gz', 'path=' + Info.ArchivePath);
  Check('lookup indexflow maps access count', Info.AccessCount = 7, 'count=' + IntToStr(Info.AccessCount));
  Check('lookup indexflow maps created_at', Info.CreatedAt = CreatedAt, 'created mismatch');
  Check('lookup indexflow maps last_accessed', Info.LastAccessed = AccessedAt, 'accessed mismatch');
end;

procedure TestLookupIndexArtifactInfoRejectsInvalidJSON;
var
  Info: TArtifactInfo;
begin
  Check('lookup indexflow rejects invalid json',
    not BuildCacheLookupIndexArtifactInfo('not-json', Info),
    'invalid json should fail');
end;

procedure TestUpsertAndRemoveIndexEntries;
var
  Entries: TStringList;
  Info: TArtifactInfo;
begin
  Entries := TStringList.Create;
  try
    Entries.Sorted := True;
    Entries.Duplicates := dupIgnore;

    Initialize(Info);
    Info.Version := '3.2.1';
    Info.CPU := 'x86_64';
    Info.OS := 'linux';
    Info.ArchivePath := '/tmp/a.tar.gz';
    Info.ArchiveSize := 10;
    Info.CreatedAt := EncodeDateTime(2026, 3, 10, 8, 0, 0, 0);
    BuildCacheUpsertIndexEntry(Entries, Info);

    Check('upsert indexflow adds entry', Entries.Count = 1, 'count=' + IntToStr(Entries.Count));
    Check('upsert indexflow stores json by version', Entries.Values['3.2.1'] <> '', 'missing value');

    Info.ArchiveSize := 42;
    BuildCacheUpsertIndexEntry(Entries, Info);
    Check('upsert indexflow replaces existing entry', Entries.Count = 1, 'count=' + IntToStr(Entries.Count));
    Check('upsert indexflow updates stored payload', Pos('42', Entries.Values['3.2.1']) > 0, 'payload=' + Entries.Values['3.2.1']);

    BuildCacheRemoveIndexEntryVersion(Entries, '3.2.1');
    Check('remove indexflow removes existing version', Entries.Count = 0, 'count=' + IntToStr(Entries.Count));

    BuildCacheRemoveIndexEntryVersion(Entries, '9.9.9');
    Check('remove indexflow ignores missing version', Entries.Count = 0, 'count=' + IntToStr(Entries.Count));
  finally
    Entries.Free;
  end;
end;

procedure TestRecordIndexAccessCoreUpdatesAndPersists;
var
  Harness: TIndexFlowHarness;
  AccessedAt: TDateTime;
  OK: Boolean;
begin
  Harness := TIndexFlowHarness.Create;
  try
    Harness.LookupOK := True;
    Initialize(Harness.LookupInfo);
    Harness.LookupInfo.Version := '3.2.2';
    Harness.LookupInfo.AccessCount := 2;
    Harness.LookupInfo.LastAccessed := 0;
    Harness.LookupInfo.ArchivePath := '/tmp/fpc.tar.gz';

    AccessedAt := EncodeDateTime(2026, 3, 10, 12, 0, 0, 0);
    OK := BuildCacheRecordIndexAccessCore(
      '3.2.2',
      AccessedAt,
      @Harness.Lookup,
      @Harness.Update,
      @Harness.SaveMetadata,
      @Harness.SaveIndex
    );

    Check('record indexflow returns true on hit', OK, 'expected success');
    Check('record indexflow looks up once', Harness.LookupCalls = 1, 'calls=' + IntToStr(Harness.LookupCalls));
    Check('record indexflow updates once', Harness.UpdateCalls = 1, 'calls=' + IntToStr(Harness.UpdateCalls));
    Check('record indexflow saves metadata once', Harness.SaveMetadataCalls = 1, 'calls=' + IntToStr(Harness.SaveMetadataCalls));
    Check('record indexflow saves index once', Harness.SaveIndexCalls = 1, 'calls=' + IntToStr(Harness.SaveIndexCalls));
    Check('record indexflow increments count', Harness.UpdatedInfo.AccessCount = 3, 'count=' + IntToStr(Harness.UpdatedInfo.AccessCount));
    Check('record indexflow updates timestamp', Harness.UpdatedInfo.LastAccessed = AccessedAt, 'timestamp mismatch');
    Check('record indexflow saves same updated info', Harness.SavedMetadataInfo.AccessCount = 3, 'saved count=' + IntToStr(Harness.SavedMetadataInfo.AccessCount));
  finally
    Harness.Free;
  end;
end;

procedure TestRecordIndexAccessCoreIgnoresMissingVersion;
var
  Harness: TIndexFlowHarness;
begin
  Harness := TIndexFlowHarness.Create;
  try
    Harness.LookupOK := False;
    Check('record indexflow returns false on miss',
      not BuildCacheRecordIndexAccessCore(
        'missing',
        EncodeDateTime(2026, 3, 10, 12, 30, 0, 0),
        @Harness.Lookup,
        @Harness.Update,
        @Harness.SaveMetadata,
        @Harness.SaveIndex
      ),
      'missing version should fail');
    Check('record indexflow skips update on miss', Harness.UpdateCalls = 0, 'update calls=' + IntToStr(Harness.UpdateCalls));
    Check('record indexflow skips save metadata on miss', Harness.SaveMetadataCalls = 0, 'save meta calls=' + IntToStr(Harness.SaveMetadataCalls));
    Check('record indexflow skips save index on miss', Harness.SaveIndexCalls = 0, 'save index calls=' + IntToStr(Harness.SaveIndexCalls));
  finally
    Harness.Free;
  end;
end;

begin
  TestLookupIndexArtifactInfoParsesJSON;
  TestLookupIndexArtifactInfoRejectsInvalidJSON;
  TestUpsertAndRemoveIndexEntries;
  TestRecordIndexAccessCoreUpdatesAndPersists;
  TestRecordIndexAccessCoreIgnoresMissingVersion;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
