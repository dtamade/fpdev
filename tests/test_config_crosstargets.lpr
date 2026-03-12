program test_config_crosstargets;

{$mode objfpc}{$H+}

uses
  SysUtils, fpjson,
  fpdev.config.interfaces,
  fpdev.config.crosstargets;

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

procedure TestAddGetAndListCrossTarget;
var
  Stub: TStubNotifier;
  Notifier: IConfigChangeNotifier;
  Mgr: TCrossTargetManager;
  Info, ReadBack: TCrossTarget;
  Targets: TStringArray;
begin
  Stub := TStubNotifier.Create;
  Notifier := Stub;
  Mgr := TCrossTargetManager.Create(Notifier);
  try
    FillChar(Info, SizeOf(Info), 0);
    Info.Enabled := True;
    Info.BinutilsPath := '/opt/binutils';
    Info.LibrariesPath := '/opt/libs';
    Info.CPU := 'arm';
    Info.OS := 'linux';
    Info.BinutilsPrefix := 'arm-linux-gnueabihf-';

    Check(Mgr.AddCrossTarget('arm-linux', Info), 'cross target manager adds target');
    Check(Stub.Calls = 1, 'cross target manager notifies on add');
    Check(Mgr.GetCrossTarget('arm-linux', ReadBack), 'cross target manager gets target');
    Check(ReadBack.BinutilsPath = '/opt/binutils', 'cross target manager preserves binutils path');
    Check(ReadBack.CPU = 'arm', 'cross target manager preserves cpu');
    Targets := Mgr.ListCrossTargets;
    Check((Length(Targets) = 1) and (Targets[0] = 'arm-linux'),
      'cross target manager lists target names');
  finally
    Mgr.Free;
  end;
end;

procedure TestRemoveCrossTarget;
var
  Stub: TStubNotifier;
  Notifier: IConfigChangeNotifier;
  Mgr: TCrossTargetManager;
  Info: TCrossTarget;
begin
  Stub := TStubNotifier.Create;
  Notifier := Stub;
  Mgr := TCrossTargetManager.Create(Notifier);
  try
    FillChar(Info, SizeOf(Info), 0);
    Info.Enabled := True;
    Mgr.AddCrossTarget('win64', Info);
    Stub.Calls := 0;
    Check(Mgr.RemoveCrossTarget('win64'), 'cross target manager removes target');
    Check(Stub.Calls = 1, 'cross target manager notifies on remove');
    Check(not Mgr.GetCrossTarget('win64', Info), 'cross target manager removes target from lookup');
  finally
    Mgr.Free;
  end;
end;

procedure TestLoadAndSaveJSON;
var
  Mgr: TCrossTargetManager;
  JSON, Saved: TJSONObject;
  Info: TCrossTarget;
begin
  Mgr := TCrossTargetManager.Create(nil);
  try
    JSON := TJSONObject.Create;
    try
      JSON.Add('win64', TJSONObject.Create([
        'enabled', True,
        'binutils_path', '/usr/x86_64-w64-mingw32/bin',
        'libraries_path', '/usr/x86_64-w64-mingw32/lib',
        'cpu', 'x86_64',
        'os', 'win64'
      ]));
      Mgr.LoadFromJSON(JSON);
    finally
      JSON.Free;
    end;

    Check(Mgr.GetCrossTarget('win64', Info), 'cross target manager loads json target');
    Check(Info.OS = 'win64', 'cross target manager loads os');

    Mgr.SaveToJSON(Saved);
    try
      Check(Assigned(Saved.Find('win64')), 'cross target manager saves target json');
      Check(Saved.Objects['win64'].Get('cpu', '') = 'x86_64',
        'cross target manager saves cpu');
    finally
      Saved.Free;
    end;
  finally
    Mgr.Free;
  end;
end;

begin
  WriteLn('=== Config Cross Target Manager Tests ===');
  TestAddGetAndListCrossTarget;
  TestRemoveCrossTarget;
  TestLoadAndSaveJSON;
  WriteLn('Passed: ', Passed);
  WriteLn('Failed: ', Failed);
  if Failed > 0 then
    Halt(1);
end.
