Option Explicit
On Error Goto 0

Const ForReading = 1
Const TemporaryFolder = 2

EnsureCScript

Dim shell, fso, temp, compiledContainerFolder, compiledFolder, testedFolders, p, askKey

askKey = False
For p = 0 To WScript.Arguments.Count - 1
	If StrComp(WScript.Arguments(p), "/AskKey", 1) = 0 Then
		askKey = True
	End If
Next

Set shell = CreateObject( "WScript.Shell" )
Set fso = CreateObject("Scripting.FileSystemObject") 
Set temp = New cTemporaryFolder
Set compiledContainerFolder = fso.GetFolder(fso.BuildPath(GetBaseFolder(), "compiled"))
testedFolders = 0
For Each compiledFolder In compiledContainerFolder.SubFolders
	RunTests compiledFolder
	testedFolders = testedFolders + 1
Next
If testedFolders = 0 Then
	WScript.StdErr.WriteLine "No directories to test found!"
	Quit 1
End If
WScript.StdOut.WriteLine
WScript.StdOut.WriteLine testedFolders & " folders tested successfully."
Quit 0

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
Function GetBaseFolder()
	Dim s, p
	s = WScript.ScriptFullName
	p = InStrRev(s, "\", -1, 0)
	If p > 0 Then
		s = Left(s, p - 1)
	End If
	GetBaseFolder = s
End Function

Class cTemporaryFolder
	Private myPath
	Public Property Get Path
		Path = myPath
	End Property
	Private myIndex
	Private Sub Class_Initialize()
		Dim parentDir, unexistingDir
		myIndex = 0
		myPath = ""
		parentDir = fso.GetSpecialFolder(TemporaryFolder)
		Do
			unexistingDir = fso.BuildPath(parentDir, fso.GetTempName())
		Loop While fso.FolderExists(unexistingDir) Or fso.FileExists(unexistingDir)
		fso.CreateFolder unexistingDir
		myPath = unexistingDir
	End Sub
	Private Sub Class_Terminate()
		If myPath <> "" Then
			fso.DeleteFolder myPath
			myPath = ""
		End If
	End Sub
	Public Function GetNewFilename(ByVal extension)
		GetNewFilename = fso.BuildPath(myPath, "file-" & myIndex & "." & extension)
		myIndex = myIndex + 1
	End Function
End Class

Sub RunTests(folder)
	Dim binFolder
	Dim phpFile, potFile, poFile, translatedPoFile, moFile, qtFile, decompiledPoFile, decompiledPoFileCP1252, batFile
	Dim f, s, batStart, batEnd
	WScript.StdOut.WriteLine "### Testing " & folder.Name
	batStart = ""
	batStart = batStart & "@echo off" & vbCrLf
	batStart = batStart & "setlocal" & vbCrLf
	batStart = batStart & "for /f ""tokens=1* delims=="" %%a in ('set') do (" & vbCrLf
	batStart = batStart & "	set %%a=" & vbCrLf
	batStart = batStart & ")" & vbCrLf
	batStart = batStart & "set GETTEXTIOENCODING=UTF-8" & vbCrLf
	batStart = batStart & "set GETTEXTCLDRDIR=" & fso.BuildPath(fso.BuildPath(folder.Path, "lib"), "gettext") & vbCrLf
	batEnd = ""
	batEnd = batEnd & "if errorlevel 1 (" & vbCrLf
	batEnd = batEnd & "	endlocal" & vbCrLf
	batEnd = batEnd & "	exit /b 1" & vbCrLf
	batEnd = batEnd & ")" & vbCrLf
	batEnd = batEnd & "endlocal" & vbCrLf
	batEnd = batEnd & "exit /b 0" & vbCrLf

	binFolder = fso.BuildPath(folder.Path, "bin")
	WScript.StdOut.Write " - creating sample php file... "
	phpFile = temp.GetNewFilename("php")
	Set f = fso.CreateTextFile(phpFile, False, False)
	f.Write "<?php" & vbLf & "echo t('This is a test');" & vbLf
	f.Close
	WScript.StdOut.WriteLine "done."
	WScript.StdOut.Write " - generating pot file with xgettext..."
	batFile = temp.GetNewFilename("bat")
	potFile = temp.GetNewFilename("pot")
	Set f = fso.CreateTextFile(batFile, False, False)
	f.Write batStart
	f.WriteLine Quote(fso.BuildPath(binFolder, "xgettext.exe")) & " --output-dir=" & Quote(fso.GetParentFolderName(potFile)) & " --output=" & Quote(fso.GetFileName(potFile)) & " --force-po --language=PHP --from-code=UTF-8 --add-comments=i18n --keyword=t " & Quote(phpFile)
	f.Write batEnd
	f.Close
	RunFile batFile
	WScript.StdOut.WriteLine "done."
	batFile = temp.GetNewFilename("bat")
	poFile = temp.GetNewFilename("po")
	WScript.StdOut.Write " - Creating po file with msginit... "
	Set f = fso.CreateTextFile(batFile, False, False)
	f.Write batStart
	f.WriteLine Quote(fso.BuildPath(binFolder, "msginit.exe")) & " --input=" & Quote(potFile) & " --output-file=" & Quote(poFile) & " --locale=bs"
	f.Write batEnd
	f.Close
	RunFile batFile
	WScript.StdOut.WriteLine "done."
	WScript.StdOut.Write " - Checking if CLDR rules where used... "
	Set f = fso.OpenTextFile(poFile, ForReading, False, 0)
	s = f.ReadAll
	f.Close
	Set f = Nothing
	If InStr(1, s, "nplurals=3") < 1 Then
		WScript.StdErr.WriteLine "NOT FOUND!"
		Quit 1
	End If
	WScript.StdOut.WriteLine "found."
	WScript.StdOut.Write " - Filling translation... "
	s = Replace(s, "msgid ""This is a test""" & vbLf & "msgstr """"", "msgid ""This is a test""" & vbLf & "msgstr ""Questo " & Chr(195) & Chr(168) & " un test""")
	translatedPoFile = temp.GetNewFilename("po")
	Set f = fso.CreateTextFile(translatedPoFile, False, False)
	f.Write s
	f.Close
	WScript.StdOut.WriteLine "done."
	WScript.StdOut.Write " - Creating mo file with msgfmt... "
	batFile = temp.GetNewFilename("bat")
	moFile = temp.GetNewFilename("mo")
	Set f = fso.CreateTextFile(batFile, False, False)
	f.Write batStart
	f.WriteLine Quote(fso.BuildPath(binFolder, "msgfmt.exe")) & " --output-file=" & Quote(moFile) & " " & Quote(translatedPoFile)
	f.Write batEnd
	f.Close
	RunFile batFile
	WScript.StdOut.WriteLine "done."
	WScript.StdOut.Write " - Creating tcl file with msgfmt... "
	batFile = temp.GetNewFilename("bat")
	Set f = fso.CreateTextFile(batFile, False, False)
	f.Write batStart
	f.WriteLine Quote(fso.BuildPath(binFolder, "msgfmt.exe")) & " --tcl --locale=bs -d " & Quote(fso.GetParentFolderName(translatedPoFile)) & " " & Quote(translatedPoFile)
	f.Write batEnd
	f.Close
	RunFile batFile
	WScript.StdOut.WriteLine "done."
	WScript.StdOut.Write " - Creating qt file with msgfmt... "
	batFile = temp.GetNewFilename("bat")
	qtFile = temp.GetNewFilename("qt")
	Set f = fso.CreateTextFile(batFile, False, False)
	f.Write batStart
	f.WriteLine Quote(fso.BuildPath(binFolder, "msgfmt.exe")) & " --qt --output-file=" & Quote(qtFile) & " " & Quote(translatedPoFile)
	f.Write batEnd
	f.Close
	RunFile batFile
	WScript.StdOut.WriteLine "done."
	WScript.StdOut.Write " - Decompiling mo file with msgunfmt... "
	batFile = temp.GetNewFilename("bat")
	decompiledPoFile = temp.GetNewFilename("po")
	Set f = fso.CreateTextFile(batFile, False, False)
	f.Write batStart
	f.WriteLine Quote(fso.BuildPath(binFolder, "msgunfmt.exe")) & " --output-file=" & Quote(decompiledPoFile) & " " & Quote(moFile)
	f.Write batEnd
	f.Close
	RunFile batFile
	WScript.StdOut.WriteLine "done."
	WScript.StdOut.Write " - Converting charset with msgconv... "
	batFile = temp.GetNewFilename("bat")
	decompiledPoFileCP1252 = temp.GetNewFilename("po")
	Set f = fso.CreateTextFile(batFile, False, False)
	f.Write batStart
	f.WriteLine Quote(fso.BuildPath(binFolder, "msgconv.exe")) & " --to-code=CP1252 --output-file=" & Quote(decompiledPoFileCP1252) & " " & Quote(decompiledPoFile)
	f.Write batEnd
	f.Close
	RunFile batFile
	Set f = fso.OpenTextFile(decompiledPoFileCP1252, ForReading, False, 0)
	s = f.ReadAll
	f.Close
	Set f = Nothing
	If InStr(1, s, Chr(232)) < 1 Then
		WScript.StdErr.WriteLine "CONVERSION FAILED!"
		Quit 1
	End If
	WScript.StdOut.WriteLine "done."
End Sub
Sub RunFile(ByVal path)
	Dim process, s
	Set process = shell.Exec(path)
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
End Sub
Sub Quit(ByVal rc)
	If askKey Then
		WScript.StdOut.WriteLine ""
		WScript.StdOut.Write "Press RETURN"
		WScript.StdIn.ReadLine()
	End If
	WScript.Quit rc
End Sub
