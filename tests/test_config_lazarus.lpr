program test_config_lazarus;

{$mode objfpc}{$H+}

uses
  SysUtils, fpjson,
  fpdev.config.interfaces,
  fpdev.config.lazarus;

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

procedure TestAddGetListAndDefault;
var
  Stub: TStubNotifier;
  Notifier: IConfigChangeNotifier;
  Mgr: TLazarusManager;
  Info, ReadBack: TLazarusInfo;
  Versions: TStringArray;
begin
  Stub := TStubNotifier.Create;
  Notifier := Stub;
  Mgr := TLazarusManager.Create(Notifier);
  try
    FillChar(Info, SizeOf(Info), 0);
    Info.Version := '3.0';
    Info.FPCVersion := 'fpc-3.2.2';
    Info.InstallPath := '/opt/lazarus/3.0';
    Info.SourceURL := 'https://gitlab.com/freepascal.org/lazarus.git';
    Info.Branch := 'lazarus_3_0';
    Info.Installed := True;

    Check(Mgr.AddLazarusVersion('lazarus-3.0', Info), 'lazarus manager adds version');
    Check(Stub.Calls = 1, 'lazarus manager notifies on add');
    Check(Mgr.GetLazarusVersion('lazarus-3.0', ReadBack), 'lazarus manager gets version');
    Check(ReadBack.InstallPath = '/opt/lazarus/3.0', 'lazarus manager preserves install path');
    Versions := Mgr.ListLazarusVersions;
    Check((Length(Versions) = 1) and (Versions[0] = 'lazarus-3.0'),
      'lazarus manager lists versions');
    Check(Mgr.SetDefaultLazarusVersion('lazarus-3.0'), 'lazarus manager sets default');
    Check(Mgr.GetDefaultLazarusVersion = 'lazarus-3.0', 'lazarus manager returns default');
  finally
    Mgr.Free;
  end;
end;

procedure TestRemoveLazarusVersion;
var
  Stub: TStubNotifier;
  Notifier: IConfigChangeNotifier;
  Mgr: TLazarusManager;
  Info: TLazarusInfo;
begin
  Stub := TStubNotifier.Create;
  Notifier := Stub;
  Mgr := TLazarusManager.Create(Notifier);
  try
    FillChar(Info, SizeOf(Info), 0);
    Info.Version := '3.0';
    Mgr.AddLazarusVersion('lazarus-3.0', Info);
    Stub.Calls := 0;
    Check(Mgr.RemoveLazarusVersion('lazarus-3.0'), 'lazarus manager removes version');
    Check(Stub.Calls = 1, 'lazarus manager notifies on remove');
    Check(not Mgr.GetLazarusVersion('lazarus-3.0', Info), 'lazarus manager removes lookup entry');
  finally
    Mgr.Free;
  end;
end;

procedure TestLoadAndSaveJSON;
var
  Mgr: TLazarusManager;
  JSON, Saved: TJSONObject;
  Info: TLazarusInfo;
begin
  Mgr := TLazarusManager.Create(nil);
  try
    JSON := TJSONObject.Create;
    try
      JSON.Add('default_version', 'lazarus-3.0');
      JSON.Add('versions', TJSONObject.Create([
        'lazarus-3.0', TJSONObject.Create([
          'version', '3.0',
          'fpc_version', 'fpc-3.2.2',
          'install_path', '/opt/lazarus/3.0',
          'source_url', 'https://gitlab.com/freepascal.org/lazarus.git',
          'branch', 'lazarus_3_0',
          'installed', True
        ])
      ]));
      Mgr.LoadFromJSON(JSON);
    finally
      JSON.Free;
    end;

    Check(Mgr.GetDefaultLazarusVersion = 'lazarus-3.0', 'lazarus manager loads default version');
    Check(Mgr.GetLazarusVersion('lazarus-3.0', Info), 'lazarus manager loads version json');
    Check(Info.FPCVersion = 'fpc-3.2.2', 'lazarus manager loads fpc version');

    Mgr.SaveToJSON(Saved);
    try
      Check(Saved.Get('default_version', '') = 'lazarus-3.0',
        'lazarus manager saves default version');
      Check(Saved.Objects['versions'].Objects['lazarus-3.0'].Get('branch', '') = 'lazarus_3_0',
        'lazarus manager saves branch');
    finally
      Saved.Free;
    end;
  finally
    Mgr.Free;
  end;
end;

begin
  WriteLn('=== Config Lazarus Manager Tests ===');
  TestAddGetListAndDefault;
  TestRemoveLazarusVersion;
  TestLoadAndSaveJSON;
  WriteLn('Passed: ', Passed);
  WriteLn('Failed: ', Failed);
  if Failed > 0 then
    Halt(1);
end.
