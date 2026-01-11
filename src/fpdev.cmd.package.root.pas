unit fpdev.cmd.package.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry;

implementation

initialization
  GlobalCommandRegistry.RegisterPath(['package'], nil, ['pkg']);

end.
