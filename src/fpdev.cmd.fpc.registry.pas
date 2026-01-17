unit fpdev.cmd.fpc.registry;

{$mode objfpc}{$H+}

{
  FPC command root node registration.
  
  This module registers the 'fpc' root command node in the global command registry,
  enabling automatic help generation and subcommand discovery.
}

interface

uses
  fpdev.command.registry;

implementation

initialization
  // Register fpc root node for automatic help
  GlobalCommandRegistry.RegisterPath(['fpc'], nil, []);

end.
