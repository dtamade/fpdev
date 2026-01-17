unit fpdev.cmd.repo.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry;

implementation

initialization
  // 根节点，仅用于挂载子命令
  GlobalCommandRegistry.RegisterPath(['repo'], nil, []);

end.




