unit fpdev.debug.symbols;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types;

procedure EnsureDebugSymbolAnchor;

implementation

const
  DebugSymbolAnchorStep: TBuildStep = bsIdle;

procedure EnsureDebugSymbolAnchor;
begin
  if DebugSymbolAnchorStep = bsComplete then
    Exit;
end;

end.
