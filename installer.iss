; Script de Instalación Oficial - AScafe
[Setup]
AppName=AScafe
AppVersion=1.0
AppPublisher=Avrora Soft - Vibola LLC
AppPublisherURL=https://github.com/Avrorasoft
AppCopyright=Copyright (C) 2026 Avrora Soft - Vibola LLC
VersionInfoCompany=Avrora Soft - Vibola LLC
DefaultDirName={pf}\AScafe
DefaultGroupName=AScafe
OutputDir=C:\SALTENA\Output
OutputBaseFilename=AScafe_Setup_v1.0
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
SetupIconFile=C:\SALTENA\windows\runner\resources\app_icon.ico

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Files]
Source: "C:\SALTENA\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\AScafe"; Filename: "{app}\AScafe.exe"; IconFilename: "{app}\AScafe.exe"
Name: "{commondesktop}\AScafe"; Filename: "{app}\AScafe.exe"; IconFilename: "{app}\AScafe.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Code]
procedure InitializeWizard();
begin
  WizardForm.Caption := 'Instalador de AScafe — Avrora Soft - Vibola LLC';
  WizardForm.WelcomeLabel1.Caption := 'Bienvenido al asistente de instalación de AScafe';
  WizardForm.WelcomeLabel2.Caption := 'Este programa instalará AScafe en su equipo.%n%nDesarrollado oficialmente por Avrora Soft - Vibola LLC.';
end;