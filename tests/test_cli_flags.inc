procedure TestGlobalNormalizeLeadingPortable;
var
  Primary: string;
  Params: TStringArray;
  DispatchArgs: TStringArray;
begin
  NormalizePrimaryAndParams(MakeArgs(['--portable', 'fpc', 'list']), Primary, Params);
  DispatchArgs := BuildDispatchArgs(Primary, Params);
  Check('global normalize portable primary', Primary = 'fpc');
  Check('global normalize portable param count', Length(Params) = 1);
  Check('global normalize portable first param', Params[0] = 'list');
  Check('global dispatch args count', Length(DispatchArgs) = 2);
  Check('global dispatch arg0', DispatchArgs[0] = 'fpc');
  Check('global dispatch arg1', DispatchArgs[1] = 'list');
end;

procedure TestGlobalNormalizePortableOnly;
var
  Primary: string;
  Params: TStringArray;
  DispatchArgs: TStringArray;
begin
  NormalizePrimaryAndParams(MakeArgs(['--portable']), Primary, Params);
  DispatchArgs := BuildDispatchArgs(Primary, Params);
  Check('global normalize portable-only primary empty', Primary = '');
  Check('global normalize portable-only params empty', Length(Params) = 0);
  Check('global normalize portable-only dispatch empty', Length(DispatchArgs) = 0);
end;

procedure TestApplyPortableModeLeadingPreludeOnly;
begin
  SetPortableMode(False);
  ApplyPortableModeFromArgs(MakeArgs(['--portable', 'fpc', 'list']));
  Check('apply portable mode handles leading prelude', IsPortableMode);

  SetPortableMode(False);
  ApplyPortableModeFromArgs(MakeArgs(['fpc', 'list', '--portable']));
  Check('apply portable mode ignores non-leading portable flag', not IsPortableMode);
end;
