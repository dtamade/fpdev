program test_ssl_toggle;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.git2;

var
  M: TGitManager;
begin
  M := TGitManager.Create;
  try
    if not M.Initialize then
    begin
      WriteLn('INIT_FAIL');
      Halt(1);
    end;

    // 注意：SetVerifySSL 会通过 git_config 写入 http.sslVerify，可能影响全局配置。
    // 本示例仅用于演示 API 使用，请谨慎执行。

    WriteLn('VerifySSL (before): ', M.VerifySSL);
    M.SetVerifySSL(False);
    WriteLn('VerifySSL (after set false): ', M.VerifySSL);
    M.SetVerifySSL(True);
    WriteLn('VerifySSL (after set true): ', M.VerifySSL);

    WriteLn('OK:SSL_TOGGLE_DEMO');
  finally
    M.Free;
  end;
end.

