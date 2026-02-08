unit fpdev.exitcodes;

{$mode objfpc}{$H+}

{
  Global exit code constants for FPDev CLI.

  Standard exit code conventions:
  - 0: Success
  - 1: General error (runtime failures)
  - 2: Usage error (invalid arguments, missing parameters)
  - 3: Configuration error
  - 4: Network/IO error
  - 10+: Command-specific errors

  Usage:
    uses fpdev.exitcodes;
    ...
    Exit(EXIT_OK);
    Exit(EXIT_USAGE_ERROR);
}

interface

const
  { Success - command completed successfully }
  EXIT_OK = 0;

  { General runtime error - operation failed }
  EXIT_ERROR = 1;

  { Usage error - invalid arguments, missing required parameters }
  EXIT_USAGE_ERROR = 2;

  { Configuration error - invalid config, missing settings }
  EXIT_CONFIG_ERROR = 3;

  { Network/IO error - connection failed, file not found }
  EXIT_IO_ERROR = 4;

  { Resource not found - version, package, or target not found }
  EXIT_NOT_FOUND = 10;

  { Already exists - version already installed, package already added }
  EXIT_ALREADY_EXISTS = 11;

implementation

end.
