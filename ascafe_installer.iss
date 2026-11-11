; =====================================================================
; Instalador Independiente - AScafe POS
; Empresa: Avrora Soft / Vibola LLC
; =====================================================================

[Setup]
AppName=AScafe POS
AppVersion=1.0.0
AppPublisher=Avrora Soft - Vibola LLC
DefaultDirName={autopf}\AScafe
DefaultGroupName=AScafe POS
AllowNoIcons=yes
OutputDir=C:\SALTENA\lib\Output
OutputBaseFilename=AScafe_Installer_Release
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Files]
; Copia absoluta de todo el contenido de la carpeta Release (incluyendo el ejecutable, todas las DLLs de plugins, y la carpeta data completa)
Source: "C:\SALTENA\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\AScafe POS"; Filename: "{app}\AScafe.exe"
Name: "{autodesktop}\AScafe POS"; Filename: "{app}\AScafe.exe"; Tasks: desktopicon
Name: "{group}\Desinstalar AScafe"; Filename: "{uninstallexe}"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\AScafe.exe"; Description: "{cm:LaunchProgram,AScafe POS}"; Flags: nowait postinstall skipifsilent