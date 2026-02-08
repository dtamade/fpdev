unit fpdev.cmd.fpc.registry;

{$mode objfpc}{$H+}

{
  FPC command root node registration - backward compatibility wrapper.

  Note: The actual registration is now done in fpdev.cmd.fpc.root.pas
  This unit is kept for backward compatibility only.
}

interface

uses
  fpdev.cmd.fpc.root; // actual registration happens here

implementation

end.
