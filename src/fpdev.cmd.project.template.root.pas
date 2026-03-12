unit fpdev.cmd.project.template.root;

{$mode objfpc}{$H+}

{ B243: Register 'project template' command path for template subcommands }

interface

uses
  fpdev.command.registry,
  fpdev.command.rootshell;

implementation

initialization
  GlobalCommandRegistry.RegisterSingletonPath(['project', 'template'], CreateNamespaceRootShellCommand(['project', 'template']), []);

end.
