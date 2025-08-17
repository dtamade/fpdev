unit libgit2;

{$codepage utf8}
{$mode objfpc}{$H+}
{$PACKRECORDS C}

interface

uses
  SysUtils, ctypes;

const
  {$IFDEF MSWINDOWS}
  LIBGIT2_LIB = 'git2.dll';
  {$ENDIF}
  {$IFDEF LINUX}
  LIBGIT2_LIB = 'libgit2.so.1';
  {$ENDIF}
  {$IFDEF DARWIN}
  LIBGIT2_LIB = 'libgit2.1.dylib';
  {$ENDIF}

type
  // 基本类型定义
  csize_t = culong;
  git_time_t = cint64;
  git_off_t = cint64;

  // 前向声明
  git_repository = Pointer;
  git_remote = Pointer;
  git_reference = Pointer;
  git_object = Pointer;
  git_commit = Pointer;
  git_tree = Pointer;
  git_blob = Pointer;
  git_tag = Pointer;
  git_index = Pointer;
  git_config = Pointer;
  git_signature = Pointer;
  git_diff = Pointer;
  git_status_list = Pointer;
  git_branch_iterator = Pointer;
  git_revwalk = Pointer;

  // Git OID (Object ID)
  git_oid = record
    id: array[0..19] of Byte;
  end;
  Pgit_oid = ^git_oid;

  // Git时间结构
  git_time = record
    time: git_time_t;
    offset: cint;
    sign: cchar;
  end;
  Pgit_time = ^git_time;

  // Git签名结构
  git_signature_t = record
    name: PChar;
    email: PChar;
    when: git_time;
  end;
  Pgit_signature_t = ^git_signature_t;

  // 错误处理
  git_error_t = record
    message: PChar;
    klass: cint;
  end;
  Pgit_error_t = ^git_error_t;

  // 回调函数类型
  git_progress_cb = function(const str: PChar; len: csize_t; payload: Pointer): cint; cdecl;
  // 按 libgit2 定义，checkout 进度回调为 void（procedure）
  git_checkout_progress_cb = procedure(const path: PChar; completed_steps, total_steps: csize_t; payload: Pointer); cdecl;

  // 克隆进度结构
  git_indexer_progress = record
    total_objects: cuint;
    indexed_objects: cuint;
    received_objects: cuint;
    local_objects: cuint;
    total_deltas: cuint;
    indexed_deltas: cuint;
    received_bytes: csize_t;
  end;
  Pgit_indexer_progress = ^git_indexer_progress;

  // 额外回调类型（与网络/克隆相关）
  git_credential_acquire_cb = function(out cred: Pointer; const url, username_from_url: PChar; allowed_types: cuint; payload: Pointer): cint; cdecl;
  git_transport_certificate_check_cb = function(cert: Pointer; valid: cint; const host: PChar; payload: Pointer): cint; cdecl;
  git_transfer_progress_cb = function(const stats: Pgit_indexer_progress; payload: Pointer): cint; cdecl;

  git_indexer_progress_cb = function(const stats: Pgit_indexer_progress; payload: Pointer): cint; cdecl;

  // 远程/拉取/检出/克隆选项（最小子集）
  git_remote_callbacks = record
    version: cuint;
    progress: Pointer;
    completion: Pointer;
    credentials: git_credential_acquire_cb;
    certificate_check: git_transport_certificate_check_cb;
    transfer_progress: git_transfer_progress_cb;
  end;

  git_fetch_options = record
    version: cuint;
    callbacks: git_remote_callbacks;
  end;

  git_checkout_options = record
    version: cuint;
    checkout_strategy: cuint;
    progress_cb: git_checkout_progress_cb;
  end;

  git_clone_options = record
    version: cuint;
    checkout_opts: git_checkout_options;
    fetch_opts: git_fetch_options;
  end;

  // 状态标志
  git_status_t = cuint;
  git_status_opt_t = cuint;

  // 分支类型
  git_branch_t = (
    GIT_BRANCH_LOCAL = 1,
    GIT_BRANCH_REMOTE = 2,
    GIT_BRANCH_ALL = 3
  );

  // 对象类型
  git_object_t = (
    GIT_OBJECT_ANY = -2,
    GIT_OBJECT_INVALID = -1,
    GIT_OBJECT_COMMIT = 1,
    GIT_OBJECT_TREE = 2,
    GIT_OBJECT_BLOB = 3,
    GIT_OBJECT_TAG = 4,
    GIT_OBJECT_OFS_DELTA = 6,
    GIT_OBJECT_REF_DELTA = 7
  );

  // 引用类型
  git_reference_t = (
    GIT_REFERENCE_INVALID = 0,
    GIT_REFERENCE_DIRECT = 1,
    GIT_REFERENCE_SYMBOLIC = 2,
    GIT_REFERENCE_ALL = 3
  );

// 常量定义
const
  // 错误代码
  GIT_OK = 0;
  GIT_ERROR = -1;
  GIT_ENOTFOUND = -3;
  GIT_EEXISTS = -4;
  GIT_EAMBIGUOUS = -5;
  GIT_EBUFS = -6;
  GIT_EUSER = -7;
  GIT_EBAREREPO = -8;
  GIT_EUNBORNBRANCH = -9;
  GIT_EUNMERGED = -10;
  GIT_ENONFASTFORWARD = -11;
  GIT_EINVALIDSPEC = -12;
  GIT_ECONFLICT = -13;
  GIT_ELOCKED = -14;
  GIT_EMODIFIED = -15;
  GIT_EAUTH = -16;
  GIT_ECERTIFICATE = -17;
  GIT_EAPPLIED = -18;
  GIT_EPEEL = -19;
  GIT_EEOF = -20;
  GIT_EINVALID = -21;
  GIT_EUNCOMMITTED = -22;
  GIT_EDIRECTORY = -23;
  GIT_EMERGECONFLICT = -24;
  GIT_PASSTHROUGH = -30;
  GIT_ITEROVER = -31;
  GIT_RETRY = -32;
  GIT_EMISMATCH = -33;
  GIT_EINDEXDIRTY = -34;
  GIT_EAPPLYFAIL = -35;

  // 状态标志
  GIT_STATUS_CURRENT = 0;
  GIT_STATUS_INDEX_NEW = 1 shl 0;
  GIT_STATUS_INDEX_MODIFIED = 1 shl 1;
  GIT_STATUS_INDEX_DELETED = 1 shl 2;
  GIT_STATUS_INDEX_RENAMED = 1 shl 3;
  GIT_STATUS_INDEX_TYPECHANGE = 1 shl 4;
  GIT_STATUS_WT_NEW = 1 shl 7;
  GIT_STATUS_WT_MODIFIED = 1 shl 8;
  GIT_STATUS_WT_DELETED = 1 shl 9;
  GIT_STATUS_WT_TYPECHANGE = 1 shl 10;
  GIT_STATUS_WT_RENAMED = 1 shl 11;
  GIT_STATUS_WT_UNREADABLE = 1 shl 12;
  GIT_STATUS_IGNORED = 1 shl 14;
  GIT_STATUS_CONFLICTED = 1 shl 15;

// 基本库函数
function git_libgit2_init: cint; cdecl; external LIBGIT2_LIB;
function git_libgit2_shutdown: cint; cdecl; external LIBGIT2_LIB;
function git_libgit2_version(major, minor, rev: Pcint): cint; cdecl; external LIBGIT2_LIB;

// 仓库操作
function git_repository_open(out repo: git_repository; const path: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_repository_init(out repo: git_repository; const path: PChar; is_bare: cuint): cint; cdecl; external LIBGIT2_LIB;
function git_repository_discover(out out_path: PChar; path_size: csize_t; const start_path: PChar; across_fs: cint; const ceiling_dirs: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_repository_head(out head_ref: git_reference; repo: git_repository): cint; cdecl; external LIBGIT2_LIB;
function git_repository_is_bare(repo: git_repository): cint; cdecl; external LIBGIT2_LIB;
function git_repository_is_empty(repo: git_repository): cint; cdecl; external LIBGIT2_LIB;
function git_repository_path(repo: git_repository): PChar; cdecl; external LIBGIT2_LIB;
function git_repository_workdir(repo: git_repository): PChar; cdecl; external LIBGIT2_LIB;
function git_repository_set_head(repo: git_repository; const refname: PChar): cint; cdecl; external LIBGIT2_LIB;
procedure git_repository_free(repo: git_repository); cdecl; external LIBGIT2_LIB;

// 克隆操作
function git_clone(out repo: git_repository; const url: PChar; const local_path: PChar; const options: git_clone_options): cint; cdecl; external LIBGIT2_LIB;

// 远程操作
function git_remote_lookup(out remote: git_remote; repo: git_repository; const name: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_remote_fetch(remote: git_remote; const refspecs: Pointer; const opts: Pointer; const reflog_message: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_remote_url(remote: git_remote): PChar; cdecl; external LIBGIT2_LIB;
function git_remote_name(remote: git_remote): PChar; cdecl; external LIBGIT2_LIB;
procedure git_remote_free(remote: git_remote); cdecl; external LIBGIT2_LIB;

// 引用操作
function git_reference_lookup(out reference: git_reference; repo: git_repository; const name: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_reference_name(ref: git_reference): PChar; cdecl; external LIBGIT2_LIB;
function git_reference_target(ref: git_reference): Pgit_oid; cdecl; external LIBGIT2_LIB;
function git_reference_symbolic_target(ref: git_reference): PChar; cdecl; external LIBGIT2_LIB;
function git_reference_type(ref: git_reference): git_reference_t; cdecl; external LIBGIT2_LIB;
procedure git_reference_free(ref: git_reference); cdecl; external LIBGIT2_LIB;

// 分支操作
function git_branch_create(out ref_out: git_reference; repo: git_repository; const branch_name: PChar; target: git_commit; force: cint): cint; cdecl; external LIBGIT2_LIB;
function git_branch_delete(branch: git_reference): cint; cdecl; external LIBGIT2_LIB;
function git_branch_iterator_new(out iter: git_branch_iterator; repo: git_repository; list_flags: git_branch_t): cint; cdecl; external LIBGIT2_LIB;
function git_branch_next(out ref_out: git_reference; out branch_type: git_branch_t; iter: git_branch_iterator): cint; cdecl; external LIBGIT2_LIB;
procedure git_branch_iterator_free(iter: git_branch_iterator); cdecl; external LIBGIT2_LIB;

// 对象操作
function git_object_lookup(out obj: git_object; repo: git_repository; const id: Pgit_oid; obj_type: git_object_t): cint; cdecl; external LIBGIT2_LIB;
function git_object_id(obj: git_object): Pgit_oid; cdecl; external LIBGIT2_LIB;
function git_object_type(obj: git_object): git_object_t; cdecl; external LIBGIT2_LIB;
procedure git_object_free(obj: git_object); cdecl; external LIBGIT2_LIB;

// 提交操作
function git_commit_lookup(out commit: git_commit; repo: git_repository; const id: Pgit_oid): cint; cdecl; external LIBGIT2_LIB;
function git_commit_message(commit: git_commit): PChar; cdecl; external LIBGIT2_LIB;
function git_commit_author(commit: git_commit): Pgit_signature_t; cdecl; external LIBGIT2_LIB;
function git_commit_committer(commit: git_commit): Pgit_signature_t; cdecl; external LIBGIT2_LIB;
function git_commit_time(commit: git_commit): git_time_t; cdecl; external LIBGIT2_LIB;
function git_commit_parentcount(commit: git_commit): cuint; cdecl; external LIBGIT2_LIB;

// OID操作
function git_oid_fromstr(out id: git_oid; const str: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_oid_tostr(out str: PChar; size: csize_t; const id: Pgit_oid): PChar; cdecl; external LIBGIT2_LIB;
function git_oid_fmt(out str: PChar; const id: Pgit_oid): cint; cdecl; external LIBGIT2_LIB;
function git_oid_cmp(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl; external LIBGIT2_LIB;
function git_oid_equal(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl; external LIBGIT2_LIB;
function git_oid_iszero(const id: Pgit_oid): cint; cdecl; external LIBGIT2_LIB;

// 错误处理
function git_error_last: Pgit_error_t; cdecl; external LIBGIT2_LIB;
procedure git_error_clear; cdecl; external LIBGIT2_LIB;
function git_error_set_str(error_class: cint; const str: PChar): cint; cdecl; external LIBGIT2_LIB;

// 状态操作
function git_status_list_new(out status_list: git_status_list; repo: git_repository; const opts: Pointer): cint; cdecl; external LIBGIT2_LIB;
function git_status_list_entrycount(status_list: git_status_list): csize_t; cdecl; external LIBGIT2_LIB;

  // 遍历状态（无结构体，使用回调避免布局问题）
  type
    git_status_cb = function(const path: PChar; status_flags: cuint; payload: Pointer): cint; cdecl;
  function git_status_foreach(repo: git_repository; cb: git_status_cb; payload: Pointer): cint; cdecl; external LIBGIT2_LIB;



// Checkout flags（按位）最小集合
const
  GIT_CHECKOUT_NONE              = $00000000;
  GIT_CHECKOUT_SAFE              = $00000001; // 默认安全
  GIT_CHECKOUT_FORCE             = $00000002; // 强制覆盖
  GIT_CHECKOUT_RECREATE_MISSING  = $00000200;


procedure git_status_list_free(status_list: git_status_list); cdecl; external LIBGIT2_LIB;

// 索引操作
function git_repository_index(out index: git_index; repo: git_repository): cint; cdecl; external LIBGIT2_LIB;
function git_index_add_bypath(index: git_index; const path: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_index_write(index: git_index): cint; cdecl; external LIBGIT2_LIB;

  // Checkout 操作
  function git_checkout_head(repo: git_repository; const opts: git_checkout_options): cint; cdecl; external LIBGIT2_LIB;
  function git_checkout_tree(repo: git_repository; tree: git_object; const opts: git_checkout_options): cint; cdecl; external LIBGIT2_LIB;

procedure git_index_free(index: git_index); cdecl; external LIBGIT2_LIB;

// 配置操作
function git_config_open_default(out cfg: git_config): cint; cdecl; external LIBGIT2_LIB;
function git_config_get_string(out out_value: PChar; cfg: git_config; const name: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_config_set_string(cfg: git_config; const name: PChar; const value: PChar): cint; cdecl; external LIBGIT2_LIB;
procedure git_config_free(cfg: git_config); cdecl; external LIBGIT2_LIB;

// 选项初始化函数（使用 Pointer 以避免跨单元类型耦合）
function git_remote_init_callbacks(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB;
function git_fetch_options_init(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB;
function git_clone_options_init(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB;
function git_checkout_options_init(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB;

// 凭据创建（最小集）
function git_credential_default_new(out cred: Pointer): cint; cdecl; external LIBGIT2_LIB;
function git_credential_userpass_plaintext_new(out cred: Pointer; const username, password: PChar): cint; cdecl; external LIBGIT2_LIB;

// 签名操作
function git_signature_new(out sig: git_signature; const name: PChar; const email: PChar; time: git_time_t; offset: cint): cint; cdecl; external LIBGIT2_LIB;
function git_signature_now(out sig: git_signature; const name: PChar; const email: PChar): cint; cdecl; external LIBGIT2_LIB;
procedure git_signature_free(sig: git_signature); cdecl; external LIBGIT2_LIB;

implementation

end.
