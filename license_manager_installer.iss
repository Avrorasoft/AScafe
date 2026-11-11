; =====================================================================
; Instalador Independiente - Avrora License Manager
; Empresa: Avrora Soft / Vibola LLC
; =====================================================================

[Setup]
AppName=Avrora License Manager
AppVersion=1.0.0
AppPublisher=Avrora Soft - Vibola LLC
DefaultDirName={autopf}\AvroraLicenseManager
DefaultGroupName=Avrora Soft
AllowNoIcons=yes
OutputDir=C:\SALTENA\lib\Output
OutputBaseFilename=Avrora_License_Manager_Installer_Release
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Files]
; Copia absoluta de todo el contenido de la carpeta Release del generador de licencias
Source: "C:\SALTENA\avrora_license_manager\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Gestor de Licencias Avrora"; Filename: "{app}\avrora_license_manager.exe"
Name: "{autodesktop}\Gestor de Licencias Avrora"; Filename: "{app}\avrora_license_manager.exe"; Tasks: desktopicon
Name: "{group}\Desinstalar Gestor de Licencias"; Filename: "{uninstallexe}"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\avrora_license_manager.exe"; Description: "{cm:LaunchProgram,Avrora License Manager}"; Flags: nowait postinstall skipifsilent