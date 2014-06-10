#define MyGettextVer "0.19.1"
#define MyIconvVer "1.14"

[Setup]
AppId="gettext-iconv"
AppName="gettext + iconv - {#MyVersionShownName}"
AppVerName="gettext {#MyGettextVer} + iconv {#MyIconvVer} - {#MyVersionShownName}"
DefaultDirName={pf}\gettext-iconv
AppPublisher=Michele Locati
AppPublisherURL=https://github.com/mlocati
AppSupportURL=https://github.com/mlocati/gettext-iconv-windows
AppUpdatesURL=https://github.com/mlocati/gettext-iconv-windows/releases
#if MyIs64bit
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
#endif
ChangesEnvironment=yes
Compression=lzma2/max
LicenseFile=setup-data\license.txt
OutputDir=setup
OutputBaseFilename=gettext{#MyGettextVer}-iconv{#MyIconvVer}-{#MyVersionCodeName}

[Files]
Source: "compiled\out-{#MyVersionCodeName}\bin\*.*"; Excludes: "*.sh,autopoint,gettextize"; DestDir: "{app}"
Source: setup-data\license.txt; DestDir: "{app}"

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"

[Tasks]
Name: modifypath; Description: &Add application directory to your environmental path

[Code]
const
    ModPathName = 'modifypath';
    ModPathType = 'system';
function ModPathDir(): TArrayOfString;
begin
    setArrayLength(Result, 1)
    Result[0] := ExpandConstant('{app}');
end;
#include "modpath.iss"
