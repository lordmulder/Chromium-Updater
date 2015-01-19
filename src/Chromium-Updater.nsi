################################################################################
# Chromium Updater                                                             #
# Copyright (C) 2008-2015 LoRd_MuldeR <MuldeR2@GMX.de>                         #
#                                                                              #
# This program is free software; you can redistribute it and/or modify         #
# it under the terms of the GNU General Public License as published by         #
# the Free Software Foundation; either version 2 of the License, or            #
# (at your option) any later version.                                          #
#                                                                              #
# This program is distributed in the hope that it will be useful,              #
# but WITHOUT ANY WARRANTY; without even the implied warranty of               #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                #
# GNU General Public License for more details.                                 #
#                                                                              #
# You should have received a copy of the GNU General Public License along      #
# with this program; if not, write to the Free Software Foundation, Inc.,      #
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.                  #
#                                                                              #
# http://www.gnu.org/licenses/gpl-2.0.txt                                      #
################################################################################

; Check defines
!ifndef UPDATER_VERSION
!error "UPDATER_VERSION is not set!"
!endif

; Includes
!include WinVer.nsh
!include StdUtils.nsh

; Global Symbols
!define BuildBot_URL "http://commondatastorage.googleapis.com/"		;chromium-browser-snapshots" ;"http://build.chromium.org/f/chromium/"
!define About_URL "http://www.chromium.org/"
!define Path_Snapshots "chromium-browser-snapshots"
!define Path_Continuous "chromium-browser-continuous"

Name "Chromium Auto-Updater"
Caption "Chromium Auto-Updater"
BrandingText "Auto-Updater v${UPDATER_VERSION}"

; The file to write
OutFile "..\bin\Chromium-Updater.exe"

; Runtime Packer
!packhdr "exehead.tmp" '"..\etc\upx.exe" --best exehead.tmp'

; Installer Attributes
XPStyle on
InstallDir "$PROGRAMFILES\Chrome"
ShowInstDetails show
Icon "..\etc\Update.ico"
InstallColors /windows

; Sub Captions
SubCaption 0 " "
SubCaption 1 " "
SubCaption 2 " "
SubCaption 3 " "
SubCaption 4 " "

; Pages
Page instfiles

; Vars
Var Current
Var Revision
Var Address
Var Channel

; Multi-User
!define MULTIUSER_EXECUTIONLEVEL Admin
!define MULTIUSER_INIT_TEXT_ADMINREQUIRED "Sorry, the Chromium updater cannot run in the context of a limited user.$\nPlease log in with an unrestricted user account or ask your administartor for help!"
!define MULTIUSER_NOUNINSTALL
!include MultiUser.nsh

;--------------------------------

!macro __DetailPrint Text
  SetDetailsPrint Both
  DetailPrint "${Text}"
  SetDetailsPrint None
!macroend

!macro __TextPrint Text
  SetDetailsPrint TextOnly
  DetailPrint "${Text}"
  SetDetailsPrint None
!macroend

!macro __ListPrint Text Data
  !define ID "${__LINE__}"
  SetDetailsPrint ListOnly

  StrCmp ${Data} "" PrintEmpty_${ID}
  DetailPrint "> ${Text}: ${Data}"
  Goto PrintDone_${ID}
  
  PrintEmpty_${ID}:
  DetailPrint "> ${Text}: Unknown"
  Goto PrintDone_${ID}

  PrintDone_${ID}:
  SetDetailsPrint None
  !undef ID
!macroend

!define DetailPrint "!insertmacro __DetailPrint"
!define TextPrint "!insertmacro __TextPrint"
!define ListPrint "!insertmacro __ListPrint"

;--------------------------------

!macro __MyAbort Text
  SetDetailsPrint Both
  Abort "${Text}"
  SetDetailsPrint None
!macroend

!define MyAbort "!insertmacro __MyAbort"

;--------------------------------

!macro __Download mode Info URL OutName
  !define ID "${__LINE__}"
  
  DL_Retry_${ID}:
  
  !if ${mode} == "popup"
    inetc::get /CAPTION "${Info}" /POPUP "${URL}" "${URL}" "${OutName}"
  !else if ${mode} == "banner"
    inetc::get /CAPTION "${Info}" /BANNER "Update Server:$\n$\n${URL}" "${URL}" "${OutName}"
  !else
    !error 'You must set MODE to "popup" or "banner"'
  !endif
  
  Pop $R0
  
  SetDetailsPrint TextOnly
  DetailPrint "Download status: $R0"
  SetDetailsPrint None

  StrCmp $R0 "OK" DL_Success_${ID}
  StrCmp $R0 "Cancelled" DL_Canceled_${ID}
  StrCmp $R0 "Transfer Error" DL_Error_${ID}

  MessageBox MB_RETRYCANCEL|MB_ICONSTOP|MB_TOPMOST "Download failed: $R0$\nPlease check your internet connection and try again!" IDRETRY DL_Retry_${ID}
  ${MyAbort} "Update has failed."
  
  DL_Canceled_${ID}:
  MessageBox MB_OK|MB_ICONEXCLAMATION|MB_TOPMOST "Download was aborted by user!"
  ${MyAbort} "Update was aborted by user."
  
  DL_Error_${ID}:
  ${DetailPrint} "Transfer error detected, retrying..."
  Goto DL_Retry_${ID}

  DL_Success_${ID}:
  !undef ID
!macroend

!define Download "!insertmacro __Download"

;--------------------------------

!macro __CheckInstances.WinNT
  !define ID "${__LINE__}"
 
  StartSearch_${ID}:
  LockedList::AddCaption /NOUNLOAD "*Chrome"
  LockedList::AddCaption /NOUNLOAD "*Chromium"
  LockedList::AddModule /NOUNLOAD "$EXEDIR\chrome.exe"
  LockedList::AddModule /NOUNLOAD "$EXEDIR\chrome.dll"
  LockedList::AddModule /NOUNLOAD "$EXEDIR\icudt38.dll"
  LockedList::AddModule /NOUNLOAD "$EXEDIR\themes\default.dll"
  LockedList::AddModule /NOUNLOAD "$EXEDIR\plugins\gears\gears.dll"
  
  GetFunctionAddress $R0 __CheckInstances.CallbackFunction
  StrCpy $R1 "<FALSE>"
  LockedList::SilentSearch $R0

  StrCmp $R1 "<FALSE>" NotRunning_${ID}
  MessageBox MB_ICONEXCLAMATION|MB_ABORTRETRYIGNORE|MB_TOPMOST "It seems Chrome (Chromium) is still running on your computer:$\n$\n$R2 [PID $R1]" IDRETRY StartSearch_${ID} IDIGNORE NotRunning_${ID}
  ${MyAbort} "Update was aborted by user."
    
  NotRunning_${ID}:
  !undef ID
!macroend

Function __CheckInstances.CallbackFunction
  Pop $R1 ; process id
  Pop $R2 ; file path
  Pop $R3 ; description
  ; do stuff here
  Push true ; continue enumeration
FunctionEnd

!macro __CheckInstances
  ${If} ${AtLeastWinNt4}
  !insertmacro __CheckInstances.WinNT
  ${EndIf}
!macroend

!define CheckInstances "!insertmacro __CheckInstances"

;--------------------------------

Section ""
  SetDetailsPrint None
  InitPluginsDir
  SetOutPath $EXEDIR

  StrCpy $Current ""
  StrCpy $Revision ""
  StrCpy $Address ""
  StrCpy $Channel ""

  ;--------------------------
  ; Chrome installed?
  ;--------------------------

  ${DetailPrint} "Location: $EXEDIR"
  
  IfFileExists "$EXEDIR\chrome.exe" ChromeIsInstalled
  MessageBox MB_ICONINFORMATION|MB_OKCANCEL|MB_TOPMOST "Could not find 'chrome.exe' in current directory. Chormium will be installed to this location:$\n$\n$EXEDIR" IDOK SkipVersionDetection
  ${MyAbort} "Update was aborted by user."
  
  ChromeIsInstalled:
  
  ;--------------------------
  ; Detect Version
  ;--------------------------

  ${DetailPrint} "Detecting installed version, please wait..."

  ClearErrors
  ReadINIStr $Current "$EXEDIR\$EXEFILE.ini" "ChromiumUpdater" "revision"
  IfErrors SkipVersionDetection

  IntOp $Current $Current + 0
  
  SkipVersionDetection:
  ${ListPrint} "Currently installed build" $Current

  ;--------------------------
  ; Load Config
  ;--------------------------
 
  ClearErrors
  ReadINIStr $Channel "$EXEDIR\$EXEFILE.ini" "ChromiumUpdater" "channel"
  IfErrors NotConfiguredYet

  StrCmp $Channel "snapshots" ConfigurationDone
  StrCmp $Channel "continuous" ConfigurationDone
  
  NotConfiguredYet:
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_TOPMOST "Do you want to get 'continous' Chromium builds, i.e. only builds that have passed all automated tests? (Recommended)$\n$\nOtherwise always the latest 'snapshot' build will be downloaded." IDNO GetSnapshotBuilds
  
  StrCpy $Channel "continuous"
  Goto SaveConfiguration
  GetSnapshotBuilds:
  StrCpy $Channel "snapshots"
  Goto SaveConfiguration

  SaveConfiguration:
  WriteINIStr "$EXEDIR\$EXEFILE.ini" "ChromiumUpdater" "channel" $Channel
  
  ConfigurationDone:

  ;--------------------------
  ; Set Address
  ;--------------------------
  
  StrCmp $Channel "continuous" 0 +2
  StrCpy $Address "${BuildBot_URL}${Path_Continuous}/Win"

  StrCmp $Channel "snapshots" 0 +2
  StrCpy $Address "${BuildBot_URL}${Path_Snapshots}/Win"
  
  ;--------------------------
  ; Fetch latest version
  ;--------------------------
  
  ${DetailPrint} "Searching for latest Chromium build, please wait..."
  ${ListPrint} "Selected update channel" $Channel

  ${Download} "banner" "Downloading version information..." "$Address/LAST_CHANGE" "$PLUGINSDIR\LAST_CHANGE.txt"
  
  ClearErrors
  FileOpen $0 "$PLUGINSDIR\LAST_CHANGE.txt" r
  IfErrors SkipBuildDetection
  FileRead $0 $Revision
  FileClose $0
  IntOp $Revision $Revision + 0
  
  SkipBuildDetection:
  Delete "$PLUGINSDIR\LAST_CHANGE.txt"
  
  ;--------------------------
  ; Check version info
  ;--------------------------
  
  StrCmp $Revision "" BuildInfoNotFound
  StrCmp $Revision "0" BuildInfoNotFound
  Goto BuildInfoFound
  
  BuildInfoNotFound:
  MessageBox MB_OK|MB_ICONSTOP|MB_TOPMOST "Could not find the latest build, sorry..."
  ${MyAbort} "Update has failed."
  
  BuildInfoFound:
  ${ListPrint} "Latest build available on server" $Revision

  ;--------------------------
  ; Is update required?
  ;--------------------------

  StrCmp $Current "" BeginUpdate
  IntCmp $Revision $Current 0 0 BeginUpdate

  ${DetailPrint} "The installed build is still up-to-date."
  MessageBox MB_YESNO|MB_DEFBUTTON2|MB_ICONINFORMATION|MB_TOPMOST "The installed build is still up-to-date. There's nothing to update now!$\n$\nDo you want to download and re-install the latest build anyway?" IDYES BeginUpdate
  ${DetailPrint} "Update was skipped."
  Goto UpdateCompleted
  
  BeginUpdate:
  
  ;--------------------------
  ; Download new version
  ;--------------------------
  
  ${DetailPrint} "Downloading Chromium build $Revision, please wait..."
  ${Download} "popup" "Chromium $Revision" "$Address/$Revision/chrome-win32.zip" "$PLUGINSDIR\chrome-win32.zip"
  
  ;--------------------------
  ; Extract new files
  ;--------------------------

  ${DetailPrint} "Extracting files, please wait..."
  
  CreateDirectory "$PLUGINSDIR\cache"
  File /oname=$PLUGINSDIR\unzip.exe "..\etc\unzip.exe"

  RetryExtraction:  
  nsExec::Exec /TIMEOUT=30000 '"$PLUGINSDIR\unzip.exe" -o "$PLUGINSDIR\chrome-win32.zip" -d "$PLUGINSDIR\cache"'
  Pop $0
  
  IntCmp $0 0 SuccessfullyExtracted
  StrCmp $0 "error" +2
  MessageBox MB_RETRYCANCEL|MB_ICONSTOP|MB_TOPMOST "An errer has occured while extracing the files! (Code: $0)" IDRETRY RetryExtraction
  Delete "$PLUGINSDIR\chrome-win32.zip"
  ${MyAbort} "Update has failed."
  
  SuccessfullyExtracted:
  Delete "$PLUGINSDIR\chrome-win32.zip"
  Delete "$PLUGINSDIR\unzip.exe"

  ;--------------------------
  ; Files complete?
  ;--------------------------

  IfFileExists "$PLUGINSDIR\cache\chrome-win32\chrome.exe" 0 MissingFile
  IfFileExists "$PLUGINSDIR\cache\chrome-win32\chrome.dll" 0 MissingFile
  Goto AllFilesThere
  
  MissingFile:
  ${DetailPrint} "Error: At least one required file is missing in the update!"
  ${MyAbort} "Update has failed."
  
  AllFilesThere:
  
  ;--------------------------
  ; Is Chrome running?
  ;--------------------------

  ${DetailPrint} "Checking for running instances, please wait..."
  ${CheckInstances}

  ;--------------------------
  ; Clean-UP
  ;--------------------------

  ${DetailPrint} "Cleaning-up old files, please wait..."
  
  Delete "$EXEDIR\*.exe"
  Delete "$EXEDIR\*.nexe"
  Delete "$EXEDIR\*.dll"
  Delete "$EXEDIR\*.bin"
  Delete "$EXEDIR\*.manifest"
  Delete "$EXEDIR\*.pak"
  Delete "$EXEDIR\*.dat"
  
  ;--------------------------
  ; Install the new files
  ;--------------------------

  ${DetailPrint} "Installing the new files, please wait..."

  RetryFileCopy:
  ClearErrors
  CopyFiles /SILENT "$PLUGINSDIR\cache\chrome-win32\*.*" "$EXEDIR"
  IfErrors 0 CopySuccessfull
  
  MessageBox MB_RETRYCANCEL|MB_ICONSTOP|MB_TOPMOST "Faild to copy the new files to the install folder!" IDRETRY RetryFileCopy
  RMDir /r "$PLUGINSDIR\cache"
  ${MyAbort} "Update has failed."
  
  CopySuccessfull:
  RMDir /r "$PLUGINSDIR\cache"
  
  ;--------------------------
  ; Remember revision
  ;--------------------------

  ${DetailPrint} "Saving version information, please wait..."

  ClearErrors
  WriteINIStr "$EXEDIR\$EXEFILE.ini" "ChromiumUpdater" "revision" $Revision

  ;--------------------------
  ; Done
  ;--------------------------

  ${DetailPrint} "Update completed successfully."
  SetAutoClose true
  Sleep 3333
  
  UpdateCompleted:
SectionEnd

Function .onInstSuccess
  ${StdUtils.ExecShellAsUser} $0 "$EXEDIR\chrome.exe" "open" "${About_URL}"
FunctionEnd

Function .onInit
  !insertmacro MULTIUSER_INIT
FunctionEnd

Function .onGuiInit
  Aero::Apply
FunctionEnd
