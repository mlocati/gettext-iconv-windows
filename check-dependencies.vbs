Option Explicit
On Error Goto 0

EnsureCScript

Dim shell, fso, compiledContainerFolder, askKey, p, dumpBin, checkedFolders, compiledFolder

Const FILETYPE_NOT_BINARY = 0
Const FILETYPE_BUILT_EXE = 1
Const FILETYPE_BUILT_DLL = 2
Const FILETYPE_MINGW_DLL = 3
Const FILETYPE_WINDOWS_DLL = 4

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
    Dim db, rc, env, rx, matches, dbFolder, oShell, value, p, oFolder
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
    Set rx = CreateObject("VBScript.RegExp")
    rx.IgnoreCase = False
    rx.Pattern = "^VS(\d+)COMNTOOLS=(.*)$"
    For Each env in shell.Environment("SYSTEM")
        Set matches = rx.Execute(env)
        If matches.Count = 1 Then
            If matches(0).SubMatches(0) <> "110" Then
                dbFolder = matches(0).SubMatches(1)
                If Right(dbFolder, 1) <> "\" Then
                    dbFolder = dbFolder & "\"
                End If
                db = dbFolder & "..\..\VC\bin\dumpbin.exe"
                If fso.FileExists(db) Then
                    FindDumpBin = db
                    Exit Function
                End If
            End If
        End If
    Next
    Set oShell = CreateObject("WScript.Shell")
    On Error Resume Next
    Err.Clear
    value = oShell.RegRead("HKEY_CLASSES_ROOT\VisualStudio.Solution\CLSID\")
    If Err.Number <> 0 Then
        value = ""
        Err.Clear
    End If
    If ("" & value) <> "" Then
        value = oShell.RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Classes\WOW6432Node\CLSID\" & value & "\LocalServer32\")
        If Err.Number <> 0 Then
            value = ""
            Err.Clear
        End If
    End If
    On Error Goto 0
    If ("" & value) <> "" Then
        p = InStr(value, """")
        If p = 1 Then
            value = Mid(value, 2)
        End If
        Set rx = CreateObject("VBScript.RegExp")
        rx.IgnoreCase = True
        rx.Pattern = "^(.*)\\common\d*\\ide\\devenv\.exe"
        Set matches = rx.Execute(value)
        If matches.Count = 1 Then
            value = matches(0).SubMatches(0) & "\VC\Tools\MSVC"
            If fso.FolderExists(value) Then
                For Each oFolder In fso.GetFolder(value).SubFolders
                    value = oFolder.Path & "\bin\Hostx64\x64\dumpbin.exe"
                    rem value = oFolder.Path & "\bin\Hostx86\x86\dumpbin.exe"
                    If fso.FileExists(value) Then
                        FindDumpBin = value
                        Exit Function
                    End If
                Next
            End If
        End If
    End If
    WScript.StdErr.WriteLine "Unable to find dumpbin." & vbNewLine & "Install Visual Studio and add its VC\bin directory to the PATH environment variable"
    Quit 1
End Function

Sub CheckDependencies(folder)
    Dim depList, i, dep, j, importedFunctions, s
    WScript.StdOut.WriteLine "### Checking dependencies for " & folder.Name
    Set depList = New DepencencyList
    depList.CheckFolder folder, folder
    Set s = depList.GetMissingRequiredDLLList()
    If s.Count > 0 Then
        WScript.StdErr.WriteLine "Missing DLLs: " & s.Implode(", ")
        Quit 1
    End If
    Set s = depList.GetUnneededDLLList()
    If s.Count > 0 Then
        WScript.StdErr.WriteLine "Unneeded DLLs: " & s.Implode(", ")
        Quit 1
    End If
    If depList.DependenciesCount = 0 Then
        WScript.StdOut.WriteLine "No dependencies found."
    Else
        For i = 0 To depList.DependenciesCount - 1
            Set dep = depList.DependencyItem(i)
            WScript.StdOut.WriteLine "- " & dep.DLLName & " required by"
            For j = 0 To dep.Count - 1
                WScript.StdOut.WriteLine "  - " & dep.Item(j).DisplayName
                Select Case dep.Item(j).FileType
                    Case FILETYPE_MINGW_DLL
                    Case FILETYPE_WINDOWS_DLL
                    Case Else
                        WScript.StdOut.WriteLine "    imported functions: " & dep.Item(j).GetImportedFunctions().Implode(", ")
                End Select
            Next
        Next
    End If
End Sub

Class DepencencyList
    Private nDependencies
    Private lDependencies()
    Private dllFoundAll
    Private dllFoundMinGW
    Private dllRequired
    Sub Class_Initialize()
        nDependencies = 0
        Set dllFoundAll = New ValueList
        dllFoundAll.IsCaseInsensitiveStringList = True
        Set dllFoundMinGW = New ValueList
        dllFoundMinGW.IsCaseInsensitiveStringList = True
        Set dllRequired = New ValueList
        dllRequired.IsCaseInsensitiveStringList = True
    End Sub
    Public Property Get DependenciesCount
        DependenciesCount = nDependencies
    End Property
    Public Function GetMissingRequiredDLLList()
        Dim i, r
        Set r = New ValueList
        For i = 0 To dllRequired.Count - 1
            If Not dllFoundAll.Contains(dllRequired.Item(i)) Then
                r.Add dllRequired.Item(i)
            End If
        Next
        r.Sort
        Set GetMissingRequiredDLLList = r
    End Function
    Public Function GetUnneededDLLList()
        Dim i, r
        Set r = New ValueList
        For i = 0 To dllFoundMinGW.Count - 1
            If Not dllRequired.Contains(dllFoundMinGW.Item(i)) Then
                r.Add dllFoundMinGW.Item(i)
            End If
        Next
        r.Sort
        Set GetUnneededDLLList = r
    End Function
    Public Function DependencyItem(index)
        Set DependencyItem = lDependencies(index)
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
        Dim fileType, dependencyFileType
        fileType = GetFileType(file.Name)
        Select Case fileType
            Case FILETYPE_NOT_BINARY
                Exit Sub
            Case FILETYPE_MINGW_DLL
                dllFoundAll.Add file.Name
                dllFoundMinGW.Add file.Name
            Case FILETYPE_BUILT_DLL
                dllFoundAll.Add file.Name
            Case FILETYPE_BUILT_EXE
            Case Else
                WScript.StdErr.WriteLine "Unexpected file: " & file.Path
                Quit 1
        End Select
        Dim summary, line, status, dep
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
                        dependencyFileType = GetFileType(line)
                        Select Case dependencyFileType
                            Case FILETYPE_BUILT_DLL, FILETYPE_MINGW_DLL
                                dllRequired.AddIfNotThere line
                        End Select
                        If dependencyFileType <> FILETYPE_WINDOWS_DLL And dependencyFileType <> FILETYPE_BUILT_DLL Then
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
        n = Me.DependenciesCount
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
    Private myFileType
    Public Sub Init(dep, baseFolder, file)
        Set myDependency = dep
        Set myBaseFolder = baseFolder
        Set myFile = file
        Set myImportedFunctions = Nothing
        myFileType = -1
    End Sub
    Public Property Get DisplayName
        DisplayName = Mid(myFile.Path, Len(myBaseFolder.Path) + 2)
    End Property
    Public Property Get FileType
        If myFileType = -1 Then
            myFileType = GetFileType(myFile.Name)
        End If
        FileType = myFileType
    End Property
    Public Function GetImportedFunctions()
        Dim summary, line, status, rxStart, rxSkip, rxImport, matches, r
        If myImportedFunctions Is Nothing Then
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
            Set r = New ValueList
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
                                r.Add matches(0).SubMatches(0)
                            End If
                    End Select
                End If
            Next
            If status <> 2 Then
                Err.Raise 1, "Failed to parse imported functions from:" & vbNewLine & summary
            End If
            r.Sort
            Set myImportedFunctions = r
        End If
        Set GetImportedFunctions = myImportedFunctions
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

Function GetFileType(ByVal binName)
    Dim rx
    Set rx = CreateObject("VBScript.RegExp")
    rx.IgnoreCase = True
    rx.Pattern = ".\.exe$"
    If rx.Test(binName) Then
        GetFileType = FILETYPE_BUILT_EXE
        Exit Function
    End If
    rx.Pattern = ".\.dll$"
    If Not rx.Test(binName) Then
        GetFileType = FILETYPE_NOT_BINARY
        Exit Function
    End If
    rx.Pattern = "^(libcharset|libgettextlib|libgettextpo|libgettextsrc|libiconv|libintl|libtextstyle)-\d+(-\d+)*\.dll"
    If rx.Test(binName) Then
        GetFileType = FILETYPE_BUILT_DLL
        Exit Function
    End If
    rx.Pattern = "^(libgcc_s_seh|libgcc_s_sjlj|libstdc\+\+|libwinpthread)-\d+(-\d+)*\.dll"
    If rx.Test(binName) Then
        GetFileType = FILETYPE_MINGW_DLL
        Exit Function
    End If
    rx.Pattern = "^(advapi32|kernel32|msvcrt|user32)\.dll"
    If rx.Test(binName) Then
        GetFileType = FILETYPE_WINDOWS_DLL
        Exit Function
    End If
    WScript.StdErr.WriteLine "Unrecognized binary type: " & binName
    Quit 1
End Function

Class ValueList
    Private myIsCaseInsensitiveStringList
    Private nItems
    Private lItems()
    Sub Class_Initialize()
        nItems = 0
        myIsCaseInsensitiveStringList = False
    End Sub
    Public Property Get IsCaseInsensitiveStringList
        IsCaseInsensitiveStringList = myIsCaseInsensitiveStringList
    End Property
    Public Property Let IsCaseInsensitiveStringList(ByVal value)
        myIsCaseInsensitiveStringList = value
    End Property
    Public Property Get Count
        Count = nItems
    End Property
    Public Function Contains(ByVal value)
        Dim i
        If myIsCaseInsensitiveStringList Then
            For i = 0 To nItems - 1
                If StrComp(value, lItems(i), 1) = 0 Then
                    Contains = True
                    Exit Function
                End If
            Next
        Else
            For i = 0 To nItems - 1
                If lItems(i) = value Then
                    Contains = True
                    Exit Function
                End If
            Next
        End If
        Contains = False
    End Function
    Public Sub Add(ByVal value)
        If nItems = 0 Then
            ReDim lItems(0)
        Else
            ReDim Preserve lItems(nItems)
        End If
        lItems(nItems) = value
        nItems = nItems + 1
    End Sub
    Public Sub AddIfNotThere(ByVal value)
        If Not Me.Contains(value) Then
            Me.Add value
        End If
    End Sub
    Public Function Item(index)
        Item = lItems(index)
    End Function
    Public Function Implode(glue)
        Dim i, s
        s = ""
        For i = 0 To nItems - 1
            If i > 0 Then
                s = s & glue
            End If
            s = s & lItems(i)
        Next
        Implode = s
    End Function
    Public Sub Sort()
        Dim i, j, tmp, sw
        For i = 0 To nItems - 2
            For j = i + 1 To nItems - 1
                If myIsCaseInsensitiveStringList Then
                    sw = StrComp(lItems(i), lItems(j), 1) > 0
                Else
                    sw = StrComp("" & lItems(i), "" & lItems(j), 0) > 0
                End If
                If sw Then
                    tmp = lItems(i)
                    lItems(i) = lItems(j)
                    lItems(j) = tmp
                End If
            Next
        Next
    End Sub
End Class
