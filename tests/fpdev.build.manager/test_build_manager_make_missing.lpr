program test_build_manager_make_missing;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.manager;

procedure EnsureDir(const APath: string);
begin
  if (APath <> '') and (not DirectoryExists(APath)) then
    ForceDirectories(APath);
end;

procedure Fail(const AMsg: string);
begin
  WriteLn('[FAIL] ', AMsg);
  Halt(1);
end;

procedure Pass(const AMsg: string);
begin
  WriteLn('[PASS] ', AMsg);
end;

var
  LBM: TBuildManager;
  LSrcRoot, LSrcTree: string;
  LOk: Boolean;
  LErr: string;
begin
  // BuildManager expects: <sourceRoot>/fpc-<version>/...
  LSrcRoot := 'tests_tmp' + PathDelim + 'bm_make_missing' + PathDelim + 'sources' + PathDelim + 'fpc';
  LSrcTree := IncludeTrailingPathDelimiter(LSrcRoot) + 'fpc-main';
  EnsureDir(LSrcTree);

  LBM := TBuildManager.Create(LSrcRoot, 1, False);
  try
    // Force a non-existent make command: BuildCompiler should not crash.
    LBM.SetMakeCmd('fpdev-make-does-not-exist');

    try
      LOk := LBM.BuildCompiler('main');
    except
      on E: Exception do
        Fail('BuildCompiler raised exception: ' + E.ClassName + ': ' + E.Message);
    end;

    if LOk then
      Fail('BuildCompiler should fail when make is missing');

    LErr := LBM.GetLastError;
    if LErr = '' then
      Fail('GetLastError should be set when make is missing');

    Pass('BuildCompiler fails gracefully when make is missing');
  finally
    LBM.Free;
  end;
end.

