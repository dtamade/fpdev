unit fpdev.registry.client;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, fpjson, jsonparser,
  fpdev.registry.client.intf, fpdev.registry.auth, fpdev.registry.retry;

type
  { TRemoteRegistryClient - Remote registry client implementation }
  TRemoteRegistryClient = class(TInterfacedObject, IRemoteRegistryClient)
  private
    FConfig: TRegistryConfig;
    FAuthProvider: IAuthProvider;
    FRetryPolicy: IRetryPolicy;
    FHTTPClient: TFPHTTPClient;
    FLastError: string;
    FLastHTTPCode: Integer;
    
    function BuildURL(const APath: string): string;
    function AddAuthHeaders(const AHeaders: TStrings): Boolean;
    function ExecuteWithRetry(const AMethod, AURL: string;
      const ABody: TStream; const AHeaders: TStrings;
      const AResponse: TStream): Boolean;
    function BuildMultipartBody(const AFilePath, AFieldName: string;
      out ABoundary: string): TMemoryStream;
  public
    constructor Create;
    destructor Destroy; override;
    
    { IRemoteRegistryClient implementation }
    function Initialize(const AConfig: TRegistryConfig): Boolean;
    procedure SetAuthProvider(const AProvider: IAuthProvider);
    procedure SetRetryPolicy(const APolicy: IRetryPolicy);
    
    function SearchPackages(const AQuery: string): TStringList;
    function GetPackageInfo(const AName: string): TJSONObject;
    function GetPackageVersions(const AName: string): TStringList;
    function GetPackageMetadata(const AName, AVersion: string): TJSONObject;
    
    function DownloadPackage(const AName, AVersion, ADestPath: string): Boolean;
    function GetDownloadURL(const AName, AVersion: string): string;
    
    function UploadPackage(const AArchivePath: string): Boolean;
    function PublishMetadata(const AMetadata: TJSONObject): Boolean;
    
    function GetLastError: string;
    function GetLastHTTPCode: Integer;
  end;

implementation

const
  URL_PATH_SEPARATOR = '/';
  API_PACKAGES_SEARCH_PREFIX = '/api/packages/search?q=';
  API_PACKAGES_PREFIX = '/api/packages/';
  API_PACKAGES_VERSIONS_SUFFIX = '/versions';
  API_PACKAGES_METADATA_SUFFIX = '/metadata';
  API_PACKAGES_DOWNLOAD_SUFFIX = '/download';
  API_PACKAGES_UPLOAD_PATH = '/api/packages/upload';
  API_PACKAGES_PUBLISH_PATH = '/api/packages/publish';

{ Helper functions }

procedure WriteString(AStream: TStream; const AStr: string);
begin
  if Length(AStr) > 0 then
    AStream.WriteBuffer(AStr[1], Length(AStr));
end;

{ TRemoteRegistryClient }

constructor TRemoteRegistryClient.Create;
begin
  inherited Create;
  FHTTPClient := TFPHTTPClient.Create(nil);
  FHTTPClient.AllowRedirect := True;
  FLastError := '';
  FLastHTTPCode := 0;
  FAuthProvider := nil;
  FRetryPolicy := nil;
end;

destructor TRemoteRegistryClient.Destroy;
begin
  FHTTPClient.Free;
  inherited Destroy;
end;

function TRemoteRegistryClient.Initialize(const AConfig: TRegistryConfig): Boolean;
begin
  FConfig := AConfig;
  
  // Configure HTTP client
  if AConfig.Timeout > 0 then
  begin
    FHTTPClient.ConnectTimeout := AConfig.Timeout;
    FHTTPClient.IOTimeout := AConfig.Timeout;
  end;
  
  // Set User-Agent
  if AConfig.UserAgent <> '' then
    FHTTPClient.AddHeader('User-Agent', AConfig.UserAgent)
  else
    FHTTPClient.AddHeader('User-Agent', 'fpdev-registry-client/1.0');
  
  Result := True;
end;

procedure TRemoteRegistryClient.SetAuthProvider(const AProvider: IAuthProvider);
begin
  FAuthProvider := AProvider;
end;

procedure TRemoteRegistryClient.SetRetryPolicy(const APolicy: IRetryPolicy);
begin
  FRetryPolicy := APolicy;
end;

function TRemoteRegistryClient.BuildURL(const APath: string): string;
begin
  Result := FConfig.BaseURL;
  if (Length(Result) > 0) and
    (Result[Length(Result)] <> URL_PATH_SEPARATOR) then
    Result := Result + URL_PATH_SEPARATOR;
  if (Length(APath) > 0) and (APath[1] = URL_PATH_SEPARATOR) then
    Result := Result + Copy(APath, 2, Length(APath))
  else
    Result := Result + APath;
end;

function TRemoteRegistryClient.AddAuthHeaders(const AHeaders: TStrings): Boolean;
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

function TRemoteRegistryClient.ExecuteWithRetry(const AMethod, AURL: string;
  const ABody: TStream; const AHeaders: TStrings; const AResponse: TStream): Boolean;
var
  Attempt: Integer;
  Delay: Integer;
  Success: Boolean;
  StatusCode: Integer;
begin
  Result := False;
  Attempt := 0;
  
  repeat
    Success := False;
    
    try
      // Clear previous headers
      FHTTPClient.RequestHeaders.Clear;
      
      // Add custom headers
      if Assigned(AHeaders) then
        FHTTPClient.RequestHeaders.AddStrings(AHeaders);

      // Reset request body between attempts/method changes.
      FHTTPClient.RequestBody := nil;
      
      // Execute HTTP request
      if AMethod = 'GET' then
      begin
        FHTTPClient.Get(AURL, AResponse);
        Success := True;
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
        Success := True;
      end
      else if AMethod = 'DELETE' then
      begin
        FHTTPClient.HTTPMethod('DELETE', AURL, AResponse, [200, 202, 204]);
        Success := True;
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
      begin
        Result := True;
        Exit;
      end
      else
      begin
        FLastError := Format('HTTP %d: %s', [StatusCode, FHTTPClient.ResponseStatusText]);
        Success := False;
      end;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        StatusCode := 0;
        Success := False;
      end;
    end;
    
    // Check if should retry
    if not Success and Assigned(FRetryPolicy) then
    begin
      if FRetryPolicy.ShouldRetry(Attempt, StatusCode) then
      begin
        Delay := FRetryPolicy.GetDelay(Attempt);
        Sleep(Delay);
        Inc(Attempt);
        Continue;
      end;
    end;
    
    Break;
  until False;
  
  Result := Success;
end;

function TRemoteRegistryClient.BuildMultipartBody(const AFilePath, AFieldName: string;
  out ABoundary: string): TMemoryStream;
var
  FileStream: TFileStream;
  Body: TMemoryStream;
  FileName: string;
begin
  ABoundary := '---------------------------' + IntToStr(Random(MaxInt));
  Body := TMemoryStream.Create;
  
  try
    FileName := ExtractFileName(AFilePath);
    
    // Write boundary and headers
    WriteString(Body, '--' + ABoundary + #13#10);
    WriteString(Body, 'Content-Disposition: form-data; name="' + AFieldName + '"; filename="' + FileName + '"'#13#10);
    WriteString(Body, 'Content-Type: application/octet-stream'#13#10#13#10);
    
    // Write file content
    FileStream := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyWrite);
    try
      Body.CopyFrom(FileStream, FileStream.Size);
    finally
      FileStream.Free;
    end;
    
    // Write closing boundary
    WriteString(Body, #13#10'--' + ABoundary + '--'#13#10);
    
    Body.Position := 0;
    Result := Body;
  except
    Body.Free;
    raise;
  end;
end;

function TRemoteRegistryClient.SearchPackages(const AQuery: string): TStringList;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
  JSONArray: TJSONArray;
  I: Integer;
begin
  Result := TStringList.Create;
  
  URL := BuildURL(API_PACKAGES_SEARCH_PREFIX + AQuery);
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  try
    AddAuthHeaders(Headers);
    
    if ExecuteWithRetry('GET', URL, nil, Headers, Response) then
    begin
      Response.Position := 0;
      JSON := GetJSON(Response);
      try
        if JSON is TJSONArray then
        begin
          JSONArray := TJSONArray(JSON);
          for I := 0 to JSONArray.Count - 1 do
            Result.Add(JSONArray.Strings[I]);
        end;
      finally
        JSON.Free;
      end;
    end;
  finally
    Headers.Free;
    Response.Free;
  end;
end;

function TRemoteRegistryClient.GetPackageInfo(const AName: string): TJSONObject;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
begin
  Result := nil;
  
  URL := BuildURL(API_PACKAGES_PREFIX + AName);
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  try
    AddAuthHeaders(Headers);
    
    if ExecuteWithRetry('GET', URL, nil, Headers, Response) then
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

function TRemoteRegistryClient.GetPackageVersions(const AName: string): TStringList;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
  JSONArray: TJSONArray;
  I: Integer;
begin
  Result := TStringList.Create;
  
  URL := BuildURL(
    API_PACKAGES_PREFIX + AName + API_PACKAGES_VERSIONS_SUFFIX
  );
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  try
    AddAuthHeaders(Headers);
    
    if ExecuteWithRetry('GET', URL, nil, Headers, Response) then
    begin
      Response.Position := 0;
      JSON := GetJSON(Response);
      try
        if JSON is TJSONArray then
        begin
          JSONArray := TJSONArray(JSON);
          for I := 0 to JSONArray.Count - 1 do
            Result.Add(JSONArray.Strings[I]);
        end;
      finally
        JSON.Free;
      end;
    end;
  finally
    Headers.Free;
    Response.Free;
  end;
end;

function TRemoteRegistryClient.GetPackageMetadata(const AName, AVersion: string): TJSONObject;
var
  URL: string;
  Response: TMemoryStream;
  Headers: TStringList;
  JSON: TJSONData;
begin
  Result := nil;
  
  URL := BuildURL(
    API_PACKAGES_PREFIX + AName + URL_PATH_SEPARATOR + AVersion +
    API_PACKAGES_METADATA_SUFFIX
  );
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  try
    AddAuthHeaders(Headers);
    
    if ExecuteWithRetry('GET', URL, nil, Headers, Response) then
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

function TRemoteRegistryClient.DownloadPackage(const AName, AVersion, ADestPath: string): Boolean;
var
  URL: string;
  Response: TFileStream;
  Headers: TStringList;
begin
  Result := False;
  
  URL := BuildURL(
    API_PACKAGES_PREFIX + AName + URL_PATH_SEPARATOR + AVersion +
    API_PACKAGES_DOWNLOAD_SUFFIX
  );
  Response := TFileStream.Create(ADestPath, fmCreate);
  Headers := TStringList.Create;
  try
    AddAuthHeaders(Headers);
    
    Result := ExecuteWithRetry('GET', URL, nil, Headers, Response);
  finally
    Headers.Free;
    Response.Free;
  end;
end;

function TRemoteRegistryClient.GetDownloadURL(const AName, AVersion: string): string;
begin
  Result := BuildURL(
    API_PACKAGES_PREFIX + AName + URL_PATH_SEPARATOR + AVersion +
    API_PACKAGES_DOWNLOAD_SUFFIX
  );
end;

function TRemoteRegistryClient.UploadPackage(const AArchivePath: string): Boolean;
var
  URL: string;
  Body: TMemoryStream;
  Response: TMemoryStream;
  Headers: TStringList;
  Boundary: string;
begin
  Result := False;
  
  if not FileExists(AArchivePath) then
  begin
    FLastError := 'Archive file not found: ' + AArchivePath;
    Exit;
  end;
  
  URL := BuildURL(API_PACKAGES_UPLOAD_PATH);
  Body := BuildMultipartBody(AArchivePath, 'package', Boundary);
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  try
    AddAuthHeaders(Headers);
    Headers.Add('Content-Type: multipart/form-data; boundary=' + Boundary);
    
    Result := ExecuteWithRetry('POST', URL, Body, Headers, Response);
  finally
    Headers.Free;
    Response.Free;
    Body.Free;
  end;
end;

function TRemoteRegistryClient.PublishMetadata(const AMetadata: TJSONObject): Boolean;
var
  URL: string;
  Body: TMemoryStream;
  Response: TMemoryStream;
  Headers: TStringList;
  JSONStr: string;
begin
  Result := False;
  
  if not Assigned(AMetadata) then
  begin
    FLastError := 'Metadata is nil';
    Exit;
  end;
  
  URL := BuildURL(API_PACKAGES_PUBLISH_PATH);
  Body := TMemoryStream.Create;
  Response := TMemoryStream.Create;
  Headers := TStringList.Create;
  try
    // Convert JSON to string and write to stream
    JSONStr := AMetadata.AsJSON;
    WriteString(Body, JSONStr);
    Body.Position := 0;
    
    AddAuthHeaders(Headers);
    Headers.Add('Content-Type: application/json');
    
    Result := ExecuteWithRetry('POST', URL, Body, Headers, Response);
  finally
    Headers.Free;
    Response.Free;
    Body.Free;
  end;
end;

function TRemoteRegistryClient.GetLastError: string;
begin
  Result := FLastError;
end;

function TRemoteRegistryClient.GetLastHTTPCode: Integer;
begin
  Result := FLastHTTPCode;
end;

end.
