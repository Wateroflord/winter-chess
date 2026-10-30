; Установщик Шахматы для Windows (Inno Setup 6), ставится в профиль пользователя.
#define BuildNo GetEnv("BUILD_NO")
#if BuildNo == ""
  #define BuildNo "0"
#endif

[Setup]
AppId={{6451DB50-190C-4D27-9D54-2C8D1091C157}
AppName=Шахматы
AppVersion=1.0.{#BuildNo}
AppPublisher=Winter Hub
DefaultDirName={localappdata}\Programs\Winter Chess
DefaultGroupName=Шахматы
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=Winter-Chess-Setup
Compression=lzma2
SolidCompression=yes
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\winter_chess.exe
CloseApplications=force
RestartApplications=no
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Шахматы"; Filename: "{app}\winter_chess.exe"
Name: "{group}\{cm:UninstallProgram,Шахматы}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\Шахматы"; Filename: "{app}\winter_chess.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\winter_chess.exe"; Description: "{cm:LaunchProgram,Шахматы}"; Flags: nowait postinstall skipifsilent
Filename: "{app}\winter_chess.exe"; Flags: nowait; Check: WizardSilent
