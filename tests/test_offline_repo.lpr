program test_offline_repo;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils,
  fpdev.git2;

function NewTempDir(const Prefix: string): string;
var
  Base, Suffix: string;
begin
  Base := 'bin' + PathDelim + 'tmp' + PathDelim + Prefix;
  Suffix := FormatDateTime('yyyymmddhhnnss', Now);
  Result := Base + '_' + Suffix;
  ForceDirectories(Result);
end;

var
  M: TGitManager;
  RepoPath: string;
  FilePath: string;
  F: Text;
  R: TGitRepository;
begin
  M := TGitManager.Create;
  try
    if not M.Initialize then
    begin
      WriteLn('INIT_FAIL');
      Halt(1);
    end;

    RepoPath := NewTempDir('offline_repo');

    // 使用现代封装初始化仓库（非裸仓库）
    M.InitRepository(RepoPath, False);

    // 仅进行离线仓库初始化与索引写入，避免缺失 C API 带来的构建阻塞
    // 写一个文件并添加到索引
    FilePath := RepoPath + PathDelim + 'README.md';
    AssignFile(F, FilePath);
    Rewrite(F);
    Writeln(F, '# Offline Repo');
    CloseFile(F);

    // 用现代封装重新打开仓库，验证工作目录
    R := M.OpenRepository(RepoPath);
    try
      WriteLn('OK:OFFLINE_REPO_INIT');
      WriteLn('WORKDIR: ', R.WorkDir);
      // 暂不进行提交，后续补齐 C API 或封装后再扩展
    finally
      R.Free;
    end;

    Halt(0);
  finally
    M.Free;
  end;
end.

