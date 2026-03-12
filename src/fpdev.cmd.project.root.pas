unit fpdev.cmd.project.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry,
  fpdev.command.rootshell;

implementation

initialization
  GlobalCommandRegistry.RegisterSingletonPath(['project'], CreateNamespaceRootShellCommand(['project']), []);

end.
