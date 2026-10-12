function Listen-Port {
    param(
        [int]$Port = 80,
        [switch]$Http,
        [string]$BindAddress = "0.0.0.0"
    )

    $ip = [System.Net.IPAddress]::Parse($BindAddress)
    $listener = [System.Net.Sockets.TcpListener]::new($ip, $Port)
    try {
        $listener.Start()
    } catch {
        Write-Host "Could not bind ${BindAddress}:${Port} -> $($_.Exception.InnerException.Message)" -ForegroundColor Red
        return
    }

    Write-Host "Listening on ${BindAddress}:${Port} ... Ctrl+C to stop" -ForegroundColor Cyan
    try {
        while ($true) {
            if ($listener.Pending()) {
                $client = $listener.AcceptTcpClient()
                $stamp  = Get-Date -Format "HH:mm:ss"
                Write-Host "[$stamp] Connection from $($client.Client.RemoteEndPoint)" -ForegroundColor Green

                if ($Http) {
                    $stream = $client.GetStream()
                    $body   = "OK`r`n"
                    $resp   = "HTTP/1.1 200 OK`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n$body"
                    $bytes  = [System.Text.Encoding]::ASCII.GetBytes($resp)
                    $stream.Write($bytes, 0, $bytes.Length)
                    $stream.Flush()
                }
                $client.Close()
            } else {
                Start-Sleep -Milliseconds 200
            }
        }
    } finally {
        $listener.Stop()
        Write-Host "Stopped." -ForegroundColor Cyan
    }
}

function Test-Port($hostname, $port, $timeoutMs = 3000) {
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync($hostname, $port)
        if ($task.Wait($timeoutMs)) {
            Write-Host "$hostname`:$port -> OPEN" -ForegroundColor Green
        } else {
            Write-Host "$hostname`:$port -> TIMED OUT (firewall / no route)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "$hostname`:$port -> REFUSED/ERROR: $($_.Exception.InnerException.Message)" -ForegroundColor Red
    } finally {
        $client.Dispose()
    }
}

function Update-Tool {
    param(
        [string]$Url  = "https://raw.githubusercontent.com/decafbeef/pstooling/refs/heads/main/utility.ps1",
        [string]$Path = "$PSScriptRoot\utility.ps1"
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -eq "\utility.ps1") {
        $Path = Join-Path (Get-Location) "utility.ps1"
    }

    Write-Host "Fetching $Url" -ForegroundColor Cyan
    try {
        $content = Invoke-RestMethod -Uri $Url -ErrorAction Stop
    } catch {
        Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    if ($content -match '<!DOCTYPE html>' -or $content -match '<html') {
        Write-Host "Got HTML, not a script - check the URL." -ForegroundColor Red
        return
    }

    Set-Content -Path $Path -Value $content -Encoding UTF8
    Write-Host "Saved to $Path" -ForegroundColor Green

    return $Path   # dot-source the result:  . (Update-Tool)
}

#Test-Port "192.168.0.2" 80
