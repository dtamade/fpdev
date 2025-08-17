unit fpdev.cmd.fpc.root2;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry;

implementation

initialization
  // 注册 fpc 根节点（用于自动帮助）
  GlobalCommandRegistry.RegisterPath(['fpc'], nil, []);

end.

