unit fpdev.cmd.fpc.cache;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry,
  fpdev.command.rootshell;

implementation

initialization
  GlobalCommandRegistry.RegisterSingletonPath(['fpc', 'cache'], CreateNamespaceRootShellCommand(['fpc', 'cache']), []);

end.
