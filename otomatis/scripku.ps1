<#
    monitor-charger.ps1
    Copyright (c) 2025 MUH NAUFAL RABBANI MARUN

    Deskripsi:
    Script PowerShell untuk memantau status charger laptop.
    Jika charger dilepas, maka akan memicu shutdown kecuali dibatalkan
    oleh pengguna atau charger dicolok kembali dalam 60 detik.

    Lisensi:
    Skrip ini bersifat open-source untuk tujuan pembelajaran dan pribadi.
    Dilarang memperjualbelikan tanpa izin tertulis dari pembuat.

    Versi: 1.0.0
    Tanggal: 13 Mei 2025
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Write-Log {
    param([string]$message)
    $logPath = "$env:USERPROFILE\Desktop\charger-log.txt"
    Add-Content -Path $logPath -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $message"
}

function Show-Notification {
    param([string]$message)

    $form = New-Object Windows.Forms.Form
    $form.Text = "Notifikasi"
    $form.Size = New-Object Drawing.Size(350, 100)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.ControlBox = $false
    $form.TopMost = $true

    $label = New-Object Windows.Forms.Label
    $label.Text = $message
    $label.AutoSize = $true
    $label.Location = New-Object Drawing.Point(20, 20)
    $form.Controls.Add($label)

    $form.Show()
    Start-Sleep -Seconds 3
    $form.Close()
}

function IsCharging {
    $batt = Get-CimInstance -ClassName Win32_Battery
    return $batt.BatteryStatus -eq 2
}

function Wait-For-KeyPressOrCharger {
    $global:cancelShutdown = $false
    $shutdownScheduled = $false

    $form = New-Object Windows.Forms.Form
    $form.Text = "⚠️ Charger Dicabut"
    $form.Size = New-Object Drawing.Size(400, 150)
    $form.StartPosition = 'CenterScreen'
    $form.TopMost = $true
    $form.KeyPreview = $true

    $label = New-Object Windows.Forms.Label
    $label.Text = "Tekan tombol dalam 60 detik untuk membatalkan shutdown."
    $label.AutoSize = $true
    $label.Location = New-Object Drawing.Point(20, 30)
    $form.Controls.Add($label)

    $form.Add_KeyDown({
        if ($shutdownScheduled) {
            shutdown /a
            Write-Log "Tombol ditekan. Membatalkan shutdown."
        }
        $global:cancelShutdown = $true
        $form.Close()
    })

    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 1000
    $secondsLeft = 60

    $timer.Add_Tick({
        if (-not $shutdownScheduled) {
            shutdown /s /t 60
            $shutdownScheduled = $true
            Write-Log "Shutdown dijadwalkan dalam 60 detik."
        }

        if (IsCharging) {
            shutdown /a
            Write-Log "Charger dicolok kembali. Membatalkan shutdown dan menutup form."
            $global:cancelShutdown = $true
            $timer.Stop()
            $form.Close()
        }

        $secondsLeft--
        if ($secondsLeft -le 0) {
            Write-Log "Tidak ada respon. Shutdown akan dilanjutkan."
            $timer.Stop()
            $form.Close()
        }
    })

    $form.Add_Shown({ 
        Write-Log "Charger dicabut. Menunggu respon tombol atau colokan charger kembali."
        $timer.Start()
    })
    $form.ShowDialog() | Out-Null

    return $global:cancelShutdown
}

# ========================== MULAI SCRIPT ===========================

Write-Log "Script dimulai"
Show-Notification "🔌 Menunggu charger tersambung..."
Write-Log "Menunggu charger tersambung..."

# Tunggu charger dicolok
while (-not (IsCharging)) {
    Start-Sleep -Seconds 5
}

Show-Notification "✅ Charger terdeteksi. Pemantauan dimulai."
Write-Log "Charger terdeteksi. Memulai pemantauan."

# Loop utama
while ($true) {
    if (-not (IsCharging)) {
        $cancel = Wait-For-KeyPressOrCharger
        if (-not $cancel) {
            break
        } else {
            Show-Notification "✅ Shutdown dibatalkan. Pemantauan ulang dalam 60 detik."
            Write-Log "Shutdown dibatalkan oleh user atau charger kembali. Delay 60 detik."
            Start-Sleep -Seconds 60
        }
    }

    Start-Sleep -Seconds 5
}
