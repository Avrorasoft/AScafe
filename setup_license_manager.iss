[Setup]
AppName=Avrora License Manager
AppVersion=1.0.0
AppPublisher=Avrora Soft - Vibola LLC
DefaultDirName={autopf}\Avrora License Manager
DefaultGroupName=Avrora License Manager
AllowNoIcons=yes
OutputDir=C:\SALTENA\lib\Output
OutputBaseFilename=Avrora_License_Manager_Installer_Release
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
Source: "C:\SALTENA\avrora_license_manager\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Avrora License Manager"; Filename: "{app}\avrora_license_manager.exe"
Name: "{autodesktop}\Avrora License Manager"; Filename: "{app}\avrora_license_manager.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\avrora_license_manager.exe"; Description: "Ejecutar Avrora License Manager"; Flags: nowait postinstall skipifsilent