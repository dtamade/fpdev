unit fpdev.constants;

{$mode objfpc}{$H+}

interface

const
  // FPC相关常量
  DEFAULT_FPC_REPO = 'https://gitlab.com/freepascal.org/fpc/source.git';
  DEFAULT_FPC_VERSION = '3.2.2';
  FALLBACK_FPC_VERSION = '3.2.0';
  
  // 路径相关常量
  FPDEV_CONFIG_DIR = '.fpdev';
  PATH_SEPARATOR = {$IFDEF WINDOWS}''{$ELSE}'/'{$ENDIF};
  
  // 命令行参数
  CMD_SWITCH_CLEAN = '/c';
  CMD_SWITCH_SILENT = '/s';
  
  // 日志相关
  LOG_TIMESTAMP_FORMAT = 'yyyy-mm-dd hh:nn:ss.zzz';

implementation

end.
