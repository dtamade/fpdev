unit fpdev.cmd.package.repo.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry;

implementation

initialization
  GlobalCommandRegistry.RegisterPath(['package','repo'], nil, []);

end.
