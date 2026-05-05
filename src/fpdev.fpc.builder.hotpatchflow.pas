unit fpdev.fpc.builder.hotpatchflow;

{
================================================================================
  fpdev.fpc.builder.hotpatchflow - FPC source hotpatch procedures
================================================================================

  Standalone procedures for applying build-time hotpatches to FPC source
  trees before compilation.

  Extracted from TFPCSourceBuilder as part of the facade/flow refactoring.

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

{ Invalidates stale compiler message include files so they get regenerated. }
procedure FPCBuilderInvalidateCompilerMessageIncludesCore(const ASourceDir: string);

{ Applies the fcl-web JWT source path hotpatch for correct fpjwt.pp resolution. }
procedure FPCBuilderApplyFCLWebJWTSourcePathHotpatchCore(const ASourceDir: string);

implementation

uses
  SysUtils, Classes,
  fpdev.utils.fs;

procedure FPCBuilderInvalidateCompilerMessageIncludesCore(const ASourceDir: string);
var
  CompilerDir: string;
  MsgDir: string;
  MsgIdxPath: string;
  MsgTxtPath: string;
begin
  CompilerDir := IncludeTrailingPathDelimiter(ASourceDir) + 'compiler';
  MsgDir := CompilerDir + PathDelim + 'msg';
  if not DirectoryExists(MsgDir) then
    Exit;

  MsgIdxPath := CompilerDir + PathDelim + 'msgidx.inc';
  MsgTxtPath := CompilerDir + PathDelim + 'msgtxt.inc';

  if FileExists(MsgIdxPath) then
    DeleteFile(MsgIdxPath);
  if FileExists(MsgTxtPath) then
    DeleteFile(MsgTxtPath);
end;

procedure FPCBuilderApplyFCLWebJWTSourcePathHotpatchCore(const ASourceDir: string);
var
  FPMakePath: string;
  JWTSourceDir: string;
  JWTUnitPath: string;
  BaseJWTUnitPath: string;
  UnitsRoot: string;
  FPMakeLines: TStringList;
  Search: TSearchRec;
  UnitsSearch: TSearchRec;
  BaseIndex: Integer;
  JwtIndex: Integer;
  TargetIndex: Integer;
  BaseLine: string;
  JwtLine: string;
  UnitsDir: string;
begin
  JWTSourceDir := IncludeTrailingPathDelimiter(ASourceDir) + 'packages' + PathDelim +
    'fcl-web' + PathDelim + 'src' + PathDelim + 'jwt';
  if not DirectoryExists(JWTSourceDir) then
    Exit;
  JWTUnitPath := JWTSourceDir + PathDelim + 'fpjwt.pp';
  BaseJWTUnitPath := IncludeTrailingPathDelimiter(ASourceDir) + 'packages' + PathDelim +
    'fcl-web' + PathDelim + 'src' + PathDelim + 'base' + PathDelim + 'fpjwt.pp';

  FPMakePath := IncludeTrailingPathDelimiter(ASourceDir) + 'packages' + PathDelim +
    'fcl-web' + PathDelim + 'fpmake.pp';
  if FileExists(FPMakePath) then
  begin
    FPMakeLines := TStringList.Create;
    try
      FPMakeLines.LoadFromFile(FPMakePath);
      BaseIndex := FPMakeLines.IndexOf('    P.SourcePath.Add(''src/base'');');
      JwtIndex := FPMakeLines.IndexOf('    P.SourcePath.Add(''src/jwt'');');
      TargetIndex := FPMakeLines.IndexOf('    T:=P.Targets.AddUnit(''fpjwt.pp'');');
      if (BaseIndex >= 0) and (JwtIndex < 0) then
      begin
        FPMakeLines.Insert(BaseIndex, '    P.SourcePath.Add(''src/jwt'');');
        JwtIndex := BaseIndex;
        Inc(BaseIndex);
      end;
      if (BaseIndex >= 0) and (JwtIndex >= 0) and (BaseIndex < JwtIndex) then
      begin
        BaseLine := FPMakeLines[BaseIndex];
        JwtLine := FPMakeLines[JwtIndex];
        FPMakeLines[BaseIndex] := JwtLine;
        FPMakeLines[JwtIndex] := BaseLine;
      end;
      if TargetIndex >= 0 then
        FPMakeLines[TargetIndex] := '    T:=P.Targets.AddUnit(''src/jwt/fpjwt.pp'');';
      FPMakeLines.SaveToFile(FPMakePath);
    finally
      FPMakeLines.Free;
    end;
  end;

  if FileExists(JWTUnitPath) and FileExists(BaseJWTUnitPath) then
    CopyFileSafe(JWTUnitPath, BaseJWTUnitPath);

  UnitsRoot := IncludeTrailingPathDelimiter(ASourceDir) + 'packages' + PathDelim +
    'fcl-web' + PathDelim + 'units';
  if FindFirst(UnitsRoot + PathDelim + '*', faDirectory, Search) = 0 then
  begin
    repeat
      if (Search.Name <> '.') and (Search.Name <> '..') and
         ((Search.Attr and faDirectory) <> 0) then
      begin
        UnitsDir := UnitsRoot + PathDelim + Search.Name;
        if FindFirst(UnitsDir + PathDelim + 'fpjwt.*', faAnyFile, UnitsSearch) = 0 then
        begin
          repeat
            if (UnitsSearch.Name <> '.') and (UnitsSearch.Name <> '..') and
               ((UnitsSearch.Attr and faDirectory) = 0) then
              DeleteFile(UnitsDir + PathDelim + UnitsSearch.Name);
          until FindNext(UnitsSearch) <> 0;
          FindClose(UnitsSearch);
        end;
        if FileExists(UnitsDir + PathDelim + 'BuildUnit_fcl_web.pp') then
          DeleteFile(UnitsDir + PathDelim + 'BuildUnit_fcl_web.pp');
      end;
    until FindNext(Search) <> 0;
    FindClose(Search);
  end;
end;

end.
