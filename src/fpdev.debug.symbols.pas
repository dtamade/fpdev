unit fpdev.debug.symbols;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types;

procedure EnsureDebugSymbolAnchor;

implementation

const
  // Keep the build-cache types unit in the CLI link graph without reintroducing
  // an inline anchor in fpdev.lpr or triggering unused-unit hints.
  DEBUG_SYMBOL_ANCHOR_STEP: TBuildStep = bsIdle;

procedure EnsureDebugSymbolAnchor;
begin
  if DEBUG_SYMBOL_ANCHOR_STEP = bsComplete then
    Exit;
end;

end.
