program test_config_repositories;

{$mode objfpc}{$H+}

uses
  SysUtils, fpjson,
  fpdev.config.interfaces,
  fpdev.config.repositories;

type
  TStubNotifier = class(TInterfacedObject, IConfigChangeNotifier)
  public
    Calls: Integer;
    procedure NotifyConfigChanged;
  end;

procedure TStubNotifier.NotifyConfigChanged;
begin
  Inc(Calls);
end;

var
  Passed: Integer = 0;
  Failed: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(Passed);
    WriteLn('[PASS] ', AMessage);
  end
  else
  begin
    Inc(Failed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

procedure TestAddGetAndListRepository;
var
  Notifier: IConfigChangeNotifier;
  Stub: TStubNotifier;
  RepoMgr: TRepositoryManager;
  Repos: TStringArray;
begin
  Stub := TStubNotifier.Create;
  Notifier := Stub;
  RepoMgr := TRepositoryManager.Create(Notifier);
  try
    Check(RepoMgr.AddRepository('official', 'https://example.com/repo.git'),
      'repository manager adds repository');
    Check(RepoMgr.GetRepository('official') = 'https://example.com/repo.git',
      'repository manager returns repository url');
    Check(RepoMgr.HasRepository('official'),
      'repository manager reports existing repository');
    Repos := RepoMgr.ListRepositories;
    Check((Length(Repos) = 1) and (Repos[0] = 'official'),
      'repository manager lists repository names');
    Check(Stub.Calls = 1, 'repository manager notifies on add');
  finally
    RepoMgr.Free;
  end;
end;

procedure TestRemoveRepository;
var
  Notifier: IConfigChangeNotifier;
  Stub: TStubNotifier;
  RepoMgr: TRepositoryManager;
begin
  Stub := TStubNotifier.Create;
  Notifier := Stub;
  RepoMgr := TRepositoryManager.Create(Notifier);
  try
    RepoMgr.AddRepository('official', 'https://example.com/repo.git');
    Stub.Calls := 0;
    Check(RepoMgr.RemoveRepository('official'),
      'repository manager removes existing repository');
    Check(not RepoMgr.HasRepository('official'),
      'repository manager removes repository from lookup');
    Check(Stub.Calls = 1, 'repository manager notifies on remove');
  finally
    RepoMgr.Free;
  end;
end;

procedure TestLoadAndSaveJSON;
var
  RepoMgr: TRepositoryManager;
  ReposJSON: TJSONObject;
  SavedRepos: TJSONObject;
  DefaultRepo: string;
begin
  RepoMgr := TRepositoryManager.Create(nil);
  try
    ReposJSON := TJSONObject.Create;
    try
      ReposJSON.Add('official_fpc', 'https://gitlab.com/freepascal.org/fpc/source.git');
      ReposJSON.Add('official_lazarus', 'https://gitlab.com/freepascal.org/lazarus/lazarus.git');
      RepoMgr.LoadFromJSON(ReposJSON, 'official_fpc');
    finally
      ReposJSON.Free;
    end;

    Check(RepoMgr.GetDefaultRepository = 'official_fpc',
      'repository manager preserves default repository');
    Check(RepoMgr.GetRepository('official_lazarus') <> '',
      'repository manager loads json repositories');

    RepoMgr.SaveToJSON(SavedRepos, DefaultRepo);
    try
      Check(DefaultRepo = 'official_fpc',
        'repository manager saves default repository');
      Check(SavedRepos.Get('official_fpc', '') = 'https://gitlab.com/freepascal.org/fpc/source.git',
        'repository manager saves repository json');
    finally
      SavedRepos.Free;
    end;
  finally
    RepoMgr.Free;
  end;
end;

begin
  WriteLn('=== Config Repository Manager Tests ===');
  TestAddGetAndListRepository;
  TestRemoveRepository;
  TestLoadAndSaveJSON;
  WriteLn('Passed: ', Passed);
  WriteLn('Failed: ', Failed);
  if Failed > 0 then
    Halt(1);
end.
