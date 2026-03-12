unit fpdev.config.settings;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson,
  fpdev.config.interfaces;

type
  TSettingsManager = class(TInterfacedObject, ISettingsManager)
  private
    FNotifier: IConfigChangeNotifier;
    FSettings: TFPDevSettings;
  public
    constructor Create(ANotifier: IConfigChangeNotifier);

    function GetSettings: TFPDevSettings;
    function SetSettings(const ASettings: TFPDevSettings): Boolean;

    procedure LoadFromJSON(ASettings: TJSONObject);
    procedure SaveToJSON(out ASettings: TJSONObject);
  end;

implementation

constructor TSettingsManager.Create(ANotifier: IConfigChangeNotifier);
begin
  inherited Create;
  FNotifier := ANotifier;

  FSettings.AutoUpdate := False;
  FSettings.ParallelJobs := 4;
  FSettings.KeepSources := True;
  FSettings.InstallRoot := '';
  FSettings.DefaultRepo := '';
  FSettings.Mirror := 'auto';
  FSettings.CustomRepoURL := '';
end;

function TSettingsManager.GetSettings: TFPDevSettings;
begin
  Result := FSettings;
end;

function TSettingsManager.SetSettings(const ASettings: TFPDevSettings): Boolean;
begin
  Result := False;
  try
    FSettings := ASettings;
    if Assigned(FNotifier) then
      FNotifier.NotifyConfigChanged;
    Result := True;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

procedure TSettingsManager.LoadFromJSON(ASettings: TJSONObject);
begin
  if Assigned(ASettings) then
  begin
    FSettings.AutoUpdate := ASettings.Get('auto_update', False);
    FSettings.ParallelJobs := ASettings.Get('parallel_jobs', 4);
    FSettings.KeepSources := ASettings.Get('keep_sources', True);
    FSettings.InstallRoot := ExcludeTrailingPathDelimiter(ASettings.Get('install_root', ''));
    FSettings.DefaultRepo := ASettings.Get('default_repo', '');
    FSettings.Mirror := ASettings.Get('mirror', 'auto');
    FSettings.CustomRepoURL := ASettings.Get('custom_repo_url', '');
  end;
end;

procedure TSettingsManager.SaveToJSON(out ASettings: TJSONObject);
begin
  ASettings := TJSONObject.Create;
  ASettings.Add('auto_update', FSettings.AutoUpdate);
  ASettings.Add('parallel_jobs', FSettings.ParallelJobs);
  ASettings.Add('keep_sources', FSettings.KeepSources);
  ASettings.Add('install_root', FSettings.InstallRoot);
  ASettings.Add('default_repo', FSettings.DefaultRepo);
  ASettings.Add('mirror', FSettings.Mirror);
  ASettings.Add('custom_repo_url', FSettings.CustomRepoURL);
end;

end.
