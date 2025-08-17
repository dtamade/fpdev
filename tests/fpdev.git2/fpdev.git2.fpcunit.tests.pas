unit fpdev.git2.fpcunit.tests;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpcunit, testregistry,
  git2.types, git2.api, git2.impl, fpdev.git2;

type
  { TTestCase_Global }
  TTestCase_Global = class(TTestCase)
  published
    procedure Test_DiscoverRepository_Fallback;
  end;

  { TTestCase_Git2Status }
  TTestCase_Git2Status = class(TTestCase)
  private
    function Libgit2Available: Boolean;
  published
    procedure Test_StatusEntries_Untracked_Filtered;
  end;

implementation

procedure TTestCase_Global.Test_DiscoverRepository_Fallback;
var
  LMgr: IGitManager;
  LTmp, LGitDir, LFound: string;
begin
  LTmp := GetCurrentDir + PathDelim + 'tmp_discover_' + FormatDateTime('yyyymmddhhnnss', Now);
  ForceDirectories(LTmp);
  LGitDir := IncludeTrailingPathDelimiter(LTmp) + '.git';
  ForceDirectories(LGitDir);
  try
    LMgr := NewGitManager; // 不依赖 Initialize，即走回退实现
    LFound := LMgr.DiscoverRepository(LTmp);
    AssertTrue('Discover 应返回临时仓库根', (LFound <> '') and (ExtractFileName(TrimRight(LFound, ['\','/'])) = ExtractFileName(LTmp)));
  finally
    {$IFDEF MSWINDOWS}
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', LTmp]);
    {$ELSE}
    ExecuteProcess('rm', ['-rf', LTmp]);
    {$ENDIF}
  end;
end;

function TTestCase_Git2Status.Libgit2Available: Boolean;
var
  LMgr: IGitManager;
begin
  Result := False;
  try
    LMgr := NewGitManager;
    Result := LMgr.Initialize;
  except
    Result := False;
  end;
end;

procedure TTestCase_Git2Status.Test_StatusEntries_Untracked_Filtered;
var
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LDir, LFileUntracked: string;
  LFilter: TGitStatusFilter;
  LEntries: array of TGitStatusEntry;
  LFound: Boolean;
  i: Integer;
begin
  if not Libgit2Available then
  begin
    AssertTrue('libgit2 不可用，跳过', True);
    Exit;
  end;
  LMgr := NewGitManager;
  LDir := GetCurrentDir + PathDelim + 'tmp_status_unit_' + FormatDateTime('yyyymmddhhnnss', Now);
  ForceDirectories(LDir);
  try
    LRepo := LMgr.InitRepository(LDir, False);
    LFileUntracked := LDir + PathDelim + 'u.txt';
    with TStringList.Create do
    try
      Text := 'hello';
      SaveToFile(LFileUntracked);
    finally
      Free;
    end;
    FillByte(LFilter, SizeOf(LFilter), 0);
    LFilter.WorkingTreeOnly := True;
    LFilter.IncludeUntracked := True;
    LEntries := LRepo.StatusEntries(LFilter);
    LFound := False;
    for i := 0 to High(LEntries) do
      if SameText(ExtractFileName(LEntries[i].Path), 'u.txt') then
        LFound := True;
    AssertTrue('应包含未跟踪文件', LFound);

    // 关闭未跟踪包含，应排除
    LFilter.IncludeUntracked := False;
    LEntries := LRepo.StatusEntries(LFilter);
    LFound := False;
    for i := 0 to High(LEntries) do
      if SameText(ExtractFileName(LEntries[i].Path), 'u.txt') then
        LFound := True;
    AssertTrue('不应包含未跟踪文件（过滤生效）', not LFound);
  finally
    {$IFDEF MSWINDOWS}
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', LDir]);
    {$ELSE}
    ExecuteProcess('rm', ['-rf', LDir]);
    {$ENDIF}
  end;
end;

initialization
  RegisterTest(TTestCase_Global);
  RegisterTest(TTestCase_Git2Status);

end.

