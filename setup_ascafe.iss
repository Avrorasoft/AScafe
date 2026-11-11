[Setup]
AppName=AScafe POS
AppVersion=1.0.0
AppPublisher=Avrora Soft - Vibola LLC
DefaultDirName={autopf}\AScafe POS
DefaultGroupName=AScafe POS
AllowNoIcons=yes
OutputDir=C:\SALTENA\lib\Output
OutputBaseFilename=AScafe_Installer_Release
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "C:\SALTENA\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\AScafe POS"; Filename: "{app}\AScafe.exe"
Name: "{autodesktop}\AScafe POS"; Filename: "{app}\AScafe.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\AScafe.exe"; Description: "Ejecutar AScafe POS"; Flags: nowait postinstall skipifsilent