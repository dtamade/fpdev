unit fpdev.git.types;

{$mode objfpc}{$H+}

interface

type
  TGitBackend = (gbLibgit2, gbCommandLine, gbNone);

function GitBackendToString(ABackend: TGitBackend): string;

implementation

function GitBackendToString(ABackend: TGitBackend): string;
begin
  case ABackend of
    gbLibgit2: Result := 'libgit2';
    gbCommandLine: Result := 'git (command-line)';
    gbNone: Result := 'none';
  end;
end;

end.
