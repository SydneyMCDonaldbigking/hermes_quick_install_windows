; installer.nsi
; Hermes 启动器 NSIS 安装脚本

!include "MUI2.nsh"

; ============================================================
; 基本设置
; ============================================================

Name "Hermes 启动器"
OutFile "Hermes启动器-1.0.0-x64-Setup.exe"
InstallDir "$PROGRAMFILES\Hermes Launcher"
InstallDirRegKey HKCU "Software\Hermes\Launcher" "InstallPath"

; ============================================================
; 接口设置
; ============================================================

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "SimplifiedChinese"

; ============================================================
; 安装分支
; ============================================================

Section "安装应用"
    SetOutPath "$INSTDIR"
    
    ; 复制应用文件
    File /r "dist\Hermes 启动器-1.0.0.exe"
    File /r "scripts\*.ps1"
    File /r "public\*.*"
    
    ; 创建开始菜单快捷方式
    CreateDirectory "$SMPROGRAMS\Hermes Launcher"
    CreateShortcut "$SMPROGRAMS\Hermes Launcher\Hermes 启动器.lnk" "$INSTDIR\Hermes 启动器-1.0.0.exe"
    CreateShortcut "$SMPROGRAMS\Hermes Launcher\卸载.lnk" "$INSTDIR\uninstall.exe"
    
    ; 创建桌面快捷方式
    CreateShortcut "$DESKTOP\Hermes 启动器.lnk" "$INSTDIR\Hermes 启动器-1.0.0.exe"
    
    ; 保存安装路径到注册表
    WriteRegStr HKCU "Software\Hermes\Launcher" "InstallPath" "$INSTDIR"
    WriteRegStr HKCU "Software\Hermes\Launcher" "Version" "1.0.0"
    WriteRegStr HKCU "Software\Hermes\Launcher" "InstallDate" "$INSTDIR"
    
    ; 创建卸载程序
    WriteUninstaller "$INSTDIR\uninstall.exe"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Hermes Launcher" "DisplayName" "Hermes 启动器"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Hermes Launcher" "UninstallString" "$INSTDIR\uninstall.exe"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Hermes Launcher" "DisplayVersion" "1.0.0"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Hermes Launcher" "InstallLocation" "$INSTDIR"
SectionEnd

; ============================================================
; 卸载分支
; ============================================================

Section "Uninstall"
    ; 删除应用文件
    Delete "$INSTDIR\Hermes 启动器-1.0.0.exe"
    Delete "$INSTDIR\uninstall.exe"
    RMDir /r "$INSTDIR"
    
    ; 删除快捷方式
    Delete "$SMPROGRAMS\Hermes Launcher\Hermes 启动器.lnk"
    Delete "$SMPROGRAMS\Hermes Launcher\卸载.lnk"
    RMDir "$SMPROGRAMS\Hermes Launcher"
    Delete "$DESKTOP\Hermes 启动器.lnk"
    
    ; 删除注册表项
    DeleteRegKey HKCU "Software\Hermes\Launcher"
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Hermes Launcher"
SectionEnd

; ============================================================
; 函数
; ============================================================

Function .onInit
    ; 检查已安装版本
    ReadRegStr $0 HKCU "Software\Hermes\Launcher" "Version"
    ${If} $0 != ""
        MessageBox MB_YESNO "检测到已安装的 Hermes 启动器 (版本 $0)。是否继续安装？" IDNO endInit
    ${EndIf}
    
    ; 管理员权限检查
    ${If} $RunningX64
        SetRegView 64
    ${Else}
        SetRegView 32
    ${EndIf}
    
endInit:
FunctionEnd

Function un.onInit
    MessageBox MB_YESNO "确实要卸载 Hermes 启动器吗？" IDNO noUninstall
    Return
    
noUninstall:
    Abort
FunctionEnd
