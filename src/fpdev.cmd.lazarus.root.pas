unit fpdev.cmd.lazarus.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry;

implementation

initialization
  // Register lazarus root node (for auto-help listing subcommands)
  GlobalCommandRegistry.RegisterPath(['lazarus'], nil, []);

end.

