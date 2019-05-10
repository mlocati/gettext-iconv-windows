Option Explicit
On Error Goto 0

Const ForReading = 1

EnsureCScript

Dim shell, fso, baseFolder, exe7Zip, exeInnoSetup, compiledFolders(), outputFolder, p, askKey

askKey = False
For p = 0 To WScript.Arguments.Count - 1
	If StrComp(WScript.Arguments(p), "/AskKey", 1) = 0 Then
		askKey = True
	End If
Next

Set shell = CreateObject( "WScript.Shell" )
Set fso = CreateObject("Scripting.FileSystemObject") 

LookForApps
GetCompiledFolders
Set outputFolder = fso.GetFolder(fso.BuildPath(GetBaseFolder(), "setup"))

CreateZIPs
CreateSetups

Quit 0

Function GetBaseFolder()
	Dim s, p
	s = WScript.ScriptFullName
	p = InStrRev(s, "\", -1, 0)
	If p > 0 Then
		s = Left(s, p - 1)
	End If
	GetBaseFolder = s
End Function

Sub EnsureCScript()
	Dim s, p, shell, cmdLine
	s = WScript.FullName
	p = InStrRev(s, "\", -1, 0)
	If p > 0 Then
		s = Mid(s, p + 1)
	End If
	If StrComp(s, "cscript.exe", 1) <> 0 Then
		Set shell = WScript.CreateObject("WScript.Shell")
		cmdLine = "CScript.exe //NoLogo " & Quote(WScript.ScriptFullName)
		cmdLine = cmdLine & " /AskKey"
		For p = 0 To WScript.Arguments.Count - 1
			cmdLine = cmdLine & " " & Quote(WScript.Arguments(p))
		Next
		shell.Run cmdLine
		Set shell = Nothing
		WScript.Quit
	End If
End Sub

Function Quote(value)
	Dim doQuote, s
	s = "" & value
	doQuote = False
	If InStr(1, s, " ", 0) > 0 Then
		doQuote = True
		If Len(s) >= 2 Then
			If (Left(s, 1) = """") And (Right(s, 1) = """") Then
				doQuote = False
			End If
		End If
	End If
	If doQuote Then
		Quote = """" & s & """"
	Else
		Quote = s
	End If
End Function

Sub LookForApps()
	Dim drive, programsFolder, appsFolder, appFolder
	exe7Zip = ""
	exeInnoSetup = ""
	For Each drive in fso.Drives
		If drive.DriveType = 2 And drive.IsReady And drive.DriveLetter <> "" Then
			For Each programsFolder In fso.GetFolder(drive.DriveLetter + ":\").SubFolders
				If InStr(1, programsFolder.Name, "Program", 1) > 0 Then
					On Error Resume Next
					Set appsFolder = programsFolder.SubFolders
					If Err.Number <> 0 Then
						Set appsFolder = Nothing
						Err.Clear
					End If
					If IsObject(appsFolder) Then
						For Each appFolder In appsFolder
							If Err.Number <> 0 Then
								Err.Clear
								Exit For
							End If
							If exe7Zip = "" Then
								If InStr(1, appFolder.Name, "7", 1) > 0 And InStr(1, appFolder.Name, "Zip", 1) > 0 Then
									exe7Zip = fso.BuildPath(appFolder.Path, "7z.exe")
									If Not fso.FileExists(exe7Zip) Then
										exe7Zip = ""
									End If
								End If
							End If
							If exeInnoSetup = "" Then
								If InStr(1, appFolder.Name, "Inno", 1) > 0 And InStr(1, appFolder.Name, "Setup", 1) > 0 Then
									exeInnoSetup = fso.BuildPath(appFolder.Path, "ISCC.exe")
									If Not fso.FileExists(exeInnoSetup) Then
										exeInnoSetup = ""
									End If
								End If
							End If
							If exe7Zip <> "" And exeInnoSetup <> "" Then
								Err.Clear
								On Error Goto 0
								Exit Sub
							End If
						Next
					End If
				End If
			Next
		End If
	Next
	Err.Clear
	On Error Goto 0
	WScript.Echo "Failed to locate 7-zip or InnoSetup"
	Quit 1
End Sub

Sub CreateZIPs()
	Dim i, zipName, origDir, rc
	WScript.Echo "Creating zip files"
	origDir = shell.CurrentDirectory
	For i = LBound(compiledFolders) To UBound(compiledFolders)
		WScript.Echo " - " & compiledFolders(i).Bits & "-bits " & compiledFolders(i).Link
		zipName = fso.BuildPath(outputFolder.Path, compiledFolders(i).BaseName & ".zip")
		If fso.FileExists(zipName) Then
			fso.DeleteFile zipName
		End If
		On Error Resume Next
		shell.CurrentDirectory = compiledFolders(i).Folder.Path
		If Err.Number = 0 Then
			rc = shell.Run(Quote(exe7Zip) & " a -r -tzip -mx=7 " & Quote(zipName) & " *", 0, True)
			If rc <> 0 Then
				Err.Raise rc, "7-zip failed!"
			End If
		End If
		If Err.Number <> 0 Then
			WScript.Echo "ERROR! " & Err.Description
			shell.CurrentDirectory = origDir
			Err.Clear
			On Error Goto 0
			Quit 1
		End If
	Next
	On Error Goto 0
	shell.CurrentDirectory = origDir
End Sub

Sub CreateSetups()
	Dim i, scriptName, scriptText, tempName, rc, file
	WScript.Echo "Creating setup files"
	scriptName = fso.BuildPath(fso.BuildPath(GetBaseFolder(), "setup-data"), "script.iss")
	Set file = fso.OpenTextFile(scriptName, ForReading)
	scriptText = file.ReadAll
	file.Close
	Set file = Nothing
	tempName = fso.GetTempName()
	For i = LBound(compiledFolders) To UBound(compiledFolders)
		WScript.Echo " - " & compiledFolders(i).Bits & "-bits " & compiledFolders(i).Link
		Set file = fso.CreateTextFile(tempName, True, False)
		file.Write "#define MyVersionShownName """ & compiledFolders(i).Link & " (" & compiledFolders(i).Bits & " bit)""" & vbCrLf
		file.Write "#define MyVersionCodeName """ & compiledFolders(i).Link & "-" & compiledFolders(i).Bits & """" & vbCrLf
		If compiledFolders(i).Bits = "64" Then
			file.Write "#define MyIs64bit true" & vbCrLf
		Else
			file.Write "#define MyIs64bit false" & vbCrLf
		End If
		file.Write "#define MyGettextVer """ & compiledFolders(i).GettextVersion & """" & vbCrLf
		file.Write "#define MyIconvVer """ & compiledFolders(i).IconvVersion & """" & vbCrLf
		file.Write "#define MyCompiledFolderPath """ & compiledFolders(i).Folder.Path & """"
		file.Write vbCrLf & vbCrLf & vbCrLf & scriptText
		file.Close
		Set file = Nothing
		rc = shell.Run(Quote(exeInnoSetup) & " /O" & Quote(outputFolder.Path) & " /F" & Quote(compiledFolders(i).BaseName) & " " & Quote(tempName), 0, True)
		fso.DeleteFile tempName
		If rc <> 0 Then
			WScript.Echo "ERROR! " & Err.Description
			Quit 1
		End If
	Next
End Sub

Sub GetCompiledFolders()
	Dim folder, link, bits, numResult
	numResult = 0
	For Each folder In fso.GetFolder(fso.BuildPath(GetBaseFolder(), "compiled")).SubFolders
		If InStr(1, folder.Name, "shared", 1) > 0 Then
			link = "shared"
		ElseIf InStr(1, folder.Name, "static", 1) > 0 Then
			link = "static"
		Else
			link = ""
		End If
		If InStr(1, folder.Name, "32", 1) > 0 Then
			bits = "32"
		ElseIf InStr(1, folder.Name, "64", 1) > 0 Then
			bits = "64"
		Else
			bits = ""
		End If
		If link <> "" And bits <> "" Then
			If numResult = 0 Then
				ReDim compiledFolders(0)
			Else
				ReDim Preserve compiledFolders(numResult)
			End If
			Set compiledFolders(numResult) = new CompiledFolder
			Set compiledFolders(numResult).Folder = folder
			compiledFolders(numResult).Link = link
			compiledFolders(numResult).Bits = bits
			compiledFolders(numResult).IconvVersion = GetIconvVersion(folder)
			compiledFolders(numResult).GettextVersion = GetGettextVersion(folder)
			numResult = numResult + 1
		End If
	Next
	If numResult = 0 Then
		WScript.Echo "No compiled folders found"
		Quit 1
	End If
End Sub

Class CompiledFolder
	Public Folder
	Public Link
	Public Bits
	Public IconvVersion
	Public GettextVersion
	Public Property Get BaseName
		BaseName = "gettext" & Me.GettextVersion & "-iconv" & Me.IconvVersion & "-" & Me.Link & "-" & Me.Bits
	End Property
End Class

Sub Quit(ByVal rc)
	If askKey Then
		WScript.StdOut.WriteLine ""
		WScript.StdOut.Write "Press RETURN"
		WScript.StdIn.ReadLine()
	End If
	WScript.Quit rc
End Sub

Function GetIconvVersion(folder)
	Dim exePath, exeOutput, rx, matches
	exePath = fso.BuildPath(fso.BuildPath(folder.Path, "bin"), "iconv.exe")
	exeOutput = RunCommandLine(Quote(exePath) & " --version")
	Set rx  = CreateObject("VBScript.RegExp")
	rx.Pattern = "GNU libiconv (\d[\w\d\.\-]*)"
	Set matches = rx.Execute(exeOutput)
	If matches.Count <> 1 Then
		Err.Raise 1, "Unable to extract the iconv version from" & vbNewLine & exeOutput
	End If
	GetIconvVersion = matches.Item(0).SubMatches(0)
End Function

Function GetGettextVersion(folder)
	Dim exePath, exeOutput, rx, matches
	exePath = fso.BuildPath(fso.BuildPath(folder.Path, "bin"), "xgettext.exe")
	exeOutput = RunCommandLine(Quote(exePath) & " --version")
	Set rx  = CreateObject("VBScript.RegExp")
	rx.Pattern = "xgettext(?:.exe)? \(GNU gettext-tools\) (\d[\w\d\.\-]*)"
	Set matches = rx.Execute(exeOutput)
	If matches.Count <> 1 Then
		Err.Raise 1, "Unable to extract the iconv version from" & vbNewLine & exeOutput
	End If
	GetGettextVersion = matches.Item(0).SubMatches(0)
End Function

Function RunCommandLine(ByVal commandLine)
	Dim process, s
	Set process = shell.Exec(commandLine)
	Do While process.Status = 0
		WScript.Sleep 100
	Loop
	If process.ExitCode <> 0 Then
		If Not process.StdErr.AtEndOfStream Then
			s = Trim(process.StdErr.ReadAll)
		End If
		If s = "" And Not process.StdOut.AtEndOfStream Then
			s = Trim(process.StdOut.ReadAll)
		End If
		If s <> "" Then
			s = "Error: " & s
		Else
			s = "Unknown error (code: " & process & ")"
		End If
		WScript.StdErr.WriteLine s
		Quit 1
	End If
	If process.StdOut.AtEndOfStream Then
		RunCommandLine = ""
	Else
		RunCommandLine = Trim(process.StdOut.ReadAll)
	End If
End Function
