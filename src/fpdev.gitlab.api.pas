unit fpdev.gitlab.api;

{$mode objfpc}{$H+}

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
    FBaseURL := 'https://gitlab.com/api/v4';
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
  if (Length(Result) > 0) and (Result[Length(Result)] <> '/') then
    Result := Result + '/';
  if (Length(APath) > 0) and (APath[1] = '/') then
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
    
    // Execute HTTP request
    if AMethod = 'GET' then
    begin
      FHTTPClient.Get(AURL, AResponse);
      Result := True;
    end
    else if (AMethod = 'POST') or (AMethod = 'PUT') or (AMethod = 'DELETE') then
    begin
      // GitLab API POST/PUT/DELETE not yet implemented
      // Requires custom HTTP client or different approach
      FLastError := 'HTTP ' + AMethod + ' not yet implemented - requires custom HTTP client';
      Exit(False);
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
begin
  Result := nil;
  FLastError := 'CreateProject not yet implemented - requires HTTP POST support';
end;

function TGitLabClient.GetProject(const AProjectID: string): TJSONObject;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
begin
  Result := nil;
  
  URL := BuildURL('/projects/' + AProjectID);
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
  
  URL := BuildURL('/projects');
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
begin
  Result := nil;
  FLastError := 'UploadPackage not yet implemented - requires HTTP POST support';
end;

function TGitLabClient.GetPackage(const AProjectID, APackageName, AVersion: string): TJSONObject;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
begin
  Result := nil;
  
  URL := BuildURL('/projects/' + AProjectID + '/packages?package_name=' + APackageName + '&package_version=' + AVersion);
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
  
  URL := BuildURL('/projects/' + AProjectID + '/packages');
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
begin
  Result := False;
  FLastError := 'DeletePackage not yet implemented - requires HTTP DELETE support';
end;

function TGitLabClient.CreateRelease(const AProjectID, ATag, AName, ADescription: string): TJSONObject;
begin
  Result := nil;
  FLastError := 'CreateRelease not yet implemented - requires HTTP POST support';
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
