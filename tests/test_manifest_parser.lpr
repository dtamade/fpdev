program test_manifest_parser;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.manifest;

var
  Parser: TManifestParser;
  TestsPassed, TestsFailed: Integer;
  Pkg: TManifestPackage;
  Target: TManifestTarget;
  Versions, Platforms: TStringArray;
  Algorithm, Digest: string;

procedure Assert(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    Inc(TestsFailed);
  end;
end;

const
  ValidManifest = '{' + LineEnding +
    '  "manifest-version": "1",' + LineEnding +
    '  "date": "2026-01-18",' + LineEnding +
    '  "channel": "stable",' + LineEnding +
    '  "pkg": {' + LineEnding +
    '    "fpc": {' + LineEnding +
    '      "version": "3.2.2",' + LineEnding +
    '      "targets": {' + LineEnding +
    '        "linux-x86_64": {' + LineEnding +
    '          "url": "https://sourceforge.net/fpc-3.2.2.tar.gz",' + LineEnding +
    '          "hash": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",' + LineEnding +
    '          "size": 123456789' + LineEnding +
    '        },' + LineEnding +
    '        "windows-x86_64": {' + LineEnding +
    '          "url": ["https://mirror1.com/fpc.exe", "https://mirror2.com/fpc.exe"],' + LineEnding +
    '          "hash": "sha512:cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e",' + LineEnding +
    '          "size": 987654321,' + LineEnding +
    '          "signature": "minisign:RWS..."' + LineEnding +
    '        }' + LineEnding +
    '      }' + LineEnding +
    '    }' + LineEnding +
    '  }' + LineEnding +
    '}';

  InvalidJSON = '{ "manifest-version": "1", invalid json }';

  MissingManifestVersion = '{' + LineEnding +
    '  "date": "2026-01-18",' + LineEnding +
    '  "pkg": {}' + LineEnding +
    '}';

  MissingDate = '{' + LineEnding +
    '  "manifest-version": "1",' + LineEnding +
    '  "pkg": {}' + LineEnding +
    '}';

  MissingPkg = '{' + LineEnding +
    '  "manifest-version": "1",' + LineEnding +
    '  "date": "2026-01-18"' + LineEnding +
    '}';

  UnsupportedVersion = '{' + LineEnding +
    '  "manifest-version": "2",' + LineEnding +
    '  "date": "2026-01-18",' + LineEnding +
    '  "pkg": {}' + LineEnding +
    '}';

  InvalidHashFormat = '{' + LineEnding +
    '  "manifest-version": "1",' + LineEnding +
    '  "date": "2026-01-18",' + LineEnding +
    '  "pkg": {' + LineEnding +
    '    "fpc": {' + LineEnding +
    '      "version": "3.2.2",' + LineEnding +
    '      "targets": {' + LineEnding +
    '        "linux-x86_64": {' + LineEnding +
    '          "url": "https://example.com/fpc.tar.gz",' + LineEnding +
    '          "hash": "invalid-hash-format",' + LineEnding +
    '          "size": 123456789' + LineEnding +
    '        }' + LineEnding +
    '      }' + LineEnding +
    '    }' + LineEnding +
    '  }' + LineEnding +
    '}';

  NoURLs = '{' + LineEnding +
    '  "manifest-version": "1",' + LineEnding +
    '  "date": "2026-01-18",' + LineEnding +
    '  "pkg": {' + LineEnding +
    '    "fpc": {' + LineEnding +
    '      "version": "3.2.2",' + LineEnding +
    '      "targets": {' + LineEnding +
    '        "linux-x86_64": {' + LineEnding +
    '          "hash": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",' + LineEnding +
    '          "size": 123456789' + LineEnding +
    '        }' + LineEnding +
    '      }' + LineEnding +
    '    }' + LineEnding +
    '  }' + LineEnding +
    '}';

  InvalidSize = '{' + LineEnding +
    '  "manifest-version": "1",' + LineEnding +
    '  "date": "2026-01-18",' + LineEnding +
    '  "pkg": {' + LineEnding +
    '    "fpc": {' + LineEnding +
    '      "version": "3.2.2",' + LineEnding +
    '      "targets": {' + LineEnding +
    '        "linux-x86_64": {' + LineEnding +
    '          "url": "https://example.com/fpc.tar.gz",' + LineEnding +
    '          "hash": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",' + LineEnding +
    '          "size": 0' + LineEnding +
    '        }' + LineEnding +
    '      }' + LineEnding +
    '    }' + LineEnding +
    '  }' + LineEnding +
    '}';

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn('=== Manifest Parser Tests ===');
  WriteLn;

  // Test 1: Parse valid manifest
  Parser := TManifestParser.Create;
  try
    Assert(Parser.LoadFromString(ValidManifest), 'Parse valid manifest');
    Assert(Parser.ManifestVersion = '1', 'Manifest version is 1');
    Assert(Parser.Date = '2026-01-18', 'Date is correct');
    Assert(Parser.Channel = 'stable', 'Channel is stable');
  finally
    Parser.Free;
  end;

  // Test 2: Invalid JSON
  Parser := TManifestParser.Create;
  try
    Assert(not Parser.LoadFromString(InvalidJSON), 'Invalid JSON returns false');
    Assert(Length(Parser.LastError) > 0, 'Invalid JSON sets error message');
  finally
    Parser.Free;
  end;

  // Test 3: Missing manifest-version
  Parser := TManifestParser.Create;
  try
    Assert(not Parser.LoadFromString(MissingManifestVersion), 'Missing manifest-version returns false');
    Assert(Pos('manifest-version', Parser.LastError) > 0, 'Error mentions manifest-version');
  finally
    Parser.Free;
  end;

  // Test 4: Missing date
  Parser := TManifestParser.Create;
  try
    Assert(not Parser.LoadFromString(MissingDate), 'Missing date returns false');
    Assert(Pos('date', Parser.LastError) > 0, 'Error mentions date');
  finally
    Parser.Free;
  end;

  // Test 5: Missing pkg
  Parser := TManifestParser.Create;
  try
    Assert(not Parser.LoadFromString(MissingPkg), 'Missing pkg returns false');
    Assert(Pos('pkg', Parser.LastError) > 0, 'Error mentions pkg');
  finally
    Parser.Free;
  end;

  // Test 6: Unsupported version
  Parser := TManifestParser.Create;
  try
    Assert(not Parser.LoadFromString(UnsupportedVersion), 'Unsupported version returns false');
    Assert(Pos('Unsupported', Parser.LastError) > 0, 'Error mentions unsupported version');
  finally
    Parser.Free;
  end;

  // Test 7: GetPackage with valid data
  Parser := TManifestParser.Create;
  try
    Parser.LoadFromString(ValidManifest);
    Assert(Parser.GetPackage('fpc', '3.2.2', '', Pkg), 'GetPackage returns true for valid package');
    Assert(Pkg.Version = '3.2.2', 'Package version is correct');
    Assert(Length(Pkg.Targets) = 2, 'Package has 2 targets');
  finally
    Parser.Free;
  end;

  // Test 8: GetPackage with invalid version
  Parser := TManifestParser.Create;
  try
    Parser.LoadFromString(ValidManifest);
    Assert(not Parser.GetPackage('fpc', '9.9.9', '', Pkg), 'GetPackage returns false for invalid version');
    Assert(Length(Parser.LastError) > 0, 'GetPackage sets error for invalid version');
  finally
    Parser.Free;
  end;

  // Test 9: GetTarget with valid platform
  Parser := TManifestParser.Create;
  try
    Parser.LoadFromString(ValidManifest);
    Assert(Parser.GetTarget('fpc', '3.2.2', 'linux-x86_64', Target), 'GetTarget returns true for valid platform');
    Assert(Length(Target.URLs) = 1, 'Target has 1 URL');
    Assert(Pos('sourceforge', Target.URLs[0]) > 0, 'URL contains sourceforge');
    Assert(Target.Hash = 'sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 'Hash is correct');
    Assert(Target.Size = 123456789, 'Size is correct');
  finally
    Parser.Free;
  end;

  // Test 10: GetTarget with multi-mirror URLs
  Parser := TManifestParser.Create;
  try
    Parser.LoadFromString(ValidManifest);
    Assert(Parser.GetTarget('fpc', '3.2.2', 'windows-x86_64', Target), 'GetTarget returns true for windows platform');
    Assert(Length(Target.URLs) = 2, 'Target has 2 mirror URLs');
    Assert(Pos('mirror1', Target.URLs[0]) > 0, 'First mirror URL is correct');
    Assert(Pos('mirror2', Target.URLs[1]) > 0, 'Second mirror URL is correct');
    Assert(Pos('sha512', Target.Hash) > 0, 'Hash uses sha512');
    Assert(Target.Signature = 'minisign:RWS...', 'Signature is present');
  finally
    Parser.Free;
  end;

  // Test 11: GetTarget with invalid platform
  Parser := TManifestParser.Create;
  try
    Parser.LoadFromString(ValidManifest);
    Assert(not Parser.GetTarget('fpc', '3.2.2', 'invalid-platform', Target), 'GetTarget returns false for invalid platform');
    Assert(Pos('Platform not found', Parser.LastError) > 0, 'Error mentions platform not found');
  finally
    Parser.Free;
  end;

  // Test 12: ListVersions
  Parser := TManifestParser.Create;
  try
    Parser.LoadFromString(ValidManifest);
    Versions := Parser.ListVersions('fpc');
    Assert(Length(Versions) = 1, 'ListVersions returns 1 version');
    Assert(Versions[0] = '3.2.2', 'Version is 3.2.2');
  finally
    Parser.Free;
  end;

  // Test 13: ListPlatforms
  Parser := TManifestParser.Create;
  try
    Parser.LoadFromString(ValidManifest);
    Platforms := Parser.ListPlatforms('fpc', '3.2.2');
    Assert(Length(Platforms) = 2, 'ListPlatforms returns 2 platforms');
    Assert((Platforms[0] = 'linux-x86_64') or (Platforms[1] = 'linux-x86_64'), 'linux-x86_64 platform exists');
    Assert((Platforms[0] = 'windows-x86_64') or (Platforms[1] = 'windows-x86_64'), 'windows-x86_64 platform exists');
  finally
    Parser.Free;
  end;

  // Test 14: Validate with valid manifest
  Parser := TManifestParser.Create;
  try
    Parser.LoadFromString(ValidManifest);
    Assert(Parser.Validate, 'Validate returns true for valid manifest');
  finally
    Parser.Free;
  end;

  // Test 15: Validate with invalid hash format
  Parser := TManifestParser.Create;
  try
    Parser.LoadFromString(InvalidHashFormat);
    Assert(not Parser.Validate, 'Validate returns false for invalid hash format');
    Assert(Pos('Invalid hash format', Parser.LastError) > 0, 'Error mentions invalid hash format');
  finally
    Parser.Free;
  end;

  // Test 16: Validate with no URLs
  Parser := TManifestParser.Create;
  try
    Parser.LoadFromString(NoURLs);
    Assert(not Parser.Validate, 'Validate returns false for no URLs');
    Assert(Pos('No URLs', Parser.LastError) > 0, 'Error mentions no URLs');
  finally
    Parser.Free;
  end;

  // Test 17: Validate with invalid size
  Parser := TManifestParser.Create;
  try
    Parser.LoadFromString(InvalidSize);
    Assert(not Parser.Validate, 'Validate returns false for invalid size');
    Assert(Pos('Invalid size', Parser.LastError) > 0, 'Error mentions invalid size');
  finally
    Parser.Free;
  end;

  // Test 18: ValidateHashFormat helper function
  Assert(ValidateHashFormat('sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'), 'ValidateHashFormat accepts sha256');
  Assert(ValidateHashFormat('sha512:cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e'), 'ValidateHashFormat accepts sha512');
  Assert(not ValidateHashFormat('md5:abc123'), 'ValidateHashFormat rejects md5');
  Assert(not ValidateHashFormat('invalid-format'), 'ValidateHashFormat rejects invalid format');
  Assert(not ValidateHashFormat('sha256:'), 'ValidateHashFormat rejects empty digest');

  // Test 19: ParseHashAlgorithm helper function
  Assert(ParseHashAlgorithm('sha256:abc123', Algorithm, Digest), 'ParseHashAlgorithm parses sha256');
  Assert(Algorithm = 'sha256', 'Algorithm is sha256');
  Assert(Digest = 'abc123', 'Digest is abc123');

  Assert(ParseHashAlgorithm('sha512:def456', Algorithm, Digest), 'ParseHashAlgorithm parses sha512');
  Assert(Algorithm = 'sha512', 'Algorithm is sha512');
  Assert(Digest = 'def456', 'Digest is def456');

  Assert(not ParseHashAlgorithm('no-colon', Algorithm, Digest), 'ParseHashAlgorithm rejects no colon');
  Assert(not ParseHashAlgorithm('md5:hash', Algorithm, Digest), 'ParseHashAlgorithm rejects md5');

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
