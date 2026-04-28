unit fpdev.cross.installsupportflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf,
  fpdev.config.interfaces,
  fpdev.cross.query;

type
  TCrossInstallSupportDownloadFunc = function(const ATarget: string): Boolean of object;
  TCrossInstallSupportErrorFunc = function: string of object;
  TCrossInstallSupportInstallPathFunc = function(const ATarget: string): string of object;
  TCrossInstallSupportSaveConfigFunc = function(
    const ATarget: string;
    const AInfo: TCrossTarget
  ): Boolean of object;

function ExecuteCrossDownloadBinutilsSurfaceCore(
  const ATarget: string;
  const ATargetInfo: TCrossTargetQueryInfo;
  ADownloadBinutils: TCrossInstallSupportDownloadFunc;
  AGetDownloaderLastError: TCrossInstallSupportErrorFunc;
  Outp: IOutput
): Boolean;

function ExecuteCrossDownloadLibrariesSurfaceCore(
  const ATarget: string;
  const ATargetInfo: TCrossTargetQueryInfo;
  ADownloadLibraries: TCrossInstallSupportDownloadFunc;
  Outp: IOutput
): Boolean;

function ExecuteCrossSetupEnvironmentSurfaceCore(
  const ATarget: string;
  const ATargetInfo: TCrossTargetQueryInfo;
  AGetTargetInstallPath: TCrossInstallSupportInstallPathFunc;
  ASaveCrossTargetConfig: TCrossInstallSupportSaveConfigFunc
): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.cross.targetflow;

function ExecuteCrossDownloadBinutilsSurfaceCore(
  const ATarget: string;
  const ATargetInfo: TCrossTargetQueryInfo;
  ADownloadBinutils: TCrossInstallSupportDownloadFunc;
  AGetDownloaderLastError: TCrossInstallSupportErrorFunc;
  Outp: IOutput
): Boolean;
var
  LastErrorText: string;
begin
  Result := False;
  if Pointer(@ATargetInfo) = nil then;
  if ATarget = '' then
    Exit;

  if not Assigned(ADownloadBinutils) then
  begin
    if Outp <> nil then
      Outp.WriteLn(_(MSG_ERROR) + ': Toolchain downloader not initialized');
    Exit;
  end;

  if Outp <> nil then
    Outp.WriteLn(_Fmt(MSG_CROSS_DOWNLOADING_BINUTILS, [ATarget]));

  Result := ADownloadBinutils(ATarget);
  if Result then
  begin
    if Outp <> nil then
      Outp.WriteLn(_(MSG_CROSS_BINUTILS_SUCCESS));
    Exit;
  end;

  LastErrorText := '';
  if Assigned(AGetDownloaderLastError) then
    LastErrorText := AGetDownloaderLastError();

  if Outp <> nil then
  begin
    if LastErrorText <> '' then
      Outp.WriteLn(_(MSG_ERROR) + ': ' + LastErrorText);
    Outp.WriteLn(_Fmt(MSG_CROSS_MANIFEST_NOT_FOUND, ['cross-manifest.json']));
  end;
end;

function ExecuteCrossDownloadLibrariesSurfaceCore(
  const ATarget: string;
  const ATargetInfo: TCrossTargetQueryInfo;
  ADownloadLibraries: TCrossInstallSupportDownloadFunc;
  Outp: IOutput
): Boolean;
begin
  Result := False;
  if Pointer(@ATargetInfo) = nil then;
  if ATarget = '' then
    Exit;

  if not Assigned(ADownloadLibraries) then
  begin
    if Outp <> nil then
      Outp.WriteLn(_(MSG_ERROR) + ': Toolchain downloader not initialized');
    Exit;
  end;

  if Outp <> nil then
    Outp.WriteLn(_Fmt(MSG_CROSS_DOWNLOADING_LIBS, [ATarget]));

  Result := ADownloadLibraries(ATarget);
  if Result then
  begin
    if Outp <> nil then
      Outp.WriteLn(_(MSG_CROSS_LIBS_SUCCESS));
    Exit;
  end;

  if Outp <> nil then
  begin
    Outp.WriteLn(_(MSG_CROSS_LIBS_MANUAL_INSTALL));
    Outp.WriteLn(_(MSG_CROSS_LIBS_NOTE));
  end;
  Result := True;
end;

function ExecuteCrossSetupEnvironmentSurfaceCore(
  const ATarget: string;
  const ATargetInfo: TCrossTargetQueryInfo;
  AGetTargetInstallPath: TCrossInstallSupportInstallPathFunc;
  ASaveCrossTargetConfig: TCrossInstallSupportSaveConfigFunc
): Boolean;
var
  InstallPath: string;
  CrossTarget: TCrossTarget;
begin
  Result := False;
  if Pointer(@ATargetInfo) = nil then;
  if (ATarget = '') or (not Assigned(AGetTargetInstallPath)) or
     (not Assigned(ASaveCrossTargetConfig)) then
    Exit;

  try
    InstallPath := AGetTargetInstallPath(ATarget);
    CrossTarget := CreateCrossTargetConfigCore(
      True,
      InstallPath + PathDelim + 'bin',
      InstallPath + PathDelim + 'lib'
    );
    Result := ASaveCrossTargetConfig(ATarget, CrossTarget);
  except
    on E: Exception do
    begin
      if E.Message = '' then;
      Result := False;
    end;
  end;
end;

end.
