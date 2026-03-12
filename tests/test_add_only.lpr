program test_add_only;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config;

var
  Config: TFPDevConfigManager;
  TempConfigPath: string;
  TempRoot: string;
begin
  TempRoot := IncludeTrailingPathDelimiter(GetTempDir(False))
    + 'fpdev-test-add-only-' + IntToStr(GetTickCount64);
  ForceDirectories(TempRoot);
  TempConfigPath := IncludeTrailingPathDelimiter(TempRoot) + 'config.json';

  WriteLn('Creating...');
  Config := TFPDevConfigManager.Create(TempConfigPath);
  try
    if Pos(IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False))),
      ExpandFileName(Config.ConfigPath)) = 1 then
      WriteLn('PASS: Config path uses system temp root')
    else
      WriteLn('FAIL: Config path is not under system temp root: ' + Config.ConfigPath);

    WriteLn('Calling AddRepository...');
    if Config.AddRepository('test', 'https://example.com/test.git') then
      WriteLn('PASS: Repository added')
    else
      WriteLn('FAIL: Failed to add repository');
    WriteLn('AddRepository returned');
  finally
    WriteLn('Freeing...');
    Config.Free;
    WriteLn('Freed');
    DeleteFile(TempConfigPath);
    if DirectoryExists(TempRoot) then
      RemoveDir(TempRoot);
  end;
  WriteLn('Exiting...');
end.
