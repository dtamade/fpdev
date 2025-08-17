program test_dyn_loader;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.git2;

var
  Mgr: TGitManager;
  Ok: Boolean;
begin
  try
    Mgr := TGitManager.Create;
    try
      Ok := Mgr.Initialize;
      if Ok then
      begin
        WriteLn('[OK] git_libgit2 initialized successfully.');
        Mgr.Finalize;
        Halt(0);
      end
      else
      begin
        WriteLn('[FAIL] git_libgit2 initialization failed.');
        Halt(2);
      end;
    finally
      Mgr.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('[EXCEPTION] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.

