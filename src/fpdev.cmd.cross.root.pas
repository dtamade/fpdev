unit fpdev.cmd.cross.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry;

implementation

initialization
  GlobalCommandRegistry.RegisterPath(['cross'], nil, ['x']);

end.
