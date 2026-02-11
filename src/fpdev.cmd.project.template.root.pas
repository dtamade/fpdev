unit fpdev.cmd.project.template.root;

{$mode objfpc}{$H+}

{ B243: Register 'project template' command path for template subcommands }

interface

uses
  fpdev.command.registry;

implementation

initialization
  GlobalCommandRegistry.RegisterPath(['project','template'], nil, ['tpl']);

end.
