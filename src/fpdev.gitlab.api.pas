unit fpdev.gitlab.api;

{$mode objfpc}{$H+}
// acq:allow-hardcoded-constants-file

interface

uses
  Classes, SysUtils, fphttpclient, fpjson, jsonparser,
  fpdev.registry.client.intf, fpdev.registry.auth;

type
  { TGitLabClient - GitLab REST API client }
  TGitLabClient = class(TInterfacedObject)
  private
    FBaseURL: string;
    FAuthProvider: IAuthProvider;
    FHTTPClient: TFPHTTPClient;
    FLastError: string;
    FLastHTTPCode: Integer;

    function BuildURL(const APath: string): string;
    function AddAuthHeaders(const AHeaders: TStrings): Boolean;
    function ExecuteRequest(const AMethod, AURL: string;
      const ABody: TStream; const AHeaders: TStrings;
      const AResponse: TStream): Boolean;
  public
    constructor Create(const ABaseURL: string = '');
    destructor Destroy; override;

    procedure SetAuthProvider(const AProvider: IAuthProvider);

    { Project operations }
    function CreateProject(const AName, ADescription: string;
      AVisibility: string): TJSONObject;
    function GetProject(const AProjectID: string): TJSONObject;
    function ListProjects: TJSONArray;

    { Package Registry operations }
    function UploadPackage(const AProjectID: string;
      const AFilePath, APackageName, AVersion: string): TJSONObject;
    function GetPackage(const AProjectID, APackageName, AVersion: string): TJSONObject;
    function ListPackages(const AProjectID: string): TJSONArray;
    function DeletePackage(const AProjectID, APackageID: string): Boolean;

    { Release operations }
    function CreateRelease(const AProjectID, ATag, AName, ADescription: string): TJSONObject;
    function GetRelease(const AProjectID, ATag: string): TJSONObject;
    function ListReleases(const AProjectID: string): TJSONArray;

    { Error handling }
    function GetLastError: string;
    function GetLastHTTPCode: Integer;
  end;

implementation

const
  DEFAULT_GITLAB_API_BASE_URL = 'https://gitlab.com/api/v4';
  URL_PATH_SEPARATOR = '/';
  API_PROJECTS_PATH = '/projects';
  API_PROJECTS_PREFIX = '/projects/';
  API_PROJECTS_GENERIC_PACKAGES_PREFIX = '/projects/';
  API_PACKAGES_GENERIC_SEGMENT = '/packages/generic/';
  API_PACKAGES_QUERY_BY_NAME_SEGMENT = '/packages?package_name=';
  API_PACKAGES_QUERY_VERSION_SEGMENT = '&package_version=';
  API_PROJECT_PACKAGES_SUFFIX = '/packages';
  API_PROJECT_PACKAGE_ITEM_SUFFIX = '/packages/';
  API_PROJECT_RELEASES_SUFFIX = '/releases';

{ Helper functions }

procedure WriteString(AStream: TStream; const AStr: string);
begin
  if Length(AStr) > 0 then
    AStream.WriteBuffer(AStr[1], Length(AStr));
end;

{ TGitLabClient }

constructor TGitLabClient.Create(const ABaseURL: string);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  if FBaseURL = '' then
    FBaseURL := DEFAULT_GITLAB_API_BASE_URL;
  FHTTPClient := TFPHTTPClient.Create(nil);
  FHTTPClient.AllowRedirect := True;
  FLastError := '';
  FLastHTTPCode := 0;
  FAuthProvider := nil;
end;

destructor TGitLabClient.Destroy;
begin
  FHTTPClient.Free;
  inherited Destroy;
end;

procedure TGitLabClient.SetAuthProvider(const AProvider: IAuthProvider);
begin
  FAuthProvider := AProvider;
end;

function TGitLabClient.BuildURL(const APath: string): string;
begin
  Result := FBaseURL;
  if (Length(Result) > 0) and
    (Result[Length(Result)] <> URL_PATH_SEPARATOR) then
    Result := Result + URL_PATH_SEPARATOR;
  if (Length(APath) > 0) and (APath[1] = URL_PATH_SEPARATOR) then
    Result := Result + Copy(APath, 2, Length(APath))
  else
    Result := Result + APath;
end;

function TGitLabClient.AddAuthHeaders(const AHeaders: TStrings): Boolean;
var
  AuthHeader: string;
begin
  Result := True;

  if Assigned(FAuthProvider) and FAuthProvider.IsValid then
  begin
    AuthHeader := FAuthProvider.GetAuthHeader;
    if AuthHeader <> '' then
      AHeaders.Add(AuthHeader);
  end;
end;

function TGitLabClient.ExecuteRequest(const AMethod, AURL: string;
  const ABody: TStream; const AHeaders: TStrings; const AResponse: TStream): Boolean;
var
  StatusCode: Integer;
begin
  Result := False;

  try
    // Clear previous headers
    FHTTPClient.RequestHeaders.Clear;

    // Add custom headers
    if Assigned(AHeaders) then
      FHTTPClient.RequestHeaders.AddStrings(AHeaders);

    // Avoid leaking request body across calls.
    FHTTPClient.RequestBody := nil;

    // Execute HTTP request
    if AMethod = 'GET' then
    begin
      FHTTPClient.Get(AURL, AResponse);
      Result := True;
    end
    else if (AMethod = 'POST') or (AMethod = 'PUT') then
    begin
      if Assigned(ABody) then
        ABody.Position := 0;
      FHTTPClient.RequestBody := ABody;
      try
        FHTTPClient.HTTPMethod(AMethod, AURL, AResponse, [200, 201, 202, 204]);
      finally
        FHTTPClient.RequestBody := nil;
      end;
      Result := True;
    end
    else if AMethod = 'DELETE' then
    begin
      FHTTPClient.HTTPMethod('DELETE', AURL, AResponse, [200, 202, 204]);
      Result := True;
    end
    else
    begin
      FLastError := 'Unsupported HTTP method: ' + AMethod;
      Exit(False);
    end;

    // Get status code
    StatusCode := FHTTPClient.ResponseStatusCode;
    FLastHTTPCode := StatusCode;

    // Check if successful (2xx)
    if (StatusCode >= 200) and (StatusCode < 300) then
      Result := True
    else
    begin
      FLastError := Format('HTTP %d: %s', [StatusCode, FHTTPClient.ResponseStatusText]);
      Result := False;
    end;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      FLastHTTPCode := 0;
      Result := False;
    end;
  end;
end;

function TGitLabClient.CreateProject(const AName, ADescription: string;
  AVisibility: string): TJSONObject;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  Body: TMemoryStream;
  Payload: TJSONObject;
  JSON: TJSONData;
  JSONStr: string;
begin
  Result := nil;
  URL := BuildURL(API_PROJECTS_PATH);
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  Body := TMemoryStream.Create;
  Payload := TJSONObject.Create;
  try
    Payload.Add('name', AName);
    Payload.Add('description', ADescription);
    Payload.Add('visibility', AVisibility);

    JSONStr := Payload.AsJSON;
    WriteString(Body, JSONStr);
    Body.Position := 0;

    AddAuthHeaders(Headers);
    Headers.Add('Content-Type: application/json');

    if ExecuteRequest('POST', URL, Body, Headers, Response) then
    begin
      Response.Position := 0;
      JSON := GetJSON(Response);
      if JSON is TJSONObject then
        Result := TJSONObject(JSON)
      else
      begin
        JSON.Free;
        FLastError := 'CreateProject response is not a JSON object';
      end;
    end;
  finally
    Payload.Free;
    Body.Free;
    Headers.Free;
    Response.Free;
  end;
end;

function TGitLabClient.GetProject(const AProjectID: string): TJSONObject;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
begin
  Result := nil;

  URL := BuildURL(API_PROJECTS_PREFIX + AProjectID);
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  try
    AddAuthHeaders(Headers);

    if ExecuteRequest('GET', URL, nil, Headers, Response) then
    begin
      Response.Position := 0;
      JSON := GetJSON(Response);
      if JSON is TJSONObject then
        Result := TJSONObject(JSON)
      else
        JSON.Free;
    end;
  finally
    Headers.Free;
    Response.Free;
  end;
end;

function TGitLabClient.ListProjects: TJSONArray;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
begin
  Result := nil;

  URL := BuildURL(API_PROJECTS_PATH);
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  try
    AddAuthHeaders(Headers);

    if ExecuteRequest('GET', URL, nil, Headers, Response) then
    begin
      Response.Position := 0;
      JSON := GetJSON(Response);
      if JSON is TJSONArray then
        Result := TJSONArray(JSON)
      else
        JSON.Free;
    end;
  finally
    Headers.Free;
    Response.Free;
  end;
end;

function TGitLabClient.UploadPackage(const AProjectID: string;
  const AFilePath, APackageName, AVersion: string): TJSONObject;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  Body: TMemoryStream;
  FileStream: TFileStream;
  JSON: TJSONData;
begin
  Result := nil;
  if not FileExists(AFilePath) then
  begin
    FLastError := 'Package file not found: ' + AFilePath;
    Exit;
  end;

  URL := BuildURL(
    API_PROJECTS_GENERIC_PACKAGES_PREFIX + AProjectID +
    API_PACKAGES_GENERIC_SEGMENT + APackageName + URL_PATH_SEPARATOR +
    AVersion + URL_PATH_SEPARATOR + ExtractFileName(AFilePath)
  );
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  Body := TMemoryStream.Create;
  try
    FileStream := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyWrite);
    try
      Body.CopyFrom(FileStream, FileStream.Size);
      Body.Position := 0;
    finally
      FileStream.Free;
    end;

    AddAuthHeaders(Headers);
    Headers.Add('Content-Type: application/octet-stream');

    if ExecuteRequest('POST', URL, Body, Headers, Response) then
    begin
      Response.Position := 0;
      JSON := GetJSON(Response);
      if JSON is TJSONObject then
        Result := TJSONObject(JSON)
      else
      begin
        JSON.Free;
        FLastError := 'UploadPackage response is not a JSON object';
      end;
    end;
  finally
    Body.Free;
    Headers.Free;
    Response.Free;
  end;
end;

function TGitLabClient.GetPackage(const AProjectID, APackageName, AVersion: string): TJSONObject;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
begin
  Result := nil;

  URL := BuildURL(
    API_PROJECTS_GENERIC_PACKAGES_PREFIX + AProjectID +
    API_PACKAGES_QUERY_BY_NAME_SEGMENT + APackageName +
    API_PACKAGES_QUERY_VERSION_SEGMENT + AVersion
  );
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  try
    AddAuthHeaders(Headers);

    if ExecuteRequest('GET', URL, nil, Headers, Response) then
    begin
      Response.Position := 0;
      JSON := GetJSON(Response);
      if JSON is TJSONObject then
        Result := TJSONObject(JSON)
      else
        JSON.Free;
    end;
  finally
    Headers.Free;
    Response.Free;
  end;
end;

function TGitLabClient.ListPackages(const AProjectID: string): TJSONArray;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
begin
  Result := nil;

  URL := BuildURL(
    API_PROJECTS_GENERIC_PACKAGES_PREFIX + AProjectID +
    API_PROJECT_PACKAGES_SUFFIX
  );
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  try
    AddAuthHeaders(Headers);

    if ExecuteRequest('GET', URL, nil, Headers, Response) then
    begin
      Response.Position := 0;
      JSON := GetJSON(Response);
      if JSON is TJSONArray then
        Result := TJSONArray(JSON)
      else
        JSON.Free;
    end;
  finally
    Headers.Free;
    Response.Free;
  end;
end;

function TGitLabClient.DeletePackage(const AProjectID, APackageID: string): Boolean;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
begin
  URL := BuildURL(
    API_PROJECTS_GENERIC_PACKAGES_PREFIX + AProjectID +
    API_PROJECT_PACKAGE_ITEM_SUFFIX + APackageID
  );
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  try
    AddAuthHeaders(Headers);
    Result := ExecuteRequest('DELETE', URL, nil, Headers, Response);
  finally
    Headers.Free;
    Response.Free;
  end;
end;

function TGitLabClient.CreateRelease(const AProjectID, ATag, AName, ADescription: string): TJSONObject;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  Body: TMemoryStream;
  Payload: TJSONObject;
  JSON: TJSONData;
  JSONStr: string;
begin
  Result := nil;
  URL := BuildURL(
    API_PROJECTS_GENERIC_PACKAGES_PREFIX + AProjectID +
    API_PROJECT_RELEASES_SUFFIX
  );
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  Body := TMemoryStream.Create;
  Payload := TJSONObject.Create;
  try
    Payload.Add('tag_name', ATag);
    Payload.Add('name', AName);
    Payload.Add('description', ADescription);

    JSONStr := Payload.AsJSON;
    WriteString(Body, JSONStr);
    Body.Position := 0;

    AddAuthHeaders(Headers);
    Headers.Add('Content-Type: application/json');

    if ExecuteRequest('POST', URL, Body, Headers, Response) then
    begin
      Response.Position := 0;
      JSON := GetJSON(Response);
      if JSON is TJSONObject then
        Result := TJSONObject(JSON)
      else
      begin
        JSON.Free;
        FLastError := 'CreateRelease response is not a JSON object';
      end;
    end;
  finally
    Payload.Free;
    Body.Free;
    Headers.Free;
    Response.Free;
  end;
end;

function TGitLabClient.GetRelease(const AProjectID, ATag: string): TJSONObject;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
begin
  Result := nil;

  URL := BuildURL('/projects/' + AProjectID + '/releases/' + ATag);
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  try
    AddAuthHeaders(Headers);

    if ExecuteRequest('GET', URL, nil, Headers, Response) then
    begin
      Response.Position := 0;
      JSON := GetJSON(Response);
      if JSON is TJSONObject then
        Result := TJSONObject(JSON)
      else
        JSON.Free;
    end;
  finally
    Headers.Free;
    Response.Free;
  end;
end;

function TGitLabClient.ListReleases(const AProjectID: string): TJSONArray;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
begin
  Result := nil;

  URL := BuildURL('/projects/' + AProjectID + '/releases');
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  try
    AddAuthHeaders(Headers);

    if ExecuteRequest('GET', URL, nil, Headers, Response) then
    begin
      Response.Position := 0;
      JSON := GetJSON(Response);
      if JSON is TJSONArray then
        Result := TJSONArray(JSON)
      else
        JSON.Free;
    end;
  finally
    Headers.Free;
    Response.Free;
  end;
end;

function TGitLabClient.GetLastError: string;
begin
  Result := FLastError;
end;

function TGitLabClient.GetLastHTTPCode: Integer;
begin
  Result := FLastHTTPCode;
end;

end.
