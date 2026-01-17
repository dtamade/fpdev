unit fpdev.constants;

{$mode objfpc}{$H+}

{
  Central Constants Definition

  This module is the SINGLE SOURCE OF TRUTH for all shared constants.
  Other modules should import from here instead of defining their own.
}

interface

uses
  SysUtils;

const
  // ============================================================
  // Official Repository URLs (SINGLE SOURCE OF TRUTH)
  // ============================================================

  // FPC Official Git Repository
  FPC_OFFICIAL_REPO = 'https://gitlab.com/freepascal.org/fpc/source.git';
  DEFAULT_FPC_REPO = FPC_OFFICIAL_REPO;  // Alias for backward compatibility

  // Lazarus Official Git Repository
  LAZARUS_OFFICIAL_REPO = 'https://gitlab.com/freepascal.org/lazarus/lazarus.git';
  DEFAULT_LAZARUS_REPO = LAZARUS_OFFICIAL_REPO;  // Alias for backward compatibility

  // FPDev Resource Repository - Multi-Repository Architecture v2.0
  // Main index repository (entry point)
  FPDEV_INDEX_GITHUB = 'https://github.com/dtamade/fpdev-index.git';
  FPDEV_INDEX_GITEE = 'https://gitee.com/dtamade/fpdev-index.git';

  // Sub-repositories (referenced from index.json)
  FPDEV_BOOTSTRAP_GITHUB = 'https://github.com/dtamade/fpdev-bootstrap.git';
  FPDEV_BOOTSTRAP_GITEE = 'https://gitee.com/dtamade/fpdev-bootstrap.git';
  FPDEV_FPC_GITHUB = 'https://github.com/dtamade/fpdev-fpc.git';
  FPDEV_FPC_GITEE = 'https://gitee.com/dtamade/fpdev-fpc.git';
  FPDEV_LAZARUS_GITHUB = 'https://github.com/dtamade/fpdev-lazarus.git';
  FPDEV_LAZARUS_GITEE = 'https://gitee.com/dtamade/fpdev-lazarus.git';
  FPDEV_CROSS_GITHUB = 'https://github.com/dtamade/fpdev-cross.git';
  FPDEV_CROSS_GITEE = 'https://gitee.com/dtamade/fpdev-cross.git';

  // Default URLs (GitHub as primary, Gitee as mirror)
  FPDEV_REPO_URL = FPDEV_INDEX_GITHUB;
  FPDEV_REPO_MIRROR = FPDEV_INDEX_GITEE;

  // Legacy aliases for backward compatibility
  FPDEV_REPO_GITHUB = FPDEV_INDEX_GITHUB;
  FPDEV_REPO_GITEE = FPDEV_INDEX_GITEE;

  // ============================================================
  // Version Constants
  // ============================================================
  DEFAULT_FPC_VERSION = '3.2.2';
  FALLBACK_FPC_VERSION = '3.2.0';
  DEFAULT_LAZARUS_VERSION = '3.6';

  // ============================================================
  // Path Constants
  // ============================================================
  FPDEV_CONFIG_DIR = '.fpdev';
  PATH_SEPARATOR = PathDelim;

  // ============================================================
  // Command Line Switches
  // ============================================================
  CMD_SWITCH_CLEAN = '/c';
  CMD_SWITCH_SILENT = '/s';

  // ============================================================
  // Logging
  // ============================================================
  LOG_TIMESTAMP_FORMAT = 'yyyy-mm-dd hh:nn:ss.zzz';

implementation

end.
