unit fpdev.cmd.fpc.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry;

implementation

initialization
  // Register fpc root node (for auto-help)
  GlobalCommandRegistry.RegisterPath(['fpc'], nil, []);

end.

