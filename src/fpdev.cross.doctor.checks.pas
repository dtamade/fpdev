unit fpdev.cross.doctor.checks;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.intf;

function ExecuteCrossDoctorChecksCore(const Ctx: IContext): Integer;

implementation

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.cross.search,
  fpdev.doctor.runtime,
  fpdev.i18n,
  fpdev.i18n.strings;

function ResolveCrossDoctorInstallRoot(const Ctx: IContext): string;
var
  Settings: TFPDevSettings;
begin
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Result := Settings.InstallRoot;
  if Result = '' then
    Result := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'data';
end;

function ExecuteCrossDoctorChecksCore(const Ctx: IContext): Integer;
var
  LOut: string;
  LErr: string;
  LOk: Boolean;
  LRoot: string;
  Search: TCrossToolchainSearch;
  DiagTarget: TCrossTarget;
  DiagLines: TStringArray;
  DiagIndex: Integer;
begin
  Result := 0;

  Ctx.Out.WriteLn(_(MSG_CHECKING_CROSS_ENV));
  Ctx.Out.WriteLn('');

  LRoot := ResolveCrossDoctorInstallRoot(Ctx);
  LOk := CheckDoctorWriteableDirCore(LRoot, LErr);
  if LOk then
    Ctx.Out.WriteLn(_Fmt(MSG_DOCTOR_WRITE_OK, [LRoot]))
  else
  begin
    Ctx.Out.WriteLn(_Fmt(MSG_DOCTOR_WRITE_FAIL, [LRoot, LErr]));
    Inc(Result);
  end;

  LOk := RunDoctorToolVersionCore('fpc', '-i', LOut);
  if LOk then
    Ctx.Out.WriteLn(_(MSG_DOCTOR_FPC_OK))
  else
  begin
    Ctx.Out.WriteLn('[X] FPC compiler not found (cross-compilation requires FPC)');
    Inc(Result);
  end;

  Search := TCrossToolchainSearch.Create;
  try
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Cross-compilation toolchain search:');

    DiagTarget := Default(TCrossTarget);
    DiagTarget.CPU := 'x86_64';
    DiagTarget.OS := 'win64';
    DiagLines := Search.DiagnoseTarget(DiagTarget);
    for DiagIndex := 0 to High(DiagLines) do
      Ctx.Out.WriteLn('  ' + DiagLines[DiagIndex]);
    Ctx.Out.WriteLn('');

    DiagTarget := Default(TCrossTarget);
    DiagTarget.CPU := 'arm';
    DiagTarget.OS := 'linux';
    DiagLines := Search.DiagnoseTarget(DiagTarget);
    for DiagIndex := 0 to High(DiagLines) do
      Ctx.Out.WriteLn('  ' + DiagLines[DiagIndex]);
    Ctx.Out.WriteLn('');

    DiagTarget := Default(TCrossTarget);
    DiagTarget.CPU := 'aarch64';
    DiagTarget.OS := 'linux';
    DiagLines := Search.DiagnoseTarget(DiagTarget);
    for DiagIndex := 0 to High(DiagLines) do
      Ctx.Out.WriteLn('  ' + DiagLines[DiagIndex]);
  finally
    Search.Free;
  end;

  LRoot := IncludeTrailingPathDelimiter(ResolveCrossDoctorInstallRoot(Ctx)) + 'cross';
  if DirectoryExists(LRoot) then
    Ctx.Out.WriteLn('[OK] Cross-compilation directory exists: ' + LRoot)
  else
    Ctx.Out.WriteLn('[!] Cross-compilation directory not found: ' + LRoot);
end;

end.
