program fpdev_git2_status_test;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.git2;

procedure Test_Status_Offline;
var
  LTmp, LFile: string;
  LMgr: TGitManager;
  LRepo: TGitRepository;
  LArr: TStringArray;
  LHasDll: Boolean;
  i: Integer;
begin
  WriteLn('== Test_Status_Offline ==');
  LTmp := GetCurrentDir + PathDelim + 'tmp_status_' + FormatDateTime('yyyymmddhhnnss', Now);
  ForceDirectories(LTmp);
  LMgr := TGitManager.Create;
  try
    LHasDll := False;
    try
      LHasDll := LMgr.Initialize;
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

    LRepo := nil;
    LRepo := LMgr.InitRepository(LTmp, False);
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
        for i := 0 to High(LArr) do
          WriteLn('  - ', LArr[i]);
      end
      else
      begin
        WriteLn('✗ Status 为空（预期应检测到变更）');
        Halt(2);
      end;
    finally
      if Assigned(LRepo) then
        LRepo.Free;
    end;
  finally
    LMgr.Free;
    {$IFDEF MSWINDOWS}
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', LTmp]);
    {$ELSE}
    ExecuteProcess('/bin/rm', ['-rf', LTmp]);
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
