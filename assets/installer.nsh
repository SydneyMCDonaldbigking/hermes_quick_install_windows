; electron-builder 自定义片段（由主模板 !include，勿写完整安装器）
; 文档: https://www.electron.build/nsis#custom-nsis-script

!define /date HERMES_INSTALL_DATE "%Y-%m-%d"

; 在 initMultiUser 之后执行，可使用 UNINSTALL_REGISTRY_KEY / SHELL_CONTEXT 等
!macro customInit
  ReadRegStr $R9 SHELL_CONTEXT "${UNINSTALL_REGISTRY_KEY}" DisplayVersion
  StrCmp $R9 "" afterVersionCheck
  MessageBox MB_YESNO "检测到已安装的 Hermes 启动器 (版本 $R9)。是否继续安装？" IDYES afterVersionCheck IDNO userCancelInstall
userCancelInstall:
  Abort
afterVersionCheck:
!macroend

; 应用文件写入完成后，附加安装日期（与 InstallLocation 同注册表项）
!macro customInstall
  WriteRegStr SHELL_CONTEXT "${INSTALL_REGISTRY_KEY}" "InstallDate" "${HERMES_INSTALL_DATE}"
!macroend
