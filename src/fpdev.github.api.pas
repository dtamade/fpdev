unit fpdev.github.api;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, fpjson, jsonparser,
  fpdev.registry.client.intf, fpdev.registry.auth;

type
  { TGitHubClient - GitHub REST API client }
  TGitHubClient = class(TInterfacedObject)
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
    
    { Repository operations }
    function CreateRepository(const AName, ADescription: string; 
      APrivate: Boolean): TJSONObject;
    
    { Release operations }
    function CreateRelease(const AOwner, ARepo, ATag, AName, ABody: string; 
      ADraft, APrerelease: Boolean): TJSONObject;
    function GetRelease(const AOwner, ARepo, ATag: string): TJSONObject;
    function ListReleases(const AOwner, ARepo: string): TJSONArray;
    
    { Asset operations }
    function UploadReleaseAsset(const AOwner, ARepo: string; 
      AReleaseID: Int64; const AFilePath, AContentType: string): TJSONObject;
    function DeleteReleaseAsset(const AOwner, ARepo: string; 
      AAssetID: Int64): Boolean;
    
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

{ TGitHubClient }

constructor TGitHubClient.Create(const ABaseURL: string);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  if FBaseURL = '' then
    FBaseURL := 'https://api.github.com';
  FHTTPClient := TFPHTTPClient.Create(nil);
  FHTTPClient.AllowRedirect := True;
  FHTTPClient.AddHeader('Accept', 'application/vnd.github+json');
  FHTTPClient.AddHeader('X-GitHub-Api-Version', '2022-11-28');
  FLastError := '';
  FLastHTTPCode := 0;
  FAuthProvider := nil;
end;

destructor TGitHubClient.Destroy;
begin
  FHTTPClient.Free;
  inherited Destroy;
end;

procedure TGitHubClient.SetAuthProvider(const AProvider: IAuthProvider);
begin
  FAuthProvider := AProvider;
end;

function TGitHubClient.BuildURL(const APath: string): string;
begin
  Result := FBaseURL;
  if (Length(Result) > 0) and (Result[Length(Result)] <> '/') then
    Result := Result + '/';
  if (Length(APath) > 0) and (APath[1] = '/') then
    Result := Result + Copy(APath, 2, Length(APath))
  else
    Result := Result + APath;
end;

function TGitHubClient.AddAuthHeaders(const AHeaders: TStrings): Boolean;
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

function TGitHubClient.ExecuteRequest(const AMethod, AURL: string;
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
      // GitHub API POST/PUT/DELETE not yet implemented
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

function TGitHubClient.CreateRepository(const AName, ADescription: string; 
  APrivate: Boolean): TJSONObject;
begin
  Result := nil;
  FLastError := 'CreateRepository not yet implemented - requires HTTP POST support';
end;

function TGitHubClient.CreateRelease(const AOwner, ARepo, ATag, AName, ABody: string; 
  ADraft, APrerelease: Boolean): TJSONObject;
begin
  Result := nil;
  FLastError := 'CreateRelease not yet implemented - requires HTTP POST support';
end;

function TGitHubClient.GetRelease(const AOwner, ARepo, ATag: string): TJSONObject;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
begin
  Result := nil;
  
  URL := BuildURL('/repos/' + AOwner + '/' + ARepo + '/releases/tags/' + ATag);
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

function TGitHubClient.ListReleases(const AOwner, ARepo: string): TJSONArray;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
begin
  Result := nil;
  
  URL := BuildURL('/repos/' + AOwner + '/' + ARepo + '/releases');
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

function TGitHubClient.UploadReleaseAsset(const AOwner, ARepo: string; 
  AReleaseID: Int64; const AFilePath, AContentType: string): TJSONObject;
begin
  Result := nil;
  FLastError := 'UploadReleaseAsset not yet implemented - requires HTTP POST support';
end;

function TGitHubClient.DeleteReleaseAsset(const AOwner, ARepo: string; 
  AAssetID: Int64): Boolean;
begin
  Result := False;
  FLastError := 'DeleteReleaseAsset not yet implemented - requires HTTP DELETE support';
end;

function TGitHubClient.GetLastError: string;
begin
  Result := FLastError;
end;

function TGitHubClient.GetLastHTTPCode: Integer;
begin
  Result := FLastHTTPCode;
end;

end.
