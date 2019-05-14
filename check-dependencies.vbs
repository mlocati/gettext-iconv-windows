Option Explicit
On Error Goto 0

EnsureCScript

Dim shell, fso, compiledContainerFolder, askKey, p, dumpBin, checkedFolders, compiledFolder

askKey = False
For p = 0 To WScript.Arguments.Count - 1
	If StrComp(WScript.Arguments(p), "/AskKey", 1) = 0 Then
		askKey = True
	End If
Next

Set shell = CreateObject( "WScript.Shell" )
Set fso = CreateObject("Scripting.FileSystemObject")

dumpBin = FindDumpBin()
Set compiledContainerFolder = fso.GetFolder(fso.BuildPath(GetBaseFolder(), "compiled"))

checkedFolders = 0
For Each compiledFolder In compiledContainerFolder.SubFolders
	CheckDependencies compiledFolder
	checkedFolders = checkedFolders + 1
Next
If checkedFolders = 0 Then
	WScript.StdErr.WriteLine "No directories to test found!"
	Quit 1
End If
WScript.StdOut.WriteLine
WScript.StdOut.WriteLine checkedFolders & " folders checked successfully."
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

Sub Quit(ByVal rc)
	If askKey Then
		WScript.StdOut.WriteLine ""
		WScript.StdOut.Write "Press RETURN"
		WScript.StdIn.ReadLine()
	End If
	WScript.Quit rc
End Sub

Function FindDumpBin()
	Dim db, rc
	db = "dumpbin.exe"
	On Error Resume Next
	Err.Clear
	RunCommandLine db & " /?"
	If Err.Number = 0 Or Err.Number = 1100 Then
		Err.Clear
		On Error Goto 0
		FindDumpBin = db
		Exit Function
	End If
	Err.Clear
	On Error Goto 0
	WScript.StdErr.WriteLine "Unable to find dumpbin." & vbNewLine & "Install Visual Studio and add its VC\bin directory to the PATH environment variable"
	Quit 1
End Function

Sub CheckDependencies(folder)
	Dim depList, i, dep, j, importedFunctions
	WScript.StdOut.WriteLine "### Checking dependencies for " & folder.Name
	Set depList = new DepencencyList
	depList.CheckFolder folder, folder
	If depList.Count = 0 Then
		WScript.StdOut.WriteLine "No dependencies found."
	Else
		For i = 0 To depList.Count - 1
			Set dep = depList.Item(i)
			WScript.StdOut.WriteLine "- " & dep.DLLName & " required by"
			For j = 0 To dep.Count - 1
			    WScript.StdOut.WriteLine "  - " & dep.Item(j).DisplayName
				If Not dep.Item(j).IsSystemDLL Then
					WScript.StdOut.WriteLine "    imported functions: " & dep.Item(j).GetImportedFunctions()
				End If
			Next 
		Next
	End If
End Sub

Class DepencencyList
	Private nDependencies
	Private lDependencies()
	Sub Class_Initialize()
		nDependencies = 0
	End Sub
    Public Property Get Count
    	Count = nDependencies
    End Property
    Public Function Item(index)
    	Set Item = lDependencies(index)
    End Function
	Private Function GetDependencyByDLLName(ByVal dllName)
		Dim p, d
		For p = 0 To nDependencies - 1
			If StrComp(lDependencies(p).DLLName, dllName, 1) = 0 Then
				 Set GetDependencyByDLLName = lDependencies(p)
				 Exit Function
			End If
		Next
		Set d = New Dependency
		d.DLLName = dllName
		ReDim Preserve lDependencies(nDependencies)
		Set lDependencies(nDependencies) = d
		nDependencies = nDependencies + 1
		Set GetDependencyByDLLName = d
	End Function
	Public Sub CheckFolder(baseFolder, folder)
		Dim file, subFolder
		For Each file in folder.Files
			CheckFile baseFolder, file
		Next
		For Each subFolder in folder.SubFolders
			CheckFolder baseFolder, subFolder
		Next
		SortDependencies
	End Sub
	Private Sub CheckFile(baseFolder, file)
		Dim p, summary, line, status, rx, dep
		p = InStrRev(file.Name, ".", -1, 0)
		If p < 1 Then
			Exit Sub
		End If
		Select Case LCase(Mid(file.Name, p))
			Case ".exe"
			Case ".dll"
			Case Else
				Exit Sub
		End Select
		Set rx = CreateObject("VBScript.RegExp")
		rx.Global = False
		rx.IgnoreCase = True
		rx.Multiline = False
		rx.Pattern = "^(libgcc_s_sjlj-\d+(-\d+)*|libgcc_s_seh-\d+(-\d+)*)\.dll$"
		If rx.Test(file.Name) Then
			Exit Sub
		End If
		rx.Pattern = "^(advapi32|kernel32|msvcrt|user32|libiconv-\d+(-\d+)*|libintl-\d+(-\d+)*|libtextstyle-\d+(-\d+)*|libgettextlib-\d+(-\d+)*|libgettextsrc-\d+(-\d+)*)\.dll$"
		status = 0
		summary = RunCommandLine(Quote(DumpBin) & " /NOLOGO /DEPENDENTS " & Quote(file.Path))
		For Each line in Split(Replace(summary, vbCrLf, vbLf, 1, -1, 0), vbLf, -1, 0)
			line = Trim(line)
			If line <> "" Then
				Select Case status
					Case 0
						If StrComp("Image has the following dependencies:", line, 0) = 0 Then
							status = 1
						End If
					Case 1
						If StrComp("Summary", line, 0) = 0 Then
							status = 2
							Exit For
						End If
						If Not rx.Test(line) Then
							Set dep = GetDependencyByDLLName(line)
							dep.AddDependency baseFolder, file
						End If
				End Select
			End If
		Next
		If status <> 2 Then
			Err.Raise 1, "Unable to extract dependencies (" & status & ") from:" & vbNewLine & summary
		End If
	End Sub
	Public Sub SortDependencies
	   Dim i, j, n, tmp
	   n = Me.Count
	   For i = 0 To n - 1
	       For j = i + 1 To n - 1
	           If StrComp(lDependencies(i).DLLName, lDependencies(j).DLLName, 1) > 0 Then
	               Set tmp = lDependencies(j)
	               Set lDependencies(j) = lDependencies(i)
	               Set lDependencies(i) = tmp
	           End If
	       Next
	   Next
	   For i = 0 To n - 1
	       lDependencies(i).SortDependentFiles
	   Next
	End Sub
End Class

Class Dependency
    Public DLLName
    Private nDependentFiles
    Private lDependentFiles()
    Sub Class_Initialize()
		nDependentFiles = 0
    End Sub
    Public Sub AddDependency(baseFolder, file)
        If nDependentFiles = 0 Then
            ReDim lDependentFiles(0)
        Else
            ReDim Preserve lDependentFiles(nDependentFiles)
        End If
        Set lDependentFiles(nDependentFiles) = New DependentFile
        lDependentFiles(nDependentFiles).Init Me, baseFolder, file
        nDependentFiles = nDependentFiles + 1
    End Sub
    Public Property Get Count
    	Count = nDependentFiles
    End Property
    Public Function Item(index)
    	Set Item = lDependentFiles(index)
    End Function
    Public Sub SortDependentFiles()
       Dim i, j, n, tmp
       n = Me.Count
       For i = 0 To n - 1
           For j = i + 1 To n - 1
               If StrComp(lDependentFiles(i).DisplayName, lDependentFiles(j).DisplayName, 1) > 0 Then
                   Set tmp = lDependentFiles(j)
                   Set lDependentFiles(j) = lDependentFiles(i)
                   Set lDependentFiles(i) = tmp
               End If
           Next
       Next
    End Sub
End Class
Class DependentFile
	Private myDependency
	Private myBaseFolder
	Private myFile
	Private myImportedFunctions
	Public Sub Init(dep, baseFolder, file)
		Set myDependency = dep
		Set myBaseFolder = baseFolder
		Set myFile = file
		myImportedFunctions = vbNullString
	End Sub
	Public Property Get DisplayName
		DisplayName = Mid(myFile.Path, Len(myBaseFolder.Path) + 2)
	End Property
	Public Property Get IsSystemDLL
		Dim rx
		Set rx = CreateObject("VBScript.RegExp")
		rx.Global = False
		rx.IgnoreCase = False
		rx.Multiline = False
		rx.Pattern = "^(libstdc\+\+-\d+(-\d+)*)\.dll$"
		IsSystemDLL = rx.Test(myFile.Name)
	End Property
	Public Function GetImportedFunctions()
		Dim summary, line, status, rxStart, rxSkip, rxImport, matches, s
		If myImportedFunctions = vbNullString Then
			summary = RunCommandLine(Quote(DumpBin) & " /NOLOGO " & Quote("/IMPORTS:" & myDependency.DLLName) & " " & Quote(myFile.Path))
			status = 0
			Set rxStart = CreateObject("VBScript.RegExp")
			rxStart.Global = False
			rxStart.IgnoreCase = False
			rxStart.Multiline = False
			rxStart.Pattern = "^[A-Fa-f0-9]+ Import Name Table$"
			Set rxSkip = CreateObject("VBScript.RegExp")
			rxSkip.Global = False
			rxSkip.IgnoreCase = False
			rxSkip.Multiline = False
			rxSkip.Pattern = "^0 \w+ "
			Set rxImport = CreateObject("VBScript.RegExp")
			rxImport.Global = False
			rxImport.IgnoreCase = False
			rxImport.Multiline = False
			rxImport.Pattern = "^[A-Fa-f0-9]+ (\w+)$"
			s = ""
			For Each line in Split(Replace(summary, vbCrLf, vbLf, 1, -1, 0), vbLf, -1, 0)
				line = Trim(line)
				If Len(line) > 0 Then
					Select Case status
						Case 0
							If rxStart.Test(line) Then
								status =1
							End If
						Case 1
							If StrComp("Summary", line, 0) = 0 Then
								status = 2
								Exit For
							End If
							If Not rxSkip.Test(line) Then
								Set matches = rxImport.Execute(line)
								If matches.Count = 0 Then
									Err.Raise 1, "Failed to parse imported function from """ & line & """ in " & vbNewLine & summary
								End If
								If Len(s) > 0 Then
									s = s & ", "
								End If
								s = s & matches(0).SubMatches(0)
							End If
					End Select
				End If
			Next
			If status <> 2 Then
				Err.Raise 1, "Failed to parse imported functions from:" & vbNewLine & summary
			End If
			myImportedFunctions = s 
		End If
		GetImportedFunctions = myImportedFunctions
	End Function
End Class

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
		Err.Raise process.ExitCode, s
	End If
	If process.StdOut.AtEndOfStream Then
		RunCommandLine = ""
	Else
		RunCommandLine = Trim(process.StdOut.ReadAll)
	End If
End Function
