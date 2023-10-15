' 2023-10-13 initial creation

Option Explicit

Private Declare PtrSafe Function GetAsyncKeyState Lib "user32" (ByVal vKey As Long) As Integer

Private Const LOCAL_REPO_BASE_PATH As String = "C:\MyData\Sandboxes\vba-code-vault\"
'Private Const GITHUB_RAW_BASE_URL As String = "https://raw.githubusercontent.com/porentief49/vba-code-vault/main/Mitarbeiterauslagen/Main.bas"
Private Const GITHUB_RAW_BASE_URL As String = "https://raw.githubusercontent.com/porentief49/vba-code-vault/main/"

Public Enum eDoWeUpdate
    WhatDoIKnow = 0
    YeahGoForIt = 1
    NahWhatIHaveIsGood = 0
End Enum

Public Sub ExportAll()
    Dim lComponent As VBComponent
    Dim lFso As New FileSystemObject
    Dim lStream As TextStream
    For Each lComponent In ThisWorkbook.VBProject.VBComponents
        If lComponent.Type < 2 Then
            Set lStream = lFso.CreateTextFile(LOCAL_REPO_BASE_PATH & GetWorkbookName & "\" & GetFileName(lComponent))
            Call lStream.Write(lComponent.CodeModule.Lines(1, lComponent.CodeModule.CountOfLines))
            Call lStream.Close
            Set lStream = Nothing
        End If
    Next lComponent
End Sub

Public Sub UpdateAll()
    Dim lComponent As VBComponent
    Dim lResult As String
    Dim lGitHubCode As String
    Dim lThisRevDate As String
    Dim lGitHubRevDate As String
    Dim lDoWeUpdate As eDoWeUpdate
    lDoWeUpdate = WhatDoIKnow
    For Each lComponent In ThisWorkbook.VBProject.VBComponents
        If lComponent.Type < 2 Then
'            If lComponent.Name <> "Loader" Then
                lResult = ReadGitHubRaw(GITHUB_RAW_BASE_URL & GetWorkbookName & "/" & GetFileName(lComponent), lGitHubCode)
                If LenB(lResult) = 0 Then
                    If LenB(lGitHubCode) > 0 Then
                        lThisRevDate = GetRevDate(lComponent.CodeModule.Lines(1, lComponent.CodeModule.CountOfLines))
                        lGitHubRevDate = GetRevDate(lGitHubCode)
                        If lGitHubRevDate > lThisRevDate Then
                            If lDoWeUpdate = WhatDoIKnow Then
                                If MsgBox("New version found on GitHub - update?", vbYesNo, "Auto-Update") = vbYes Then
                                    lDoWeUpdate = YeahGoForIt
                                Else
                                    lDoWeUpdate = NahWhatIHaveIsGood
                                    Exit For
                                End If
                            If lDoWeUpdate = YeahGoForIt Then
                                lResult = UpdateModule(lComponent.Name, lGitHubCode)
                                If LenB(lResult) = 0 Then
                                    Debug.Print "Module '" & lComponent.Name; "' successfully updated"
                                    Debug.Print "    Rev Date: " & GetRevDate(lComponent.CodeModule.Lines(1, lComponent.CodeModule.CountOfLines))
                                Else
                                    Debug.Print "UpdateModule did not work: " & lResult
                                End If
                            End If
                        Else
                                Debug.Print "Module '" & lComponent.Name; "' already up-to-date"
                        End If
                    Else
                        Debug.Print "ReadGitHubRaw worked, but no code in module"
                    End If
                Else
                    Debug.Print "ReadGitHubRaw did not work: " & lResult
                End If
'            End If
        End If
    Next lComponent
End Sub

Private Function GetFileName(aComponent As VBComponent) As String
    GetFileName = aComponent.Name & IIf(aComponent.Type = vbext_ct_StdModule, ".bas", ".cls")
End Function

Private Function GetWorkbookName() As String
    GetWorkbookName = Split(ActiveWorkbook.Name, ".")(0)
End Function

Private Function GetRevDate(aCodeAllLines As String) As String
    Dim i As Long
    Dim lLine As String
'    Dim lModule As CodeModule
    Dim lLines() As String
    Dim lDateMaybe As String
    Dim lLatestDate As String
    Dim lDone
'    Set lModule = aComponent.CodeModule
    i = 0
    lDone = False
    lLines = Split(Replace$(aCodeAllLines, vbCr, vbNullString), vbLf)
    Do
        lLine = Trim$(lLines(i))
        If Left$(lLine, 1) = "'" Then
            lDateMaybe = Split(Trim$(Mid$(lLine, 2, 999)), " ")(0)
            If Len(lDateMaybe) = 10 Then
                If LenB(ReplaceAny(lDateMaybe, "0123456789-", vbNullString)) = 0 Then
                    If lDateMaybe > lLatestDate Then lLatestDate = lDateMaybe
                Else
                    'error format!!!
                End If
            Else
                'error format!!!
            End If
        Else
            lDone = True
        End If
        i = i + 1
    Loop Until lDone Or i > UBound(lLines)
    GetRevDate = lLatestDate
End Function

Private Function ReplaceAny(aIn As String, aReplaceChars As String, aWith As String) As String
    Dim lResult As String
    Dim i As Long
    lResult = aIn
    For i = 1 To Len(aReplaceChars)
        lResult = Replace$(lResult, Mid$(aReplaceChars, i, 1), aWith)
    Next i
    ReplaceAny = lResult
End Function


Private Function ReadGitHubRaw(aUrl As String, ByRef aCodeModule As String) As String 'credit: https://chat.openai.com/share/d3dd39f3-abb9-4233-aa19-7c3cef294b50
    
    ' this is the link format needed: https://drive.google.com/uc?id=YOUR_FILE_ID"
    ' when you share in google drive, you will get this link: https://drive.google.com/file/d/18D2GscIRnO286zlWqNTSL06jcMgtTeon/view?usp=sharing
    ' now grab the doc ID and put it into the link above: https://drive.google.com/uc?id=18D2GscIRnO286zlWqNTSL06jcMgtTeon
'    Dim fileURL As String
    Dim xmlHttp As Object
    On Error GoTo hell
'    fileURL = "https://drive.google.com/uc?id=" & aFileId
    Set xmlHttp = CreateObject("MSXML2.ServerXMLHTTP")
    Call xmlHttp.Open("GET", aUrl, False)  ' Send a GET request to the Google Drive file
    Call xmlHttp.send
    If xmlHttp.Status = 200 Then ' Check if the request was successful
        aCodeModule = xmlHttp.responseText ' Read the response text (contents of the file)
'        MsgBox fileContents ' Display the file contents (you can modify this part as needed)
'        Open "c:\temp\download.txt" For Output As #1
'        Print #1, fileContents
'        Close #1
        ReadGitHubRaw = vbNullString
    Else
        ' Handle errors (e.g., file not found)
        ReadGitHubRaw = "HTTP Error: " & xmlHttp.Status & " - " & xmlHttp.statusText
    End If
    Set xmlHttp = Nothing ' Clean up
    Exit Function
hell:
    Set xmlHttp = Nothing ' Clean up
    ReadGitHubRaw = "Error: " & Err.Description
End Function


Private Function UpdateModule(aModuleName As String, aCode As String) As String
'    Dim lFso As New FileSystemObject
'    Dim lStream As TextStream
    Dim lProject As VBProject
    Dim lComponent As VBComponent
    Dim lModule As CodeModule
'    Dim lFile As String
'    Dim lLines As String
'    Dim lModuleName As String
    On Error GoTo hell
'    lModuleName = Split(lFso.GetFileName(aFile), ".")(0)
    Set lProject = ThisWorkbook.VBProject
    Set lComponent = lProject.VBComponents(aModuleName)
    Set lModule = lComponent.CodeModule
'    lFile = "C:\temp\" & lModuleName & ".txt"
'    Set lStream = lFso.OpenTextFile(aFile)
'    lLines = lStream.ReadAll
'    Call lStream.Close
'    Set lStream = Nothing
    Call lModule.DeleteLines(1, lModule.CountOfLines)
    Call lModule.InsertLines(1, aCode)
    UpdateModule = vbNullString
    Exit Function
hell:
'    Set lStream = Nothing
    UpdateModule = "Error: " & Err.Description
End Function

Function IsShiftKeyPressed() As Boolean 'credit: https://chat.openai.com/share/2c52b886-2200-41a9-93b1-40503edf8baa
    IsShiftKeyPressed = (GetAsyncKeyState(16) And &H8000) <> 0
End Function



