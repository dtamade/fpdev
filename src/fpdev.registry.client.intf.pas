unit fpdev.registry.client.intf;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson;

type
  { Authentication types }
  TAuthType = (atNone, atBearerToken, atAPIKey, atBasicAuth, atOAuth2);

  { Retry configuration }
  TRetryConfig = record
    MaxRetries: Integer;           // Maximum retry attempts (default: 3)
    InitialDelay: Integer;         // Initial delay in milliseconds (default: 1000)
    MaxDelay: Integer;             // Maximum delay in milliseconds (default: 30000)
    BackoffMultiplier: Double;     // Backoff multiplier (default: 2.0)
    RetryableStatusCodes: array of Integer;  // HTTP status codes to retry
  end;

  { Registry configuration }
  TRegistryConfig = record
    BaseURL: string;               // Registry base URL
    Timeout: Integer;              // Timeout in milliseconds (default: 30000)
    UserAgent: string;             // User-Agent string
    VerifySSL: Boolean;            // Verify SSL certificates (default: True)
    ProxyURL: string;              // Proxy URL (optional)
    MaxConcurrentDownloads: Integer;  // Max concurrent downloads (default: 3)
  end;

  { Authentication provider interface }
  IAuthProvider = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetAuthType: TAuthType;
    function GetAuthHeader: string;  // Returns "Authorization: Bearer xxx"
    function IsValid: Boolean;
    function Refresh: Boolean;  // For OAuth2 token refresh
  end;

  { Retry policy interface }
  IRetryPolicy = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    function ShouldRetry(const AAttempt: Integer; const AStatusCode: Integer): Boolean;
    function GetDelay(const AAttempt: Integer): Integer;  // Returns delay in milliseconds
    function GetMaxRetries: Integer;
  end;

  { Remote registry client interface }
  IRemoteRegistryClient = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    
    { Initialization and configuration }
    function Initialize(const AConfig: TRegistryConfig): Boolean;
    procedure SetAuthProvider(const AProvider: IAuthProvider);
    procedure SetRetryPolicy(const APolicy: IRetryPolicy);
    
    { Package query operations }
    function SearchPackages(const AQuery: string): TStringList;
    function GetPackageInfo(const AName: string): TJSONObject;
    function GetPackageVersions(const AName: string): TStringList;
    function GetPackageMetadata(const AName, AVersion: string): TJSONObject;
    
    { Package download operations }
    function DownloadPackage(const AName, AVersion, ADestPath: string): Boolean;
    function GetDownloadURL(const AName, AVersion: string): string;
    
    { Package upload operations }
    function UploadPackage(const AArchivePath: string): Boolean;
    function PublishMetadata(const AMetadata: TJSONObject): Boolean;
    
    { Error handling }
    function GetLastError: string;
    function GetLastHTTPCode: Integer;
  end;

implementation

end.
