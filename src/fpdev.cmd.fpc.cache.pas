unit fpdev.cmd.fpc.cache;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry;

implementation

initialization
  // Register fpc cache root node (for auto-help)
  GlobalCommandRegistry.RegisterPath(['fpc', 'cache'], nil, []);

end.
