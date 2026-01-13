unit fpdev.constants;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  // FPC related constants
  DEFAULT_FPC_REPO = 'https://gitlab.com/freepascal.org/fpc/source.git';
  FPC_OFFICIAL_REPO = DEFAULT_FPC_REPO;  // Alias
  DEFAULT_FPC_VERSION = '3.2.2';
  FALLBACK_FPC_VERSION = '3.2.0';

  // 路径相关常量
  FPDEV_CONFIG_DIR = '.fpdev';
  // 注意: 推荐直接使用 SysUtils.PathDelim 而非此常量
  PATH_SEPARATOR = PathDelim;

  // 命令行参数
  CMD_SWITCH_CLEAN = '/c';
  CMD_SWITCH_SILENT = '/s';

  // 日志相关
  LOG_TIMESTAMP_FORMAT = 'yyyy-mm-dd hh:nn:ss.zzz';

implementation

end.
