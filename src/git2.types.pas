unit git2.types;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  // 高层抽象的分支类型，避免直接暴露 libgit2 的枚举
  TGitBranchKind = (
    gbLocal,
    gbRemote,
    gbAll
  );

  // 统一字符串数组类型（与现存模块保持一致）
  TStringArray = array of string;

  // 状态标志（高层抽象，避免直接暴露 libgit2 位掩码）
  TGitStatusFlag = (
    gsIndexNew,
    gsIndexModified,
    gsIndexDeleted,
    gsIndexRenamed,
    gsIndexTypeChange,
    gsWtNew,
    gsWtModified,
    gsWtDeleted,
    gsWtTypeChange,
    gsWtRenamed,
    gsIgnored,
    gsConflicted
  );
  TGitStatusFlags = set of TGitStatusFlag;

  // 单个状态项
  TGitStatusEntry = record
    Path: string;
    Flags: TGitStatusFlags;
  end;
  TGitStatusEntryArray = array of TGitStatusEntry;

  // 过滤选项
  TGitStatusFilter = record
    IncludeUntracked: Boolean;
    IncludeIgnored: Boolean;
    WorkingTreeOnly: Boolean;
    IndexOnly: Boolean;
  end;


implementation

end.

