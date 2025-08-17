program fpdev_git2_status_test;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.git2, git2.impl, git2.api;

procedure Test_Status_Offline;
var
  LTmp, LGit, LFile: string;
  LRepo: TGitRepository;
  LMgr: IGitManager;
  LArr: TStringArray;
  LHasDll: Boolean;
begin
  WriteLn('== Test_Status_Offline ==');
  // 尝试加载 libgit2 初始化；若失败则跳过
  LHasDll := False;
  try
    LMgr := NewGitManager;
    if LMgr.Initialize then LHasDll := True;
  except
    LHasDll := False;
  end;
  if not LHasDll then
  begin
    WriteLn('! 跳过：未找到 libgit2（Initialize 失败）');
    Exit;
  end
  else
    WriteLn('✓ 检测到 libgit2，可运行状态测试');

  // 初始化一个空目录并调用 InitRepository
  LTmp := GetCurrentDir + PathDelim + 'tmp_status_' + FormatDateTime('yyyymmddhhnnss', Now);
  ForceDirectories(LTmp);
  try
    LRepo := GitManager.InitRepository(LTmp, False);
    try
      // 创建未跟踪文件
      LFile := LTmp + PathDelim + 'a.txt';
      with TStringList.Create do
      try
        Text := 'hello';
        SaveToFile(LFile);
      finally
        Free;
      end;
      // 查询状态（应包含 a.txt）
      LArr := LRepo.Status;
      if Length(LArr) > 0 then
      begin
        WriteLn('✓ Status 非空，检测到变更数: ', Length(LArr));
        for var i:=0 to High(LArr) do
          WriteLn('  - ', LArr[i]);
      end
      else
      begin
        WriteLn('✗ Status 为空（预期应检测到变更）');
        Halt(2);
      end;
    finally
      LRepo.Free;
    end;
  finally
    {$IFDEF MSWINDOWS}
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', LTmp]);
    {$ELSE}
    ExecuteProcess('rm', ['-rf', LTmp]);
    {$ENDIF}
  end;
end;

begin
  try
    Test_Status_Offline;
  except
    on E: Exception do begin
      WriteLn('测试异常: ', E.Message);
      Halt(1);
    end;
  end;
end.

