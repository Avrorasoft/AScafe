; Script para empaquetar Keygen-AS (Avrora Soft - Vibola LLC)
; Archivo: keygen_installer.iss

[Setup]
AppId={{B812C523-2F5B-4943-9C6F-KEYGEN2026}
AppName=Avrora Soft - Keygen License Generator
AppVersion=1.0.0
AppPublisher=Avrora Soft - Vibola LLC
AppPublisherURL=https://www.avrorasoft.com
AppSupportURL=https://www.avrorasoft.com
AppUpdatesURL=https://www.avrorasoft.com
DefaultDirName={autopf}\AvroraSoft\Keygen
DefaultGroupName=Avrora Soft Keygen
AllowNoIcons=yes
OutputDir=.\Output
OutputBaseFilename=Keygen_AS_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Ruta absoluta exacta hacia la carpeta Release de tu proyecto
Source: "C:\SALTENA\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Keygen AS"; Filename: "{app}\keygen-AS.exe"
Name: "{group}\{cm:UninstallProgram,Keygen AS}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Keygen AS"; Filename: "{app}\keygen-AS.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\keygen-AS.exe"; Description: "{cm:LaunchProgram,Keygen AS}"; Flags: nowait postinstall skipifsilent