// File used by the create-installer.ps1 script

#include "create-installer.isi"
// Must have:
// #define MyVersionShownName "<shared|static> (<32|64> bit)"
// #define MyVersionCodeName "<shared|static>-<32|64>"
// #define MyIs64bit <true|false>
// #define MyGettextVer "<gettext version>"
// #define MyIconvVer "<iconv version>"
// #define MyCompiledFolderPath "<path>"
// #define MyOutputFolderPath "<path>"
// #define MyLanguages "Entries of the [Languages] section"

[Setup]
AppId=gettext-iconv
AppName="gettext + iconv"
AppVerName="gettext {#MyGettextVer} + iconv {#MyIconvVer} - {#MyVersionShownName}"
WizardStyle=modern dynamic
DefaultDirName={autopf}\gettext-iconv
AppPublisher=Michele Locati
AppPublisherURL=https://github.com/mlocati
AppSupportURL=https://github.com/mlocati/gettext-iconv-windows/issues
AppUpdatesURL=https://github.com/mlocati/gettext-iconv-windows/releases
#if MyIs64bit
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
#endif
ChangesEnvironment=WizardIsTaskSelected('modifypath') or WizardIsTaskSelected('setenvcldr')
PrivilegesRequiredOverridesAllowed=commandline dialog
Compression=lzma2/max
LicenseFile={#MyCompiledFolderPath}\license.txt
OutputDir={#MyOutputFolderPath}
OutputBaseFilename=gettext{#MyGettextVer}-iconv{#MyIconvVer}-{#MyVersionCodeName}
VersionInfoProductTextVersion=1.0
ShowLanguageDialog=auto

[Files]
Source: "{#MyCompiledFolderPath}\*.*"; DestDir: "{app}"; Flags: recursesubdirs

[Tasks]
Name: modifypath; Description: "{cm:ModifyPath}"
Name: setenvcldr; Description: "{cm:SetEnvCLDR}"

[Languages]
{#MyLanguages}


[Code]
#ifdef UNICODE
	#define AW "W"
#else
	#define AW "A"
#endif

const
	TASK_MODPATH = 'modifypath';
	TASK_SETENVCLDR = 'setenvcldr';
	TASK_MODPATH_TYPE = 'system';
	TASK_SETENVCLDR_NAME = 'GETTEXTCLDRDIR';

function SetEnvironmentVariable(lpName: string; lpValue: string): BOOL;
	external 'SetEnvironmentVariable{#AW}@kernel32.dll stdcall';
function SetEnvironmentVariableInt(lpName: string; lpValue: Integer): BOOL;
	external 'SetEnvironmentVariable{#AW}@kernel32.dll stdcall';

function ModPathDir(): TArrayOfString;
begin
	setArrayLength(Result, 1)
	Result[0] := ExpandConstant('{app}\bin');
end;

function EnvCLDRDir(): String;
begin
	Result := ExpandConstant('{app}\share\gettext\cldr');
end;


// patched modpath.iss

// Split a string into an array using passed delimeter
procedure SetEnvCLDR();
var
	envValue: String;
	regroot:	Integer;
	regpath:	String;
begin
	if IsAdminInstallMode then begin
		regroot := HKEY_LOCAL_MACHINE;
		regpath := 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';
	end else begin
		regroot := HKEY_CURRENT_USER;
		regpath := 'Environment';
	end;
	if (IsUninstaller() = false) then begin
		envValue := EnvCLDRDir();
		SetEnvironmentVariable(TASK_SETENVCLDR_NAME, envValue);
		RegWriteStringValue(regroot, regpath, TASK_SETENVCLDR_NAME, envValue);
	end else begin
		SetEnvironmentVariableInt(TASK_SETENVCLDR_NAME, 0);
		RegDeleteValue(regroot, regpath, TASK_SETENVCLDR_NAME);
	end;
end;

procedure ModPath();
var
	oldpath:	String;
	newpath:	String;
	updatepath:	Boolean;
	pathArr:	TArrayOfString;
	i, d:		Integer;
	pathdir:	TArrayOfString;
	regroot:	Integer;
	regpath:	String;

begin
	// Get constants from main script and adjust behavior accordingly
	if IsAdminInstallMode then begin
		regroot := HKEY_LOCAL_MACHINE;
		regpath := 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';
	end else begin
		regroot := HKEY_CURRENT_USER;
		regpath := 'Environment';
	end;

	// Get array of new directories and act on each individually
	pathdir := ModPathDir();
	for d := 0 to GetArrayLength(pathdir)-1 do begin
		updatepath := true;

    // Get current path, split into an array
    RegQueryStringValue(regroot, regpath, 'Path', oldpath);
    oldpath := oldpath + ';';
    i := 0;

    while (Pos(';', oldpath) > 0) do begin
      SetArrayLength(pathArr, i+1);
      pathArr[i] := Copy(oldpath, 0, Pos(';', oldpath)-1);
      oldpath := Copy(oldpath, Pos(';', oldpath)+1, Length(oldpath));
      i := i + 1;

      // Check if current directory matches app dir
      if pathdir[d] = pathArr[i-1] then begin
        // if uninstalling, remove dir from path
        if IsUninstaller() = true then begin
          continue;
        // if installing, flag that dir already exists in path
        end else begin
          updatepath := false;
        end;
      end;

      // Add current directory to new path
      if i = 1 then begin
        newpath := pathArr[i-1];
      end else begin
        newpath := newpath + ';' + pathArr[i-1];
      end;
    end;

    // Append app dir to path if not already included
    if (IsUninstaller() = false) AND (updatepath = true) then
      newpath := newpath + ';' + pathdir[d];
    // Write new path
    RegWriteStringValue(regroot, regpath, 'Path', newpath);
	end;
end;

// Split a string into an array using passed delimeter
procedure MPExplode(var Dest: TArrayOfString; Text: String; Separator: String);
var
	i: Integer;
begin
	i := 0;
	repeat
		SetArrayLength(Dest, i+1);
		if Pos(Separator,Text) > 0 then	begin
			Dest[i] := Copy(Text, 1, Pos(Separator, Text)-1);
			Text := Copy(Text, Pos(Separator,Text) + Length(Separator), Length(Text));
			i := i + 1;
		end else begin
			Dest[i] := Text;
			Text := '';
		end;
	until Length(Text)=0;
end;


procedure CurStepChanged(CurStep: TSetupStep);
begin
	if CurStep = ssPostInstall then begin
		if WizardIsTaskSelected(TASK_MODPATH) then
			ModPath();
		if WizardIsTaskSelected(TASK_SETENVCLDR) then
			SetEnvCLDR();
	end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
	aSelectedTasks:	TArrayOfString;
	i:				Integer;
	regpath:		String;
	regstring:		String;
	appid:			String;
begin
	// only run during actual uninstall
	if CurUninstallStep = usUninstall then begin
		// get list of selected tasks saved in registry at install time
		appid := '{#emit SetupSetting("AppId")}';
		if appid = '' then appid := '{#emit SetupSetting("AppName")}';
		regpath := ExpandConstant('Software\Microsoft\Windows\CurrentVersion\Uninstall\'+appid+'_is1');
		RegQueryStringValue(HKLM, regpath, 'Inno Setup: Selected Tasks', regstring);
		if regstring = '' then RegQueryStringValue(HKCU, regpath, 'Inno Setup: Selected Tasks', regstring);

		// check each task; if matches modpath taskname, trigger patch removal
		if regstring <> '' then begin
			MPExplode(aSelectedTasks, regstring, ',');
			if GetArrayLength(aSelectedTasks) > 0 then begin
				for i := 0 to GetArrayLength(aSelectedTasks)-1 do begin
					if comparetext(aSelectedTasks[i], TASK_MODPATH) = 0 then
						ModPath();
					if comparetext(aSelectedTasks[i], TASK_SETENVCLDR) = 0 then
						SetEnvCLDR();
				end;
			end;
		end;
	end;
end;
