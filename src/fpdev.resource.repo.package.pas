unit fpdev.resource.repo.package;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function ResourceRepoResolvePackageMetaPath(const ALocalPath, AName: string): string;

implementation

function ResourceRepoResolvePackageMetaPath(const ALocalPath, AName: string): string;
var
  CandidatePath: string;
begin
  Result := '';

  CandidatePath := ALocalPath + PathDelim + 'packages' + PathDelim + AName +
    PathDelim + AName + '.json';
  if FileExists(CandidatePath) then
  begin
    Result := CandidatePath;
    Exit;
  end;

  CandidatePath := ALocalPath + PathDelim + 'packages' + PathDelim + 'core' +
    PathDelim + AName + PathDelim + AName + '.json';
  if FileExists(CandidatePath) then
  begin
    Result := CandidatePath;
    Exit;
  end;

  CandidatePath := ALocalPath + PathDelim + 'packages' + PathDelim + 'ui' +
    PathDelim + AName + PathDelim + AName + '.json';
  if FileExists(CandidatePath) then
  begin
    Result := CandidatePath;
    Exit;
  end;

  CandidatePath := ALocalPath + PathDelim + 'packages' + PathDelim + 'utils' +
    PathDelim + AName + PathDelim + AName + '.json';
  if FileExists(CandidatePath) then
  begin
    Result := CandidatePath;
    Exit;
  end;
end;

end.
