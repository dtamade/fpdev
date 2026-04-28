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
    Search := TPackageSearchCommand.Create(GetDataRoot + PathDelim + 'registry');
    Results := Search.Search('json');
    for I := 0 to Results.Count - 1 do
      WriteLn(Results[I]);
*)

interface

uses
  SysUtils, Classes, fpjson,
  fpdev.command.intf, fpdev.package.registry;

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

uses
  fpdev.command.registry,
  fpdev.package.manager,
  fpdev.package.searchcommandflow,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.paths;

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
  LSearch: TPackageSearchCommand;
  LPlan: TPackageSearchCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PreparePackageSearchCommandPlanCore(
    AParams,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  LMgr := TPackageManager.Create(Ctx.Config);
  LSearch := TPackageSearchCommand.Create(
    IncludeTrailingPathDelimiter(GetDataRoot) + 'registry');
  try
    Result := ExecutePackageSearchCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.SearchPackages,
      @LSearch.Search
    );
  finally
    LSearch.Free;
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','search'], @PackageSearchFactory, []);

end.
