unit fpdev.cmd.project.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry;

implementation

initialization
  GlobalCommandRegistry.RegisterPath(['project'], nil, ['proj']);

end.
