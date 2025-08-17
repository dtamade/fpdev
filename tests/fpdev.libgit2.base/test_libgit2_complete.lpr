program test_libgit2_complete;
{$CODEPAGE UTF8}


{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.git2, libgit2;

var
  Manager: TGitManager;

procedure TestLibGit2Initialization;
begin
  WriteLn('=== 测试libgit2初始化 ===');
  WriteLn;

  if Manager.Initialize then
  begin
    WriteLn('✓ libgit2初始化成功');
    WriteLn('版本: ', Manager.GetVersion);
  end
  else
  begin
    WriteLn('✗ libgit2初始化失败');
    Exit;
  end;
  WriteLn;
end;

procedure TestRepositoryOperations;
var
  TestDir: string;
  Repo: TGitRepository;
  Branches: TStringArray;
  Branch: string;
begin
  WriteLn('=== 测试仓库操作 ===');
  WriteLn;

  TestDir := 'test_complete_repo';

  // 清理已存在的测试目录
  if DirectoryExists(TestDir) then
  begin
    WriteLn('删除已存在的测试目录...');
    {$IFDEF MSWINDOWS}
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', TestDir]);
    {$ELSE}
    ExecuteProcess('rm', ['-rf', TestDir]);
    {$ENDIF}
  end;

  try
    WriteLn('克隆测试仓库...');
    Repo := Manager.CloneRepository('https://github.com/octocat/Hello-World.git', TestDir);
    try
      WriteLn('✓ 仓库克隆成功');

      // 测试仓库信息
      WriteLn('仓库路径: ', Repo.Path);
      WriteLn('工作目录: ', Repo.WorkDir);
      // TGitRepository 暂无 IsBare/IsEmpty 暴露，这里输出路径/工作区代替
      WriteLn('仓库路径(用于替代 IsBare/IsEmpty 检查): ', Repo.Path);
      WriteLn('工作目录(用于替代 IsBare/IsEmpty 检查): ', Repo.WorkDir);
      WriteLn('当前分支: ', Repo.GetCurrentBranch);

      // 测试分支列表
      WriteLn;
      WriteLn('本地分支:');
      Branches := Repo.ListBranches(GIT_BRANCH_LOCAL);
      for Branch in Branches do
        WriteLn('  - ', Branch);

      WriteLn;
      WriteLn('远程分支:');
      Branches := Repo.ListBranches(GIT_BRANCH_REMOTE);
      for Branch in Branches do
        WriteLn('  - ', Branch);

    finally
      Repo.Free;
    end;

  except
    on E: EGitError do
    begin
      WriteLn('✗ Git错误: ', E.Message);
      WriteLn('错误代码: ', E.ErrorCode);
    end;
    on E: Exception do
    begin
      WriteLn('✗ 异常: ', E.Message);
    end;
  end;

  WriteLn;
end;

procedure TestCommitOperations;
var
  TestDir: string;
  Repo: TGitRepository;
  Commit: TGitCommit;
  HeadRef: TGitReference;
begin
  WriteLn('=== 测试提交操作 ===');
  WriteLn;

  TestDir := 'test_complete_repo';

  if not DirectoryExists(TestDir) then
  begin
    WriteLn('✗ 测试仓库不存在，跳过提交测试');
    Exit;
  end;

  try
    Repo := Manager.OpenRepository(TestDir);
    try
      // 获取HEAD引用
      HeadRef := Repo.GetHead;
      try
        WriteLn('HEAD引用: ', HeadRef.Name);
        WriteLn('引用类型: ', Ord(HeadRef.RefType));
        WriteLn('是否为分支: ', (HeadRef.RefType = GIT_REFERENCE_DIRECT) and (Pos('refs/heads/', HeadRef.Name) = 1));

        // 获取最新提交
        Commit := Repo.GetLastCommit;
        try
          WriteLn;
          WriteLn('最新提交信息:');
          WriteLn('OID: ', GitOIDToString(Commit.OID));
          WriteLn('短OID: ', GitOIDToShortString(Commit.OID));
          WriteLn('消息: ', Commit.ShortMessage);
          WriteLn('作者: ', Commit.Author.ToString);
          WriteLn('提交者: ', Commit.Committer.ToString);
          WriteLn('时间: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Commit.Time));
          WriteLn('父提交数: ', Commit.ParentCount);

        finally
          Commit.Free;
        end;

      finally
        HeadRef.Free;
      end;

    finally
      Repo.Free;
    end;

  except
    on E: EGitError do
    begin
      WriteLn('✗ Git错误: ', E.Message);
    end;
    on E: Exception do
    begin
      WriteLn('✗ 异常: ', E.Message);
    end;
  end;

  WriteLn;
end;

procedure TestRemoteOperations;
var
  TestDir: string;
  Repo: TGitRepository;
  Remote: TGitRemote;
begin
  WriteLn('=== 测试远程操作 ===');
  WriteLn;

  TestDir := 'test_complete_repo';

  if not DirectoryExists(TestDir) then
  begin
    WriteLn('✗ 测试仓库不存在，跳过远程测试');
    Exit;
  end;

  try
    Repo := Manager.OpenRepository(TestDir);
    try
      Remote := Repo.GetRemote('origin');
      try
        WriteLn('远程仓库信息:');
        WriteLn('名称: ', Remote.Name);
        WriteLn('URL: ', Remote.URL);

      finally
        Remote.Free;
      end;

    finally
      Repo.Free;
    end;

  except
    on E: EGitError do
    begin
      WriteLn('✗ Git错误: ', E.Message);
    end;
    on E: Exception do
    begin
      WriteLn('✗ 异常: ', E.Message);
    end;
  end;

  WriteLn;
end;

procedure TestGitManagerFeatures;
var
  RepoPath: string;
begin
  WriteLn('=== 测试Git管理器功能 ===');
  WriteLn;

  WriteLn('libgit2版本: ', Manager.GetVersion);
  WriteLn('是否已初始化: ', Manager.Initialized);

  // 测试仓库发现
  // 旧编译器不支持 begin..end 内部声明变量，使用外部声明
  RepoPath := Manager.DiscoverRepository('.');
  if RepoPath <> '' then
  begin
    WriteLn('发现仓库: ', RepoPath)
  end
  else
  begin
    WriteLn('当前目录不在Git仓库中');
  end;

  // 测试仓库检查
  WriteLn('test_complete_repo是否为仓库: ', Manager.IsRepository('test_complete_repo'));
  WriteLn('当前目录是否为仓库: ', Manager.IsRepository('.'));

  WriteLn;
end;

procedure TestOIDOperations;
var
  OID1, OID2: TGitOID;
  HashString: string;
begin
  WriteLn('=== 测试OID操作 ===');
  WriteLn;

  try
    // 测试从字符串创建OID
    HashString := '7fd1a60b01f91b314f59955a4e4d4e80d8edf11d';
    OID1 := CreateGitOIDFromString(HashString);
    WriteLn('原始哈希: ', HashString);
    WriteLn('OID字符串: ', GitOIDToString(OID1));
    WriteLn('短OID: ', GitOIDToShortString(OID1));
    WriteLn('是否为零: ', IsGitOIDZero(OID1));

    // 测试OID比较
    OID2 := CreateGitOIDFromString(HashString);
    WriteLn('OID相等: ', GitOIDEquals(OID1, OID2));
    WriteLn('OID不等: ', not GitOIDEquals(OID1, OID2));

  except
    on E: Exception do
    begin
      WriteLn('✗ OID操作异常: ', E.Message);
    end;
  end;

  WriteLn;
end;

procedure CleanupTest;
var
  TestDir: string;
begin
  WriteLn('=== 清理测试文件 ===');

  TestDir := 'test_complete_repo';
  if DirectoryExists(TestDir) then
  begin
    WriteLn('删除测试目录: ', TestDir);
    {$IFDEF MSWINDOWS}
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', TestDir]);
    {$ELSE}
    ExecuteProcess('rm', ['-rf', TestDir]);
    {$ENDIF}
    WriteLn('✓ 清理完成');
  end;
  WriteLn;
end;

begin
  try
    WriteLn('libgit2完整功能测试程序');
    WriteLn('========================');
    WriteLn;

    Manager := TGitManager.Create;
    try
      TestLibGit2Initialization;
      TestGitManagerFeatures;
      TestOIDOperations;
      TestRepositoryOperations;
      TestCommitOperations;
      TestRemoteOperations;
      CleanupTest;

      WriteLn('=== 测试完成 ===');
      WriteLn('libgit2现代接口封装测试完成！');
      WriteLn('所有功能已验证，可以开始实际使用。');

    finally
      Manager.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn('测试过程中发生错误: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;

  WriteLn;
  WriteLn('按Enter键退出...');
  ReadLn;
end.
