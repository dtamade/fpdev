unit fpdev.cmd.repo.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry,
  fpdev.command.rootshell;

implementation

initialization
  GlobalCommandRegistry.RegisterSingletonPath(['system', 'repo'], CreateNamespaceRootShellCommand(['system', 'repo']), []);

end.




