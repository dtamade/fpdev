unit fpdev.cmd.package.search;

{$mode objfpc}{$H+}

(*
  Package Search Command

  Provides functionality for searching and discovering packages in a registry:
  - Search packages by name or description
  - List all available packages
  - Display package information
  - Case-insensitive search
  - Partial match support

  Usage:
    Search := TPackageSearchCommand.Create('~/.fpdev/registry');
    Results := Search.Search('json');
    for I := 0 to Results.Count - 1 do
      WriteLn(Results[I]);
*)

interface

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager,
  fpdev.i18n, fpdev.i18n.strings, fpdev.package.registry, fpdev.exitcodes;

type
  { TPackageSearchCommand - Functional class for package search }
  TPackageSearchCommand = class
  private
    FRegistryPath: string;
    FRegistry: TPackageRegistry;
    FLastError: string;

    function MatchesQuery(const APackageName, ADescription: string; const AQuery: string): Boolean;
    function FormatPackageInfo(const AName: string; const AMetadata: TJSONObject): string;

  public
    constructor Create(const ARegistryPath: string);
    destructor Destroy; override;

    { Search packages by query (name or description) }
    function Search(const AQuery: string): TStringList;

    { List all packages }
    function ListAll: TStringList;

    { Get package information }
    function GetInfo(const AName: string): string;

    { Get last error message }
    function GetLastError: string;

    property RegistryPath: string read FRegistryPath;
  end;

  { TPackageSearchCmd - Command interface implementation }
  TPackageSearchCmd = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

{ TPackageSearchCommand }

constructor TPackageSearchCommand.Create(const ARegistryPath: string);
begin
  inherited Create;
  FRegistryPath := ExpandFileName(ARegistryPath);
  FRegistry := TPackageRegistry.Create(FRegistryPath);
  FLastError := '';
end;

destructor TPackageSearchCommand.Destroy;
begin
  FRegistry.Free;
  inherited Destroy;
end;

function TPackageSearchCommand.MatchesQuery(const APackageName, ADescription: string; const AQuery: string): Boolean;
var
  LowerQuery, LowerName, LowerDesc: string;
begin
  Result := False;

  // Empty query matches everything
  if AQuery = '' then
  begin
    Result := True;
    Exit;
  end;

  // Case-insensitive comparison
  LowerQuery := LowerCase(AQuery);
  LowerName := LowerCase(APackageName);
  LowerDesc := LowerCase(ADescription);

  // Check if query matches package name or description (partial match)
  Result := (Pos(LowerQuery, LowerName) > 0) or (Pos(LowerQuery, LowerDesc) > 0);
end;

function TPackageSearchCommand.FormatPackageInfo(const AName: string; const AMetadata: TJSONObject): string;
var
  Versions: TStringList;
  I: Integer;
  Description, Author: string;
  VersionsText: string;
begin
  Result := '';

  if AMetadata = nil then
    Exit;

  // Get description and author from metadata
  Description := AMetadata.Get('description', '');
  Author := AMetadata.Get('author', '');

  // Get all versions
  Versions := FRegistry.GetPackageVersions(AName);
  try
    VersionsText := _(CMD_PKG_SEARCH_INFO_NONE);

    if Versions.Count > 0 then
    begin
      VersionsText := '';
      for I := 0 to Versions.Count - 1 do
      begin
        VersionsText := VersionsText + Versions[I];
        if I < Versions.Count - 1 then
          VersionsText := VersionsText + ', ';
      end;
    end;

    Result := _Fmt(CMD_PKG_SEARCH_INFO_PACKAGE, [AName]) + LineEnding;
    Result := Result + _Fmt(CMD_PKG_SEARCH_INFO_DESCRIPTION, [Description]) + LineEnding;
    Result := Result + _Fmt(CMD_PKG_SEARCH_INFO_AUTHOR, [Author]) + LineEnding;
    Result := Result + _Fmt(CMD_PKG_SEARCH_INFO_VERSIONS, [VersionsText]) + LineEnding;
  finally
    Versions.Free;
  end;
end;

function TPackageSearchCommand.Search(const AQuery: string): TStringList;
var
  AllPackages: TStringList;
  I: Integer;
  PackageName: string;
  Metadata: TJSONObject;
  Description: string;
begin
  Result := TStringList.Create;
  FLastError := '';

  // Initialize registry
  if not FRegistry.Initialize then
  begin
    FLastError := _Fmt(CMD_PKG_SEARCH_INIT_FAILED, [FRegistry.GetLastError]);
    Exit;
  end;

  // Get all packages
  AllPackages := FRegistry.ListPackages;
  try
    for I := 0 to AllPackages.Count - 1 do
    begin
      PackageName := AllPackages[I];

      // Get package metadata
      Metadata := FRegistry.GetPackageMetadata(PackageName);
      if Metadata <> nil then
      begin
        try
          Description := Metadata.Get('description', '');

          // Check if package matches query
          if MatchesQuery(PackageName, Description, AQuery) then
            Result.Add(PackageName);
        finally
          Metadata.Free;
        end;
      end;
    end;
  finally
    AllPackages.Free;
  end;
end;

function TPackageSearchCommand.ListAll: TStringList;
begin
  // List all is just search with empty query
  Result := Search('');
end;

function TPackageSearchCommand.GetInfo(const AName: string): string;
var
  Metadata: TJSONObject;
begin
  Result := '';
  FLastError := '';

  // Initialize registry
  if not FRegistry.Initialize then
  begin
    FLastError := _Fmt(CMD_PKG_SEARCH_INIT_FAILED, [FRegistry.GetLastError]);
    Exit;
  end;

  // Check if package exists
  if not FRegistry.HasPackage(AName) then
  begin
    FLastError := _Fmt(CMD_PKG_NOT_FOUND, [AName]);
    Exit;
  end;

  // Get package metadata
  Metadata := FRegistry.GetPackageMetadata(AName);
  if Metadata = nil then
  begin
    FLastError := _Fmt(CMD_PKG_SEARCH_META_FAILED, [FRegistry.GetLastError]);
    Exit;
  end;

  try
    Result := FormatPackageInfo(AName, Metadata);
  finally
    Metadata.Free;
  end;
end;

function TPackageSearchCommand.GetLastError: string;
begin
  Result := FLastError;
end;

{ TPackageSearchCmd }

function TPackageSearchCmd.Name: string; begin Result := 'search'; end;
function TPackageSearchCmd.Aliases: TStringArray; begin Result := nil; end;
function TPackageSearchCmd.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageSearchFactory: ICommand;
begin
  Result := TPackageSearchCmd.Create;
end;

function TPackageSearchCmd.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  Q: string;
  Arg: string;
  LJsonOutput: Boolean;
  LSearch: TPackageSearchCommand;
  LResults: TStringList;
  LJson: TJSONObject;
  LArr: TJSONArray;
  UnknownOption: string;
  I: Integer;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_SEARCH_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_SEARCH_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_SEARCH_EXAMPLE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_SEARCH_OPT_JSON));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_SEARCH_OPT_HELP));
    Exit(EXIT_OK);
  end;

  LJsonOutput := HasFlag(AParams, 'json');
  if FindUnknownOption(AParams, ['--json'], UnknownOption) then
  begin
    Ctx.Err.WriteLn(_(HELP_PACKAGE_SEARCH_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  // Get query (first non-flag argument)
  Q := '';
  for I := 0 to High(AParams) do
    if (AParams[I] <> '') and (AParams[I][1] <> '-') then
    begin
      Arg := Trim(AParams[I]);
      if Arg <> '' then
      begin
        Q := Arg;
        Break;
      end;
    end;

  if Q = '' then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['query']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_SEARCH_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if LJsonOutput then
  begin
    // JSON output mode using TPackageSearchCommand
    LSearch := TPackageSearchCommand.Create(ExpandFileName('~/.fpdev/registry'));
    try
      LResults := LSearch.Search(Q);
      try
        LJson := TJSONObject.Create;
        try
          LArr := TJSONArray.Create;
          for I := 0 to LResults.Count - 1 do
            LArr.Add(LResults[I]);
          LJson.Add('query', Q);
          LJson.Add('results', LArr);
          LJson.Add('count', LResults.Count);
          Ctx.Out.WriteLn(LJson.FormatJSON);
        finally
          LJson.Free;
        end;
      finally
        LResults.Free;
      end;
    finally
      LSearch.Free;
    end;
    Exit(EXIT_OK);
  end
  else
  begin
    // Normal text output
    LMgr := TPackageManager.Create(Ctx.Config);
    try
      if LMgr.SearchPackages(Q, Ctx.Out) then
        Exit(EXIT_OK);
      Result := EXIT_ERROR;
    finally
      LMgr.Free;
    end;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','search'], @PackageSearchFactory, []);

end.
