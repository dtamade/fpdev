unit fpdev.registry.auth;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpdev.registry.client.intf, base64;

type
  { TBearerTokenAuth - Bearer token authentication provider }
  TBearerTokenAuth = class(TInterfacedObject, IAuthProvider)
  private
    FToken: string;
    FValid: Boolean;
  public
    constructor Create(const AToken: string);
    
    { IAuthProvider implementation }
    function GetAuthType: TAuthType;
    function GetAuthHeader: string;
    function IsValid: Boolean;
    function Refresh: Boolean;
  end;

  { TAPIKeyAuth - API key authentication provider }
  TAPIKeyAuth = class(TInterfacedObject, IAuthProvider)
  private
    FAPIKey: string;
    FHeaderName: string;
    FValid: Boolean;
  public
    constructor Create(const AAPIKey: string; const AHeaderName: string = 'X-API-Key');
    
    { IAuthProvider implementation }
    function GetAuthType: TAuthType;
    function GetAuthHeader: string;
    function IsValid: Boolean;
    function Refresh: Boolean;
  end;

  { TBasicAuth - Basic authentication provider }
  TBasicAuth = class(TInterfacedObject, IAuthProvider)
  private
    FUsername: string;
    FPassword: string;
    FValid: Boolean;
  public
    constructor Create(const AUsername, APassword: string);
    
    { IAuthProvider implementation }
    function GetAuthType: TAuthType;
    function GetAuthHeader: string;
    function IsValid: Boolean;
    function Refresh: Boolean;
  end;

  { TNoneAuth - No authentication provider }
  TNoneAuth = class(TInterfacedObject, IAuthProvider)
  public
    { IAuthProvider implementation }
    function GetAuthType: TAuthType;
    function GetAuthHeader: string;
    function IsValid: Boolean;
    function Refresh: Boolean;
  end;

implementation

{ TBearerTokenAuth }

constructor TBearerTokenAuth.Create(const AToken: string);
begin
  inherited Create;
  FToken := AToken;
  FValid := Length(AToken) > 0;
end;

function TBearerTokenAuth.GetAuthType: TAuthType;
begin
  Result := atBearerToken;
end;

function TBearerTokenAuth.GetAuthHeader: string;
begin
  if FValid then
    Result := 'Authorization: Bearer ' + FToken
  else
    Result := '';
end;

function TBearerTokenAuth.IsValid: Boolean;
begin
  Result := FValid and (Length(FToken) > 0);
end;

function TBearerTokenAuth.Refresh: Boolean;
begin
  // Bearer tokens typically don't support refresh
  Result := IsValid;
end;

{ TAPIKeyAuth }

constructor TAPIKeyAuth.Create(const AAPIKey: string; const AHeaderName: string);
begin
  inherited Create;
  FAPIKey := AAPIKey;
  FHeaderName := AHeaderName;
  FValid := Length(AAPIKey) > 0;
end;

function TAPIKeyAuth.GetAuthType: TAuthType;
begin
  Result := atAPIKey;
end;

function TAPIKeyAuth.GetAuthHeader: string;
begin
  if FValid then
    Result := FHeaderName + ': ' + FAPIKey
  else
    Result := '';
end;

function TAPIKeyAuth.IsValid: Boolean;
begin
  Result := FValid and (Length(FAPIKey) > 0);
end;

function TAPIKeyAuth.Refresh: Boolean;
begin
  // API keys typically don't support refresh
  Result := IsValid;
end;

{ TBasicAuth }

constructor TBasicAuth.Create(const AUsername, APassword: string);
begin
  inherited Create;
  FUsername := AUsername;
  FPassword := APassword;
  FValid := (Length(AUsername) > 0) and (Length(APassword) > 0);
end;

function TBasicAuth.GetAuthType: TAuthType;
begin
  Result := atBasicAuth;
end;

function TBasicAuth.GetAuthHeader: string;
var
  Credentials: string;
  Encoded: string;
begin
  if FValid then
  begin
    Credentials := FUsername + ':' + FPassword;
    Encoded := EncodeStringBase64(Credentials);
    Result := 'Authorization: Basic ' + Encoded;
  end
  else
    Result := '';
end;

function TBasicAuth.IsValid: Boolean;
begin
  Result := FValid and (Length(FUsername) > 0) and (Length(FPassword) > 0);
end;

function TBasicAuth.Refresh: Boolean;
begin
  // Basic auth doesn't support refresh
  Result := IsValid;
end;

{ TNoneAuth }

function TNoneAuth.GetAuthType: TAuthType;
begin
  Result := atNone;
end;

function TNoneAuth.GetAuthHeader: string;
begin
  Result := '';
end;

function TNoneAuth.IsValid: Boolean;
begin
  Result := True;
end;

function TNoneAuth.Refresh: Boolean;
begin
  Result := True;
end;

end.
