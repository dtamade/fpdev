unit fpdev.cmd.repo.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry;

implementation

initialization
  // Root node, only for mounting subcommands
  GlobalCommandRegistry.RegisterPath(['repo'], nil, []);

end.




