; Script completo para AScafe - Avrora Soft - Vibola LLC
; Directorio del proyecto: C:\SALTENA

#define MyAppName "AScafe"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Avrora Soft - Vibola LLC"
#define MyAppURL "https://www.avrorasoft.com"
#define MyAppExeName "ascafe.exe"

[Setup]
AppId={{8B3F8A22-9C14-4E4A-BF39-51A6C8E7F2B1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppCopyright=Copyright (C) 2026 {#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
UsePreviousAppDir=yes
PrivilegesRequired=admin
OutputDir=C:\SALTENA\installer_output
OutputBaseFilename=AScafe_Setup_v1.0.0
Compression=lzma
SolidCompression=yes
WizardStyle=modern
WindowVisible=yes
ChangesAssociations=yes
AppVerName={#MyAppName} v{#MyAppVersion} - {#MyAppPublisher}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} - Sistema POS por {#MyAppPublisher}
VersionInfoVersion=1.0.0.0
SetupIconFile=C:\SALTENA\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\app_icon.ico
UninstallDisplayName={#MyAppName} - {#MyAppPublisher}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Messages]
BeveledLabel={#MyAppPublisher}
SetupWindowTitle=Instalación de {#MyAppName} - {#MyAppPublisher}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Dirs]
; Permisos totales de lectura y escritura para la base de datos SQLite y archivos .av
Name: "{app}"; Permissions: users-modify

[InstallDelete]
Type: files; Name: "{autodesktop}\{#MyAppName}.lnk"
Type: files; Name: "{userdesktop}\{#MyAppName}.lnk"
Type: files; Name: "{commondesktop}\{#MyAppName}.lnk"

[Files]
Source: "C:\SALTENA\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\SALTENA\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "C:\SALTENA\windows\runner\resources\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

; Incluye automáticamente el archivo de licencia (con s o con c) solo si existe en C:\SALTENA
#if FileExists("C:\SALTENA\license.av")
Source: "C:\SALTENA\license.av"; DestDir: "{app}"; Permissions: users-modify; Flags: ignoreversion
#endif

#if FileExists("C:\SALTENA\licence.av")
Source: "C:\SALTENA\licence.av"; DestDir: "{app}"; Permissions: users-modify; Flags: ignoreversion
#endif

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\app_icon.ico"; IconIndex: 0; Comment: "{#MyAppName} - {#MyAppPublisher}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\app_icon.ico"; IconIndex: 0; Comment: "{#MyAppName} - {#MyAppPublisher}"; Tasks: desktopicon

[Run]
; Habilita automáticamente el puerto UDP 45455 y el ejecutable en el Firewall de Windows para recibir pagos de ASyape
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""AScafe Yape UDP"""; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""AScafe Yape UDP"" dir=in action=allow protocol=UDP localport=45455"; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""AScafe Ejecutable"""; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""AScafe Ejecutable"" dir=in action=allow program=""{app}\{#MyAppExeName}"" enable=yes"; Flags: runhidden
Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""AScafe Yape UDP"""; Flags: runhidden; RunOnceId: "DelFirewallUdpAScafe"
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""AScafe Ejecutable"""; Flags: runhidden; RunOnceId: "DelFirewallExeAScafe"