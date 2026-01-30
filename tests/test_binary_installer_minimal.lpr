program test_binary_installer_minimal;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.fpc.binary;

var
  Installer: TBinaryInstaller;
begin
  WriteLn('Creating TBinaryInstaller...');
  Flush(Output);

  Installer := TBinaryInstaller.Create;
  WriteLn('TBinaryInstaller created successfully');
  Flush(Output);

  WriteLn('UseCache = ', Installer.UseCache);
  WriteLn('OfflineMode = ', Installer.OfflineMode);
  WriteLn('VerifyInstallation = ', Installer.VerifyInstallation);
  Flush(Output);

  WriteLn('Freeing TBinaryInstaller...');
  Flush(Output);

  Installer.Free;

  WriteLn('TBinaryInstaller freed successfully');
  Flush(Output);

  WriteLn('Test completed successfully');
end.
