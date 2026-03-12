unit fpdev.help.details.system;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.output.intf;

procedure WriteSystemEnvHelpCore(const Ctx: IContext);
procedure WriteSystemPerfHelpCore(const Outp: IOutput);
procedure WriteSystemConfigHelpCore(const Ctx: IContext);
procedure WriteSystemIndexHelpCore(const Ctx: IContext);
procedure WriteSystemCacheHelpCore(const Ctx: IContext);

implementation

procedure WriteSystemEnvHelpCore(const Ctx: IContext);
begin
  Ctx.Out.WriteLn('Usage: fpdev system env [command]');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Show development environment information.');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Commands:');
  Ctx.Out.WriteLn('  (none)      Show environment overview');
  Ctx.Out.WriteLn('  vars        Show FPC/Lazarus environment variables');
  Ctx.Out.WriteLn('  path        Show PATH configuration');
  Ctx.Out.WriteLn('  export      Export environment as shell script');
  Ctx.Out.WriteLn('  hook        Generate shell integration hook');
  Ctx.Out.WriteLn('  help        Show this help');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Options for export:');
  Ctx.Out.WriteLn('  --shell <sh|bash|cmd|ps>   Shell type (default: auto-detect)');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Examples:');
  Ctx.Out.WriteLn('  fpdev system env');
  Ctx.Out.WriteLn('  fpdev system env vars');
  Ctx.Out.WriteLn('  fpdev system env export --shell bash');
  Ctx.Out.WriteLn('  fpdev system env hook bash');
end;

procedure WriteSystemPerfHelpCore(const Outp: IOutput);
begin
  Outp.WriteLn('fpdev system perf - Performance Monitoring');
  Outp.WriteLn('');
  Outp.WriteLn('Usage:');
  Outp.WriteLn('  fpdev system perf report   - Show JSON performance report');
  Outp.WriteLn('  fpdev system perf summary  - Show human-readable summary');
  Outp.WriteLn('  fpdev system perf clear    - Clear all performance data');
  Outp.WriteLn('  fpdev system perf save <file> - Save report to JSON file');
  Outp.WriteLn('');
  Outp.WriteLn('Performance data is collected during build operations.');
end;

procedure WriteSystemConfigHelpCore(const Ctx: IContext);
begin
  Ctx.Out.WriteLn('Usage: fpdev system config <command> [options]');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Commands:');
  Ctx.Out.WriteLn('  show                    Show current configuration');
  Ctx.Out.WriteLn('  get <key>               Get a configuration value');
  Ctx.Out.WriteLn('  set <key> <value>       Set a configuration value');
  Ctx.Out.WriteLn('  export <file>           Export configuration to file');
  Ctx.Out.WriteLn('  import <file>           Import configuration from file');
  Ctx.Out.WriteLn('  list                    List installed FPC and Lazarus toolchains');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Configuration keys:');
  Ctx.Out.WriteLn('  mirror                  Mirror source: auto, github, gitee, or custom URL');
  Ctx.Out.WriteLn('  custom_repo_url         Custom repository URL (overrides mirror)');
  Ctx.Out.WriteLn('  parallel_jobs           Number of parallel build jobs');
  Ctx.Out.WriteLn('  auto_update             Enable auto-update: true/false');
  Ctx.Out.WriteLn('  keep_sources            Keep source files: true/false');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Examples:');
  Ctx.Out.WriteLn('  fpdev system config show');
  Ctx.Out.WriteLn('  fpdev system config set mirror gitee');
  Ctx.Out.WriteLn('  fpdev system config set mirror github');
  Ctx.Out.WriteLn('  fpdev system config set custom_repo_url https://my-server.com/fpdev-repo.git');
  Ctx.Out.WriteLn('  fpdev system config get mirror');
  Ctx.Out.WriteLn('  fpdev system config export ~/fpdev-backup.json');
  Ctx.Out.WriteLn('  fpdev system config import ~/fpdev-backup.json');
end;

procedure WriteSystemIndexHelpCore(const Ctx: IContext);
begin
  Ctx.Out.WriteLn('Usage: fpdev system index <command>');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Manage fpdev resource index.');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Commands:');
  Ctx.Out.WriteLn('  status    Show index status');
  Ctx.Out.WriteLn('  show      Show index details (repositories, channels)');
  Ctx.Out.WriteLn('  update    Force update index from remote');
  Ctx.Out.WriteLn('  help      Show this help');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Examples:');
  Ctx.Out.WriteLn('  fpdev system index status');
  Ctx.Out.WriteLn('  fpdev system index show');
  Ctx.Out.WriteLn('  fpdev system index update');
end;

procedure WriteSystemCacheHelpCore(const Ctx: IContext);
begin
  Ctx.Out.WriteLn('Usage: fpdev system cache <command>');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Manage fpdev caches.');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Commands:');
  Ctx.Out.WriteLn('  status    Show overall cache status');
  Ctx.Out.WriteLn('  stats     Show detailed cache statistics');
  Ctx.Out.WriteLn('  path      Show cache directory paths');
  Ctx.Out.WriteLn('  help      Show this help');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('For FPC-specific cache management, use:');
  Ctx.Out.WriteLn('  fpdev fpc cache list');
  Ctx.Out.WriteLn('  fpdev fpc cache clean');
  Ctx.Out.WriteLn('  fpdev fpc cache stats');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Examples:');
  Ctx.Out.WriteLn('  fpdev system cache status');
  Ctx.Out.WriteLn('  fpdev system cache stats');
  Ctx.Out.WriteLn('  fpdev system cache path');
end;

end.
