unit fpdev.cmd.cross.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry,
  fpdev.command.rootshell;

implementation

initialization
  GlobalCommandRegistry.RegisterSingletonPath(['cross'], CreateNamespaceRootShellCommand(['cross']), []);

end.
