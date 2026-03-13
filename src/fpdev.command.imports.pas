unit fpdev.command.imports;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.imports.fpc,
  fpdev.command.imports.lazarus,
  fpdev.command.imports.cross,
  fpdev.command.imports.package,
  fpdev.command.imports.project,
  fpdev.command.imports.system;

procedure EnsureCommandImports;

implementation

procedure EnsureCommandImports;
begin
  EnsureFPCCommandImports;
  EnsureLazarusCommandImports;
  EnsureCrossCommandImports;
  EnsurePackageCommandImports;
  EnsureProjectCommandImports;
  EnsureSystemCommandImports;
end;

end.
