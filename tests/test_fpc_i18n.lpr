program test_fpc_i18n;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpc.i18n,
  fpdev.utils;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

{$IFNDEF MSWINDOWS}
procedure TestDetectSystemLanguageUsesSameProcessLCAllPrecedence;
var
  Manager: TI18nManager;
  SavedLCAll: string;
  SavedLCMessages: string;
  SavedLang: string;
begin
  SavedLCAll := get_env('LC_ALL');
  SavedLCMessages := get_env('LC_MESSAGES');
  SavedLang := get_env('LANG');
  try
    set_env('LC_ALL', 'de_DE.UTF-8');
    set_env('LC_MESSAGES', 'zh_CN.UTF-8');
    set_env('LANG', 'ja_JP.UTF-8');

    Manager := TI18nManager.Create;
    try
      Check('DetectSystemLanguage prefers same-process LC_ALL',
        Manager.DetectSystemLanguage = langGerman,
        'expected langGerman');
    finally
      Manager.Free;
    end;
  finally
    RestoreEnv('LC_ALL', SavedLCAll);
    RestoreEnv('LC_MESSAGES', SavedLCMessages);
    RestoreEnv('LANG', SavedLang);
  end;
end;

procedure TestDetectSystemLanguageUsesSameProcessLCMessagesFallback;
var
  Manager: TI18nManager;
  SavedLCAll: string;
  SavedLCMessages: string;
  SavedLang: string;
begin
  SavedLCAll := get_env('LC_ALL');
  SavedLCMessages := get_env('LC_MESSAGES');
  SavedLang := get_env('LANG');
  try
    unset_env('LC_ALL');
    set_env('LC_MESSAGES', 'ru_RU.UTF-8');
    set_env('LANG', 'fr_FR.UTF-8');

    Manager := TI18nManager.Create;
    try
      Check('DetectSystemLanguage falls back to same-process LC_MESSAGES',
        Manager.DetectSystemLanguage = langRussian,
        'expected langRussian');
    finally
      Manager.Free;
    end;
  finally
    RestoreEnv('LC_ALL', SavedLCAll);
    RestoreEnv('LC_MESSAGES', SavedLCMessages);
    RestoreEnv('LANG', SavedLang);
  end;
end;

procedure TestDetectSystemLanguageUsesSameProcessLANGFallback;
var
  Manager: TI18nManager;
  SavedLCAll: string;
  SavedLCMessages: string;
  SavedLang: string;
begin
  SavedLCAll := get_env('LC_ALL');
  SavedLCMessages := get_env('LC_MESSAGES');
  SavedLang := get_env('LANG');
  try
    unset_env('LC_ALL');
    unset_env('LC_MESSAGES');
    set_env('LANG', 'pt_BR.UTF-8');

    Manager := TI18nManager.Create;
    try
      Check('DetectSystemLanguage falls back to same-process LANG',
        Manager.DetectSystemLanguage = langPortuguese,
        'expected langPortuguese');
    finally
      Manager.Free;
    end;
  finally
    RestoreEnv('LC_ALL', SavedLCAll);
    RestoreEnv('LC_MESSAGES', SavedLCMessages);
    RestoreEnv('LANG', SavedLang);
  end;
end;
{$ENDIF}

begin
  WriteLn('========================================');
  WriteLn('FPC I18n Tests');
  WriteLn('========================================');

  {$IFDEF MSWINDOWS}
  WriteLn('[PASS] Locale env detection probe skipped on Windows');
  {$ELSE}
  TestDetectSystemLanguageUsesSameProcessLCAllPrecedence;
  TestDetectSystemLanguageUsesSameProcessLCMessagesFallback;
  TestDetectSystemLanguageUsesSameProcessLANGFallback;
  {$ENDIF}

  WriteLn('========================================');
  WriteLn('Total:   ', PassCount + FailCount);
  WriteLn('Passed:  ', PassCount);
  WriteLn('Failed:  ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
