unit fpdev.cmd.lazarus.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry;

implementation

initialization
  // 注册 lazarus 根节点（用于自动帮助列出子命令）
  GlobalCommandRegistry.RegisterPath(['lazarus'], nil, []);

end.

