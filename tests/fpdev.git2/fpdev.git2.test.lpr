program fpdev_git2_test;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  git2.api, git2.impl, fpdev.git2;

procedure Test_DiscoverRepository_Fallback;
var
  LMgr: IGitManager;
  LTmpDir, LNested, LGitDir: string;
  LFound: string;
begin
  WriteLn('== Test_DiscoverRepository_Fallback ==');
  LTmpDir := GetCurrentDir; // 使用当前目录向上查找
  // 创建一个临时 .git 目录（不进行真实初始化），验证纯Pascal回退能找到
  LNested := IncludeTrailingPathDelimiter(LTmpDir) + 'tests_tmp_git2';
  ForceDirectories(LNested);
  LGitDir := IncludeTrailingPathDelimiter(LNested) + '.git';
  ForceDirectories(LGitDir);
  try
    LMgr := NewGitManager;
    // 不调用 Initialize，避免依赖 git2.dll；回退实现不需要 libgit2
    LFound := LMgr.DiscoverRepository(LNested);
    if LFound = '' then
      WriteLn('✗ 未能发现仓库目录 (fallback 失败)')
    else
      WriteLn('✓ 发现仓库目录: ', LFound);
  finally
    // 清理
    {$IFDEF MSWINDOWS}
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', LNested]);
    {$ELSE}
    ExecuteProcess('rm', ['-rf', LNested]);
    {$ENDIF}
  end;
end;

procedure Test_OID_Helpers;
var
  LOID: TGitOID;
  LHex: string;
begin
  WriteLn('== Test_OID_Helpers ==');
  // 40位0串
  LOID := CreateGitOIDFromString('0000000000000000000000000000000000000000');
  if not IsGitOIDZero(LOID) then
    WriteLn('✗ IsGitOIDZero 断言失败')
  else
    WriteLn('✓ IsGitOIDZero OK');
  LHex := GitOIDToString(LOID);
  if LHex <> '0000000000000000000000000000000000000000' then
    WriteLn('✗ GitOIDToString 断言失败: ', LHex)
  else
    WriteLn('✓ GitOIDToString OK');
end;

begin
  try
    Test_DiscoverRepository_Fallback;
    Test_OID_Helpers;
    WriteLn('== 完成 ==');
  except
    on E: Exception do
    begin
      WriteLn('测试异常: ', E.Message);
      Halt(1);
    end;
  end;
end.

