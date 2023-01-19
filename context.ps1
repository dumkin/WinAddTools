#Requires -Version 7.1

function DrawMenu {

	param (
		[string[]] $MenuItems,
		[int] $MenuPosition,
		[bool] $Multiselect,
		[int[]] $Selected
	)

	for ($i = 0; $i -le $MenuItems.length; $i++) {
		if ($null -eq $MenuItems[$i]) {
			continue
		}

		$item = $MenuItems[$i]

		if ($Multiselect) {
			if ($Selected -contains $i) {
				$item = '[✓] ' + $item
			}
			else {
				$item = '[ ] ' + $item
			}
		}

		if ($i -eq $MenuPosition) {
			Write-Host "> $($item)" -ForegroundColor Green
		}
		else {
			Write-Host "  $($item)"
		}
	}
}

function ToggleSelection {

	param (
		[int] $Position,
		[int[]] $Selected
	)
	
	if ($Selected -contains $Position) { 
		$result = $Selected | Where-Object { $_ -ne $Position }
	}
	else {
		$Selected += $Position
		$result = $Selected
	}
	$result
}

function Menu {

	param (
		[string[]] $menuItems,
		[switch] $Multiselect
	)

	if ($menuItems.Length -eq 0) {
		return $null
	}

	$successfulExit = $false
	$pos = 0
	$selection = @()

	Set-Variable KEY_ENTER -option Constant -value 13
	Set-Variable KEY_ESCAPE -option Constant -value 27
	Set-Variable KEY_SPACE -option Constant -value 32
	Set-Variable KEY_UP -option Constant -value 38
	Set-Variable KEY_DOWN -option Constant -value 40

	[console]::CursorVisible = $false # prevents cursor flickering

	DrawMenu $menuItems $pos $Multiselect $selection
	try {
		While ($true) {
			$pressedKey = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown").virtualkeycode

			if ($pressedKey -eq $KEY_UP) { $pos-- }
			if ($pressedKey -eq $KEY_DOWN) { $pos++ }
			if ($Multiselect -eq $true -and $pressedKey -eq $KEY_SPACE) {
				$selection = ToggleSelection $pos $selection
			}

			if ($pos -lt 0) { $pos = 0 }
			if ($pos -ge $menuItems.length) { $pos = $menuItems.length - 1 }
			if ($pressedKey -eq $KEY_ESCAPE) {
				$pos = $null
				$selection = @()
				$successfulExit = $true
				break
			}
			if ($pressedKey -eq $KEY_ENTER) {
				if ($Multiselect -eq $true -and $selection.length -eq 0) {
					continue
				}
				$successfulExit = $true
				break
			}

			$startPos = [System.Console]::CursorTop - $menuItems.Length
			[System.Console]::SetCursorPosition(0, $startPos)
			DrawMenu $menuItems $pos $Multiselect $selection
		}
	}
	finally {
		if ($successfulExit -eq $false) {
			DrawMenu $menuItems $pos $Multiselect $selection
			[console]::CursorVisible = $true
		}
	}
	
	if ($Multiselect) {
		return $selection
	}
	else {
		return $pos
	}
}

# Write-Host "Выберите нужные терминалы"

$terminal = @()
$terminal += "Command Prompt" # 0
$terminal += "Command Prompt as Administrator" # 1
$terminal += "PowerShell Windows" # 2
$terminal += "PowerShell Windows as Administrator" # 3
$terminal += "PowerShell" # 4
$terminal += "PowerShell as Administrator" # 5
$terminal += "Bash" # 6
$terminal += "Bash as Administrator" # 7
# $terminalsSelected = Menu $terminal -Multiselect

# Write-Host "Выберите оболочку"

$shell = @()
$shell += "Windows Terminal" # 0
$shell += "PowerShell" # 1
# $shellIndex = Menu $shell

function AddTerminal {

	param (
		[string] $Path,
		[string] $Icon,
		[string] $Name,
		[string] $Command
	)
	
	New-Item "$Path" -Force
	New-Item "$Path\command" -Force
    
	New-ItemProperty -Path "$Path" -Name "Icon" -PropertyType String -Value "$Icon"
	New-ItemProperty -Path "$Path" -Name "MUIVerb" -PropertyType String -Value "$Name"
	New-ItemProperty -Path "$Path\command" -Name "(Default)" -PropertyType String -Value "$Command"
}

New-PSDrive -PSProvider registry -Root HKEY_CLASSES_ROOT -Name HKCR

# Native
$rootBackground = 'HKCR:\Directory\Background\shell\ContextTerminal_Native'
if (Test-Path $rootBackground) {
	Remove-Item $rootBackground -Force -Recurse;
}
$rootContextMenus = 'HKCR:\Directory\ContextMenus\ContextTerminal_Native'
if (Test-Path $rootContextMenus) {
	Remove-Item $rootContextMenus -Force -Recurse;
}

New-Item "$rootBackground" -Force
New-ItemProperty -Path $rootBackground -Name "(Default)" -PropertyType String -Value "Native Terminals"
New-ItemProperty -Path $rootBackground -Name "ExtendedSubCommandsKey" -PropertyType String -Value "Directory\ContextMenus\ContextTerminal_Native"
New-ItemProperty -Path $rootBackground -Name "Icon" -PropertyType String -Value "C:\Program Files\PowerShell\7\pwsh.exe"
New-ItemProperty -Path $rootBackground -Name "Position" -PropertyType String -Value "Top"
New-Item "$rootContextMenus\shell" -Force

AddTerminal "$rootContextMenus\shell\native_cmd" "cmd.exe" "Command Prompt" "cmd.exe /s /k pushd ""%V\"""
AddTerminal "$rootContextMenus\shell\native_cmd_runas" "cmd.exe" "Command Prompt as Administrator" "pwsh -Command ""Start-Process cmd.exe -ArgumentList '/s /k pushd """"%V\""""' -Verb RunAs"""

AddTerminal "$rootContextMenus\shell\native_powershell_windows" "powershell.exe" "PowerShell Windows" "powershell.exe -noexit -command Set-Location -literalPath ""%V"""
AddTerminal "$rootContextMenus\shell\native_powershell_windows_runas" "powershell.exe" "PowerShell Windows as Administrator" "pwsh -Command ""Start-Process powershell.exe -ArgumentList '-noexit -command Set-Location -literalPath """"%V""""' -Verb RunAs"""

AddTerminal "$rootContextMenus\shell\native_powershell" "pwsh.exe" "PowerShell" "pwsh.exe -NoLogo -WorkingDirectory ""%V"""
AddTerminal "$rootContextMenus\shell\native_powershell_runas" "pwsh.exe" "PowerShell as Administrator" "pwsh -Command ""Start-Process pwsh.exe -ArgumentList '-NoLogo' -WorkingDirectory """"%V"""" -Verb RunAs"""

AddTerminal "$rootContextMenus\shell\native_bash" "bash.exe" "Bash" "bash.exe"

# Windows Terminal
$rootBackground = 'HKCR:\Directory\Background\shell\ContextTerminal_WindowsTerminal'
if (Test-Path $rootBackground) {
	Remove-Item $rootBackground -Force -Recurse;
}
$rootContextMenus = 'HKCR:\Directory\ContextMenus\ContextTerminal_WindowsTerminal'
if (Test-Path $rootContextMenus) {
	Remove-Item $rootContextMenus -Force -Recurse;
}

New-Item "$rootBackground" -Force
New-ItemProperty -Path $rootBackground -Name "(Default)" -PropertyType String -Value "Windows Terminals"
New-ItemProperty -Path $rootBackground -Name "ExtendedSubCommandsKey" -PropertyType String -Value "Directory\ContextMenus\ContextTerminal_WindowsTerminal"
New-ItemProperty -Path $rootBackground -Name "Icon" -PropertyType String -Value "C:\Program Files\PowerShell\7\pwsh.exe"
New-ItemProperty -Path $rootBackground -Name "Position" -PropertyType String -Value "Top"
New-Item "$rootContextMenus\shell" -Force

AddTerminal "$rootContextMenus\shell\wt_cmd" "cmd.exe" "Command Prompt" "pwsh -Command ""Start-Process wt.exe -ArgumentList 'new-tab -p """"Command Prompt"""" -d """"%V"""" ' "" "
AddTerminal "$rootContextMenus\shell\wt_cmd_runas" "cmd.exe" "Command Prompt as Administrator" "pwsh -Command ""Start-Process wt.exe -ArgumentList 'new-tab -p """"Command Prompt"""" -d """"%V"""" ' -Verb RunAs "" "

AddTerminal "$rootContextMenus\shell\wt_powershell_windows" "powershell.exe" "PowerShell Windows" "pwsh -Command ""Start-Process wt.exe -ArgumentList 'new-tab -p """"Windows PowerShell"""" -d """"%V"""" ' "" "
AddTerminal "$rootContextMenus\shell\wt_powershell_windows_runas" "powershell.exe" "PowerShell Windows as Administrator" "pwsh -Command ""Start-Process wt.exe -ArgumentList 'new-tab -p """"Windows PowerShell"""" -d """"%V"""" ' -Verb RunAs "" "

AddTerminal "$rootContextMenus\shell\wt_powershell" "pwsh.exe" "PowerShell" "pwsh -Command ""Start-Process wt.exe -ArgumentList 'new-tab -p """"PowerShell"""" -d """"%V"""" ' "" "
AddTerminal "$rootContextMenus\shell\wt_powershell_runas" "pwsh.exe" "PowerShell as Administrator" "pwsh -Command ""Start-Process wt.exe -ArgumentList 'new-tab -p """"PowerShell"""" -d """"%V"""" ' -Verb RunAs "" "

AddTerminal "$rootContextMenus\shell\wt_bash" "bash.exe" "Bash" "pwsh -Command ""Start-Process wt.exe -ArgumentList 'new-tab -p """"Ubuntu"""" -d """"%V"""" ' "" "

# pwsh -Command ""Start-Process pwsh.exe -ArgumentList '-NoLogo' -WorkingDirectory """"%V"""" -Verb RunAs""

# $shellIndex = 0
# if ($shellIndex -eq 0) {
# 	if ($terminalsSelected -contains 0) {
# 		AddTerminal "$rootContextMenus\shell\cmd" "cmd.exe" "Command Prompt" "cmd.exe /s /k pushd ""%V\"""
# 	}
# 	if ($terminalsSelected -contains 1) {
# 		AddTerminal "$rootContextMenus\shell\cmdrunas" "cmd.exe" "Command Prompt as Administrator" "pwsh -Command ""Start-Process cmd.exe -ArgumentList '/s /k pushd """"%V\""""' -Verb RunAs"""
# 	}
# }
# if ($shellIndex -eq 1) {
    
# }



# cmd.exe /s /c start /b Powershell -Command "Start-Process wt.exe -ArgumentList '--startingDirectory ""%V""' -Verb RunAs"


# pwsh -Command "Start-Process wt.exe -ArgumentList '--startingDirectory ""%V""' -Verb RunAs"
