#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Run_Au3Stripper=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.14.2
 Author:         Bioruebe

 Script Function:
	Merge multiple images with preview window and selection for each layer

#ce ----------------------------------------------------------------------------

; Script Start - Add your code below here

#include <Array.au3>
#include <ButtonConstants.au3>
#include <Date.au3>
#include <EditConstants.au3>
#include <GDIPlus.au3>
#include <GuiConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiListView.au3>
#include <INet.au3>
#include <ListViewConstants.au3>
#include <Math.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>

Opt("GUIOnEventMode", 1)

Global Const $sTitle = "ImageMerge"
Global Const $sVersion = "1.0.0 Beta 1"
Global Const $sIni = "ImageMerge.ini"
Global Const $sUpdateURL = "http://update.bioruebe.com/imagemerge"
Global Const $sURL = "http://bioruebe.com/dev/imagemerge"

Global $gaDropFiles[0], $aImages[0][8]	;Handle|Width|Height|ListViewItem|ResizedWidth|ResizedHeight|PosX|PosY
Global $iEnabledLayers = 0, $iSaveCount = 0, $iBaseImageWidth = 481, $iBaseImageHeight = 309, $sBackgroundName = "", $bIsResizing = False

; Read settings
Global $bEnableLayersOnLoad = IniRead($sIni, "Settings", "EnableLayersOnLoad", 0)
Global $iLastUpdate = IniRead($sIni, "General", "LastUpdate", "2016/01/01")
Global $iUpdateInterval = IniRead($sIni, "Settings", "UpdateInterval", 1)
If $iUpdateInterval < 1 Then $iUpdateInterval = 1

#Region ### START Koda GUI section ### Form=C:\Users\Bioruebe\Dropbox\Development\Autoit\ImageMerge\Main.kxf
$hGUI = GUICreate($sTitle, 562, 460, -1, -1, BitOR($WS_MINIMIZEBOX, $WS_MAXIMIZEBOX, $WS_SIZEBOX, $WS_CAPTION, $WS_POPUP, $WS_SYSMENU), $WS_EX_ACCEPTFILES)
$idDropLabel = GUICtrlCreateLabel("Drop layers here", 40, 152, $iBaseImageWidth, 28, $SS_CENTER)
GUICtrlSetFont(-1, 14, 400, 0, "MS Sans Serif")
GUICtrlSetColor(-1, 0x808080)
$idPicture = _SetResizing(GUICtrlCreatePic("", 40, 14, $iBaseImageWidth, $iBaseImageHeight, BitOR($GUI_SS_DEFAULT_PIC,$WS_BORDER)))
$idLayers = GUICtrlCreateListView("Layer", 28, 338, 217, 105, $LVS_NOCOLUMNHEADER, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_CHECKBOXES))
_GUICtrlListView_SetColumnWidth ($idLayers, 0, 189)
$idButtonUp = _SetResizing(GUICtrlCreateButton("Up", 250, 338, 51, 25))
$idButtonDown = _SetResizing(GUICtrlCreateButton("Down", 250, 370, 51, 25))
$idButtonDelete = _SetResizing(GUICtrlCreateButton("Delete", 250, 418, 51, 25))
$idButtonClear = _SetResizing(GUICtrlCreateButton("Clear", 312, 418, 59, 25))
$idButtonSave = _SetResizing(GUICtrlCreateButton("Save", 440, 368, 99, 25))
$idButtonSaveAs = _SetResizing(GUICtrlCreateButton("...", 488, 336, 27, 21))
$idButtonPlus = _SetResizing(GUICtrlCreateButton("+", 518, 336, 21, 21))
$idFileName = _SetResizing(GUICtrlCreateInput("", 336, 336, 145, 21))
$idAbout = GUICtrlCreatePic("information-button.gif", 512, 416, 25, 25)
$idSettings = GUICtrlCreatePic("gear-loading.gif", 472, 416, 25, 25)
$idEnter = GUICtrlCreateDummy()

;~ GUISetBkColor(0xFFFFFF)
Local $aAccelKeys[2][2] = [["{ENTER}", $idEnter], ["{DEL}", $idButtonDelete]]
GUISetAccelerators($aAccelKeys)
GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
GUICtrlSetOnEvent($idEnter, "_OnEnter")
GUICtrlSetOnEvent($idButtonSave, "_OnSave")
GUICtrlSetOnEvent($idButtonSaveAs, "_OnSaveAs")
GUICtrlSetOnEvent($idButtonClear, "_OnClear")
GUICtrlSetOnEvent($idButtonUp, "_OnUp")
GUICtrlSetOnEvent($idButtonDown, "_OnDown")
GUICtrlSetOnEvent($idButtonDelete, "_OnDelete")
GUICtrlSetOnEvent($idButtonPlus, "_OnPlus")
GUICtrlSetOnEvent($idAbout, "_OnAbout")
GUICtrlSetOnEvent($idSettings, "_OnSettings")
GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")
GUIRegisterMsg($WM_PAINT, "WM_PAINT")
GUIRegisterMsg($WM_SIZE, "WM_SIZE")
GUIRegisterMsg($WM_GETMINMAXINFO, "GUI_WM_GETMINMAXINFO")
GUIRegisterMsg ($WM_DROPFILES, "_WM_DROPFILES_UNICODE_FUNC")
#EndRegion ### END Koda GUI section ###

_GDIPlus_Startup()
$hPic = GUICtrlGetHandle($idPicture)
$hGraphicContainer = _GDIPlus_GraphicsCreateFromHWND($hPic)
$hBMPBuff = _GDIPlus_BitmapCreateFromGraphics($iBaseImageWidth, $iBaseImageHeight, $hGraphicContainer)
$hGraphic = _GDIPlus_ImageGetGraphicsContext($hBMPBuff)
_GDIPlus_GraphicsClear($hGraphic, 0x00000000)

GUISetState(@SW_SHOW)

_CheckUpdate()

; Main loop
While 1
	If $bIsResizing Then
		$bIsResizing = False
		_UpdatePictureSize()
		_Redraw()
	EndIf
	Sleep(10)
WEnd


; Load image file
Func _LoadImage($sPath)
	Cout("Opening " & $sPath)
	GUICtrlSetState($idDropLabel, $GUI_HIDE)
	Local $hImage = _GDIPlus_ImageLoadFromFile($sPath)
	If @error Then Return MsgBox(16, $sTitle, "Failed to open image " & $sPath & @CRLF & @CRLF & @extended)

	Local $iSize = UBound($aImages)
	ReDim $aImages[$iSize + 1][UBound($aImages, 2)]

	; Parse filename
	$iPos = StringInStr($sPath, "\", 0, -1)
	$sFileName = $iPos < 1? $sPath: StringTrimLeft($sPath, $iPos)

	; Set working directory so the file is saved to the last used folder
	If $iPos > 0 Then FileChangeDir(StringLeft($sPath, $iPos))

	$aImages[$iSize][0] = $hImage
	$aImages[$iSize][1] = _GDIPlus_ImageGetWidth($hImage)
	$aImages[$iSize][2] = _GDIPlus_ImageGetHeight($hImage)
	$aImages[$iSize][3] = GUICtrlCreateListViewItem($sFileName, $idLayers)

	_CalculateScale($iSize)

	If $iSize > 0 And $bEnableLayersOnLoad = 0 Then Return ; Only draw first layer, rest will be diabled in list
	Cout("Drawing " & $iSize)
	_GDIPlus_GraphicsDrawImageRectRect($hGraphic, $hImage, 0, 0, $aImages[$iSize][1], $aImages[$iSize][2], $aImages[$iSize][6], $aImages[$iSize][7], $aImages[$iSize][4], $aImages[$iSize][5])
	_GDIPlus_GraphicsDrawImage($hGraphicContainer, $hBMPBuff, 0, 0)
	_GUICtrlListView_SetItemChecked($idLayers, $iSize)

	If $iSize > 0 Then
		$iEnabledLayers += 1
		Return
	Else
		$iEnabledLayers = 1
		Return
	EndIf

	FileChangeDir(StringLeft($sPath, $iPos))
	_SetFileName()
EndFunc

; Update scale of image at index $iIndex
Func _CalculateScale($iIndex)
	$aImages[$iIndex][4] = $aImages[$iIndex][1]
	$aImages[$iIndex][5] = $aImages[$iIndex][2]

	$fRatio = _Min($iBaseImageWidth / $aImages[$iIndex][1], $iBaseImageHeight / $aImages[$iIndex][2])
	Cout("Image ratio: " & $fRatio)
	If $fRatio < 1 Then
		$aImages[$iIndex][4] *= $fRatio
		$aImages[$iIndex][5] *= $fRatio
	EndIf

	$aImages[$iIndex][6] = ($iBaseImageWidth - $aImages[$iIndex][4]) / 2
	$aImages[$iIndex][7] = ($iBaseImageHeight - $aImages[$iIndex][5]) / 2

	Cout($aImages[$iIndex][1] & "x" & $aImages[$iIndex][2] & " image")
	Cout($aImages[$iIndex][4] & "x" & $aImages[$iIndex][5] & " scaled")
EndFunc

; Save merged picture to file
Func _SaveMerged($sPath)
	If $iEnabledLayers < 2 Then Return MsgBox(16, $sTitle, "Please select at least two layers.")
	If $sPath = "" Or StringIsSpace($sPath) Then Return MsgBox(16, $sTitle, "Please enter a valid file name to save merged image.")
	If FileExists($sPath) And MsgBox(32+4, $sTitle, "The file " & $sPath & " already exists." & @CRLF & @CRLF & "Do you want to overwrite it?") == 7 Then Return
	Cout("Saving " & $iEnabledLayers & " layers to file " & $sPath)

	$hTempGUI = GUICreate($sTitle, $aImages[0][1], $aImages[0][2])
	GUISetState()
	$hTempGraphicGUI = _GDIPlus_GraphicsCreateFromHWND($hTempGUI)
	$hTempBMPBuff = _GDIPlus_BitmapCreateFromGraphics($aImages[0][1], $aImages[0][2], $hTempGraphicGUI)
	$hTempGraphic = _GDIPlus_ImageGetGraphicsContext($hTempBMPBuff)
	_GDIPlus_GraphicsClear($hTempGraphic, 0x00000000)
	For $i = 0 To UBound($aImages) - 1
		If _GUICtrlListView_GetItemChecked($idLayers, $i) Then _GDIPlus_GraphicsDrawImageRectRect($hTempGraphic, $aImages[$i][0], 0, 0, $aImages[$i][1], $aImages[$i][2], 0, 0, $aImages[$i][1], $aImages[$i][2])
	Next
	_GDIPlus_GraphicsDrawImage($hTempGraphicGUI, $hTempBMPBuff, 0, 0)
	Sleep(1000)
	If Not _GDIPlus_ImageSaveToFile($hTempBMPBuff, $sPath) Then MsgBox(16, $sTitle, "Error saving merged image: " & @extended)
	_GDIPlus_GraphicsDispose($hTempGraphic)
    _GDIPlus_GraphicsDispose($hTempGraphicGUI)
    _WinAPI_DeleteObject($hTempBMPBuff)
	GUIDelete($hTempGUI)

	_WinAPI_RedrawWindow($hGUI, "", "", BitOR($RDW_ERASE, $RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_FRAME, $RDW_ALLCHILDREN))

	_IncrementFileName()
EndFunc


; Handle 'Save' button click
Func _OnSave()
	_SaveMerged(GUICtrlRead($idFileName))
EndFunc

; Handle 'Save as' button click
Func _OnSaveAs()
	$sFileName = FileSaveDialog($sTitle, @WorkingDir, "Images (*.jpg;*.png)|All (*.*)", 16, GUICtrlRead($idFileName), $hGUI)
	If @error Then Return
	GUICtrlSetData($idFileName, StringTrimLeft($sFileName, StringInStr($sFileName, "\", 0, -1)))
;~ 	_SaveMerged($sFileName)
EndFunc

; Handle enter key
Func _OnEnter()
	If ControlGetFocus($hGUI) = "Edit1" Then _OnSave()
EndFunc

; Handle 'Up' button click
Func _OnUp()
	_GUICtrlListView_MoveItems($hGUI, $idLayers, -1)
EndFunc

; Handle 'Down' button click
Func _OnDown()
	_GUICtrlListView_MoveItems($hGUI, $idLayers, 1)
EndFunc

; Handle 'Delete' button click
Func _OnDelete()
	_DeleteItemsSelected($idLayers)
EndFunc

; Handle '+' button click
Func _OnPlus()
	_IncrementFileName(True)
EndFunc

; Handle 'Clear' button click
Func _OnClear()
	Cout("Cleaning up")
	GUICtrlSetData($idLayers, "")
	; Close image handles
	For $i = 0 To UBound($aImages) - 1
		Cout($i & ") " & _GDIPlus_ImageDispose($aImages[$i][0]))
		Sleep(10)
		GUICtrlDelete($aImages[$i][3])
	Next
	ReDim $aImages[0][UBound($aImages, 2)]
	_Redraw()
EndFunc

; Create about GUI
Func _OnAbout()
	Opt("GUIOnEventMode", 0)
	Local Const $iWidth = 437, $iHeight = 285
	Local $hAboutGUI = GUICreate($sTitle, $iWidth, $iHeight, -1, -1, -1, -1, $hGUI)
	GUICtrlCreateLabel($sTitle, 16, 16, $iWidth - 32, 52, $SS_CENTER)
	GUICtrlSetFont(-1, 30, 400, 0, "MS Sans Serif")
	GUICtrlCreateLabel("Version " & $sVersion, 16, 72, $iWidth - 32, 17, $SS_CENTER)
	GUICtrlCreateLabel("by Bioruebe, 2015" & @CRLF & "(" & $sURL & ")" & @CRLF & @CRLF & "'Information Button' icon by Freepik (http://www.freepik.com)" & @CRLF & "'Gear loading' icon by Amit Jakhu (http://www.flaticon.com/authors/amit-jakhu)" & @CRLF & @CRLF & "both from www.flaticon.com, licensed under CC BY 3.0" & @CRLF & "(http://creativecommons.org/licenses/by/3.0)", 16, 104, $iWidth - 32, -1, $SS_CENTER)
	GUICtrlCreatePic(".\Bioruebe.jpg", $iWidth - 89 - 10, $iHeight - 55, 89, 50)
	$idAboutOK = GUICtrlCreateButton("OK", $iWidth / 2 - 45, $iHeight - 50, 90, 25)
	GUISetState(@SW_SHOW)

	While 1
		Switch GUIGetMsg()
			Case $GUI_EVENT_CLOSE, $idAboutOK
				ExitLoop
		EndSwitch
	WEnd

	GUIDelete($hAboutGUI)
	Opt("GUIOnEventMode", 1)
EndFunc

; Open settings file
Func _OnSettings()
	ShellExecute($sIni)
EndFunc

; Resize preview control and GDI+ objects, used at GUI size change
Func _UpdatePictureSize()
	; Get new size
	Local $aPos = ControlGetPos($hGUI, "", $idPicture)
	If @error Then Return SetError(1)
	$iBaseImageWidth = $aPos[2]
	$iBaseImageHeight = $aPos[3]

	For $i = 0 To UBound($aImages) - 1
		_CalculateScale($i)
	Next

	; Reinitialize graphic context and buffer
	_GDIPlus_GraphicsDispose($hGraphic)
    _GDIPlus_GraphicsDispose($hGraphicContainer)
    _WinAPI_DeleteObject($hBMPBuff)

	$hGraphicContainer = _GDIPlus_GraphicsCreateFromHWND($hPic)
	$hBMPBuff = _GDIPlus_BitmapCreateFromGraphics($iBaseImageWidth, $iBaseImageHeight, $hGraphicContainer)
	$hGraphic = _GDIPlus_ImageGetGraphicsContext($hBMPBuff)
	_GDIPlus_GraphicsClear($hGraphic, 0x00000000)
EndFunc

; Redraw preview
Func _Redraw()
	Cout("Redraw")
	GUIRegisterMsg($WM_PAINT, "")
	Local $iSize = UBound($aImages)
	If $iSize < 1 Then GUICtrlSetState($idDropLabel, $GUI_SHOW)

	_GDIPlus_GraphicsClear($hGraphic, 0x00000000)
	_WinAPI_RedrawWindow($hGUI, "", "", BitOR($RDW_ERASE, $RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_FRAME, $RDW_ALLCHILDREN))
	$iEnabledLayers = 0

	If $iSize < 1 Then $iSize = 1
	For $i = 0 To $iSize - 1
		If _GUICtrlListView_GetItemChecked($idLayers, $i) Then _DrawToBuffer($i)
	Next

	_GDIPlus_GraphicsDrawImage($hGraphicContainer, $hBMPBuff, 0, 0)

	_SetFileName()
	GUIRegisterMsg($WM_PAINT, "WM_PAINT")
EndFunc

; Draw single layer to buffer
Func _DrawToBuffer($iIndex)
	_GDIPlus_GraphicsDrawImageRectRect($hGraphic, $aImages[$iIndex][0], 0, 0, $aImages[$iIndex][1], $aImages[$iIndex][2], $aImages[$iIndex][6], $aImages[$iIndex][7], $aImages[$iIndex][4], $aImages[$iIndex][5])
	$iEnabledLayers += 1
EndFunc

; Change file name if background has changed
Func _SetFileName()
	Local $sFileName = _GUICtrlListView_GetItemText($idLayers, 0)
	If $sBackgroundName == $sFileName And $sFileName <> "" Then Return
	$sBackgroundName = $sFileName
	Local $iPos = StringInStr($sFileName, ".", 0, -1) - 1
	If $iPos > 0 Then $sFileName = StringLeft($sFileName, $iPos) & "_merged" & StringTrimLeft($sFileName, $iPos)
	GUICtrlSetData($idFileName, $sFileName)
	$iSaveCount = 0
EndFunc

; Increment filename
Func _IncrementFileName($bForce = False)
	Local $sFileName = GUICtrlRead($idFileName)
	$iPos = StringInStr($sFileName, ".", 0, -1) - 1
	If $iPos < 2 Then Return
	$iSaveCount += 1
	$iLength = StringLen($iSaveCount)
;~ 	Cout(StringMid($sFileName, $iPos - $iLength + 1, $iLength) & "          " & $iSaveCount & "           " & StringLeft($sFileName, $iPos))

	If $iSaveCount == 1 Then
		$iLength = 0
	ElseIf StringMid($sFileName, $iPos - $iLength + 1, $iLength) <> $iSaveCount Then
		If Not $bForce Then	Return
		$iSaveCount = 1
		$iLength = 0
	EndIf

	$sFileName = StringLeft($sFileName, $iPos - $iLength) & $iSaveCount + 1 & StringTrimLeft($sFileName, $iPos)
	GUICtrlSetData($idFileName, $sFileName)
EndFunc

; Shortcut to GUICtrlSetResizing()
Func _SetResizing($idControl, $iSize = $GUI_DOCKAUTO)
	GUICtrlSetResizing($idControl, $iSize)
	Return $idControl
EndFunc

; ListView change handler
Func WM_NOTIFY($hWnd, $iMsg, $iwParam, $ilParam)
    Local $hWndFrom, $iCode, $tNMHDR, $hWndListView, $tInfo
    $hWndListView = $idLayers
    If Not IsHWnd($idLayers) Then $hWndListView = GUICtrlGetHandle($idLayers)

    $tNMHDR = DllStructCreate($tagNMHDR, $ilParam)
    $hWndFrom = HWnd(DllStructGetData($tNMHDR, "hWndFrom"))
	If $hWndFrom <> $hWndListView Then Return $GUI_RUNDEFMSG
    $iCode = DllStructGetData($tNMHDR, "Code")
    If $iCode <> $LVN_ITEMCHANGED Then Return $GUI_RUNDEFMSG

	$tNMLISTVIEW = DllStructCreate($tagNMLISTVIEW, $ilParam)
	$iIndex = DllStructGetData($tNMLISTVIEW, "Item")
    If BitAND(DllStructGetData($tNMLISTVIEW, "Changed"), $LVIF_STATE) = $LVIF_STATE Then
        Switch DllStructGetData($tNMLISTVIEW, "NewState")
            Case 8192 ;item checked
                Cout('Item ' & $iIndex & ' - ' & True)
				_DrawToBuffer($iIndex)
				; Draw overlapping layers again, so an enabled layer is not on top
				For $i = $iIndex + 1 To UBound($aImages) - 1
					If _GUICtrlListView_GetItemChecked($idLayers, $i) Then _DrawToBuffer($i)
				Next
				; Draw buffer to picture control
				_GDIPlus_GraphicsDrawImage($hGraphicContainer, $hBMPBuff, 0, 0)
            Case 4096 ;item unchecked
                Cout('Item ' & $iIndex & ' - ' & False)
				_Redraw()
		EndSwitch
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

; Drag and drop handler for multiple file support
; http://www.autoitscript.com/forum/topic/28062-drop-multiple-files-on-any-control/page__view__findpost__p__635231
Func _WM_DROPFILES_UNICODE_FUNC($hWnd, $msgID, $wParam, $lParam)
	Local $nSize, $pFileName
	Local $nAmt = DllCall("shell32.dll", "int", "DragQueryFileW", "hwnd", $wParam, "int", 0xFFFFFFFF, "ptr", 0, "int", 255)
	For $i = 0 To $nAmt[0] - 1
		$nSize = DllCall("shell32.dll", "int", "DragQueryFileW", "hwnd", $wParam, "int", $i, "ptr", 0, "int", 0)
		$nSize = $nSize[0] + 1
		$pFileName = DllStructCreate("wchar[" & $nSize & "]")
		DllCall("shell32.dll", "int", "DragQueryFileW", "hwnd", $wParam, "int", $i, "int", DllStructGetPtr($pFileName), "int", $nSize)
		ReDim $gaDropFiles[$i + 1]
		$gaDropFiles[$i] = DllStructGetData($pFileName, 1)
		$pFileName = 0
	Next
	Cout("Drag and drop action: " & @CRLF & _ArrayToString($gaDropFiles))
	_GUICtrlListView_BeginUpdate($idLayers)
	GUIRegisterMsg($WM_NOTIFY, "")
	For $sPath in $gaDropFiles
		_LoadImage($sPath)
	Next
	_GUICtrlListView_EndUpdate($idLayers)
	GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")
EndFunc

; Make sure the picture is redrawed after minimizing window
Func WM_PAINT($hWnd,$iMsg,$wParam,$lParam)
	If Not $bIsResizing Then _Redraw()
	Return $GUI_RUNDEFMSG
EndFunc

; Set $bIsResizing to True on resize event
Func WM_SIZE($hWnd, $Msg, $wParam, $lParam)
;~ 	ConsoleWrite($lParam & @CRLF)
	If Not $bIsResizing Then $bIsResizing = True
	Return $GUI_RUNDEFMSG
EndFunc

; Set minimum GUI size
Func GUI_WM_GETMINMAXINFO($hWnd, $Msg, $wParam, $lParam)
	$tagMaxinfo = DllStructCreate("int;int;int;int;int;int;int;int;int;int", $lParam)
	DllStructSetData($tagMaxinfo, 7, 579) ; min width
	DllStructSetData($tagMaxinfo, 8, 460) ; min height
	;DllStructSetData($tagMaxinfo,  9, ) ; max width
	;DllStructSetData($tagMaxinfo, 10, )  ; max height
	Return 0
EndFunc

; Terminate
Func _Exit()
	Cout("Terminating")
	For $i = 0 To UBound($aImages) - 1
		_GDIPlus_ImageDispose($aImages[$i][0])
	Next
    _GDIPlus_GraphicsDispose($hGraphic)
    _GDIPlus_GraphicsDispose($hGraphicContainer)
    _WinAPI_DeleteObject($hBMPBuff)
    _GDIPlus_Shutdown()
    Exit
EndFunc

; Write data to stdout stream
Func Cout($sData)
	If IsArray($sData) Then $sData = _ArrayToString($sData, @CRLF)
	Local $sOutput = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & ":" & @MSEC & @TAB & $sData & @CRLF; & @CRLF
	ConsoleWrite($sOutput)
	Return $sData
EndFunc

; Search for updates
Func _CheckUpdate()
	If $iLastUpdate <> 0 And _DateDiff("D", $iLastUpdate, _NowCalc()) < $iUpdateInterval Then Return
	IniWrite($sIni, "General", "LastUpdate", @YEAR & "/" & @MON & "/" & @MDAY)
	$sUpdateResponse = _INetGetSource($sUpdateURL)
	If $sUpdateResponse = $sVersion Then Return
	If MsgBox(64+4, $sTitle, "A new update is available for " & $sTitle & "." & @CRLF & @CRLF & "Your version: " & $sVersion & @CRLF & "Newest version: " & $sUpdateResponse & @CRLF & @CRLF & "Do you want to visit the download page now?") <> 6 Then Return
	ShellExecute($sURL)
EndFunc

; #FUNCTION# ====================================================================================================================
; Author ........: Gary Frost (gafrost)
; Modified.......: Melba23
; ===============================================================================================================================
Func _DeleteItemsSelected($hWnd)
	Local $iItemCount = _GUICtrlListView_GetItemCount($hWnd)
	$iSelectedCount = _GUICtrlListView_GetSelectedCount($hWnd)

	If $iSelectedCount < 1 Then Return True

	; Delete all?
	If $iSelectedCount = $iItemCount Then
		_OnClear()
		Return _GUICtrlListView_DeleteAllItems($hWnd)
	Else
		Local $aSelected = _GUICtrlListView_GetSelectedIndices($hWnd, True)
		If Not IsArray($aSelected) Then Return SetError($LV_ERR, $LV_ERR, 0)
		; Unselect all items
		_GUICtrlListView_SetItemSelected($hWnd, -1, False)
		; Determine ListView type
		Local $vCID = 0, $iNative_Delete, $iUDF_Delete
		If IsHWnd($hWnd) Then
			; Check if the ListView has a ControlID
			$vCID = _WinAPI_GetDlgCtrlID($hWnd)
		Else
			$vCID = $hWnd
			; Get ListView handle
			$hWnd = GUICtrlGetHandle($hWnd)
		EndIf
		; Loop through items
		For $iIndex = $aSelected[0] To 1 Step -1
			; Modify array
			_GDIPlus_ImageDispose($aImages[$aSelected[$iIndex]][0])
			_ArrayDelete($aImages, $aSelected[$iIndex])
;~ 			_ArrayDisplay($aImages)
			; If native ListView - could be either type of item
			If $vCID < $_UDF_STARTID Then
				; Try deleting as native item
				Local $iParam = _GUICtrlListView_GetItemParam($hWnd, $aSelected[$iIndex])
				; Check if LV item
				If GUICtrlGetState($iParam) > 0 And GUICtrlGetHandle($iParam) = 0 Then
					; Delete native item
					$iNative_Delete = GUICtrlDelete($iParam)
					; If deletion successful move to next
					If $iNative_Delete Then ContinueLoop
				EndIf
			EndIf
			; Has to be UDF Listview and/or UDF item
			$iUDF_Delete = _SendMessage($hWnd, $LVM_DELETEITEM, $aSelected[$iIndex])
			; Check for failed deletion
			If $iNative_Delete + $iUDF_Delete = 0 Then
				; $iIndex will be > 0
				ExitLoop
			EndIf
		Next
		_Redraw()
		; If all deleted return True; else return False
		Return Not $iIndex
	EndIf
EndFunc   ;==>_GUICtrlListView_DeleteItemsSelected

;===============================================================================
; Function Name:    _GUICtrlListView_MoveItems()
; Description:      Move selected item(s) in ListView Up or Down.
;
; Parameter(s):     $hWnd               - Window handle of ListView control (can be a Title).
;                   $vListView          - The ID/Handle/Class of ListView control.
;                   $iDirection         - [Optional], define in what direction item(s) will move:
;                                            1 (default) - item(s) will move Next.
;                                           -1 item(s) will move Back.
;                   $sIconsFile         - Icon file to set image for the items (only for internal usage).
;                   $iIconID_Checked    - Icon ID in $sIconsFile for checked item(s).
;                   $iIconID_UnChecked  - Icon ID in $sIconsFile for Unchecked item(s).
;
; Requirement(s):   #include <GuiListView.au3>, AutoIt 3.2.10.0.
;
; Return Value(s):  On seccess - Move selected item(s) Next/Back.
;                   On failure - Return "" (empty string) and set @error as following:
;                                                                  1 - No selected item(s).
;                                                                  2 - $iDirection is wrong value (not 1 and not -1).
;                                                                  3 - Item(s) can not be moved, reached last/first item.
;
; Note(s):          * This function work with external ListView Control as well.
;                   * If you select like 15-20 (or more) items, moving them can take a while :( (depends on how many items moved).
;
; Author(s):        G.Sandler a.k.a CreatoR (http://creator-lab.ucoz.ru)
;===============================================================================
Func _GUICtrlListView_MoveItems($hWnd, $vListView, $iDirection=1)
    Local $hListView = GUICtrlGetHandle($vListView)
    Local $aSelected_Indices = _GUICtrlListView_GetSelectedIndices($hListView, 1)

	If $aSelected_Indices[0] < 1 Then Return SetError(1, 0, "")
    If $iDirection <> 1 And $iDirection <> -1 Then Return SetError(2, 0, "")

    Local $iTotal_Items = ControlListView($hWnd, "", $hListView, "GetItemCount")
    Local $iTotal_Columns = ControlListView($hWnd, "", $hListView, "GetSubItemCount")

    Local $iUbound = $aSelected_Indices[0], $iNum = 1, $iStep = 1
    Local $iCurrent_Index, $iUpDown_Index, $sCurrent_ItemText, $sUpDown_ItemText
    Local $iCurrent_CheckedState, $iUpDown_CheckedState

    If ($iDirection = -1 And $aSelected_Indices[1] = 0) Or _
        ($iDirection = 1 And $aSelected_Indices[$iUbound] = $iTotal_Items-1) Then Return SetError(3, 0, "")

    ControlListView($hWnd, "", $hListView, "SelectClear")

    Local $aOldSelected_IDs[1]

    If $iDirection = 1 Then
        $iNum = $iUbound
        $iUbound = 1
        $iStep = -1
    EndIf

    For $i = $iNum To $iUbound Step $iStep
        $iCurrent_Index = $aSelected_Indices[$i]
        $iUpDown_Index = $aSelected_Indices[$i] + $iDirection

        $iCurrent_CheckedState = _GUICtrlListView_GetItemChecked($hListView, $iCurrent_Index)
        $iUpDown_CheckedState = _GUICtrlListView_GetItemChecked($hListView, $iUpDown_Index)

        _GUICtrlListView_SetItemSelected($hListView, $iUpDown_Index)

        For $j = 0 To $iTotal_Columns-1
            $sCurrent_ItemText = _GUICtrlListView_GetItemText($hListView, $iCurrent_Index, $j)
            $sUpDown_ItemText = _GUICtrlListView_GetItemText($hListView, $iUpDown_Index, $j)

            _GUICtrlListView_SetItemText($hListView, $iUpDown_Index, $sCurrent_ItemText, $j)
            _GUICtrlListView_SetItemText($hListView, $iCurrent_Index, $sUpDown_ItemText, $j)
        Next

        _GUICtrlListView_SetItemChecked($hListView, $iUpDown_Index, $iCurrent_CheckedState)
        _GUICtrlListView_SetItemChecked($hListView, $iCurrent_Index, $iUpDown_CheckedState)

        _GUICtrlListView_SetItemSelected($hListView, $iUpDown_Index, 0)

		_ArraySwap($aImages, $iCurrent_Index, $iUpDown_Index)
    Next

    For $i = 1 To UBound($aSelected_Indices)-1
        $iUpDown_Index = $aSelected_Indices[$i]+1
        If $iDirection = -1 Then $iUpDown_Index = $aSelected_Indices[$i]-1
        _GUICtrlListView_SetItemSelected($hListView, $iUpDown_Index)
    Next

	_Redraw()
EndFunc