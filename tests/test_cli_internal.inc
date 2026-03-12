procedure TestSystemToolchainFetchUsageError;
var
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'toolchain', 'fetch'], Ctx);
  Check('system toolchain fetch usage exit', Ret = EXIT_USAGE_ERROR);
  Check('system toolchain fetch usage text',
    StdErr.Contains('Usage: fpdev system toolchain fetch <name> <version> <os> <arch>'));
end;

procedure TestSystemToolchainExtractUsageError;
var
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'toolchain', 'extract'], Ctx);
  Check('system toolchain extract usage exit', Ret = EXIT_USAGE_ERROR);
  Check('system toolchain extract usage text',
    StdErr.Contains('Usage: fpdev system toolchain extract <zip> <dest>'));
end;

procedure TestSystemToolchainEnsureSourceUsageError;
var
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'toolchain', 'ensure-source', 'fpc-src', '3.2.2'], Ctx);
  Check('system toolchain ensure-source usage exit', Ret = EXIT_USAGE_ERROR);
  Check('system toolchain ensure-source usage text',
    StdErr.Contains('Usage: fpdev system toolchain ensure-source <name> <version> --local <dir|zip>'));
end;

procedure TestSystemToolchainImportBundleUsageError;
var
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'toolchain', 'import-bundle'], Ctx);
  Check('system toolchain import-bundle usage exit', Ret = EXIT_USAGE_ERROR);
  Check('system toolchain import-bundle usage text',
    StdErr.Contains('Usage: fpdev system toolchain import-bundle <dir|zip>'));
end;
