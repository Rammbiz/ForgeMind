' Starts the Cloudflare tunnel with no console window.
'
' cloudflared is a console program, so a startup entry that runs it
' directly puts a black window on the operator's screen at every
' logon and leaves it there. WScript.Shell.Run with a window style
' of 0 starts it with no window at all.
'
' Nothing in here may ever raise: this runs at logon, and an error
' in a startup script is a modal dialog sitting on the screen of
' whoever is working at the machine. On Error Resume Next covers
' every line, and if the check for a running tunnel cannot be made
' the tunnel is started anyway — a second tunnel is a nuisance, a
' box on the operator's screen and no tunnel at all is worse.
'
' This runs the named tunnel from .cloudflared\config.yml, which is
' bound to cad.forgemind.uk and keeps that address for good.

On Error Resume Next

running = 0

' The local-machine moniker without the \\.\ prefix: fewer
' backslashes to lose on the way into the file.
Set wmi = GetObject("winmgmts:root\cimv2")

If Err.Number = 0 Then

    Set found = wmi.ExecQuery( _
        "Select ProcessId From Win32_Process " & _
        "Where Name = 'cloudflared.exe'")

    If Err.Number = 0 Then running = found.Count

End If

Err.Clear

If running = 0 Then

    command = """C:\Program Files (x86)\cloudflared\cloudflared.exe""" & _
        " --no-autoupdate" & _
        " --loglevel info" & _
        " --logfile C:\ForgeMind\files\tunnel.log" & _
        " tunnel run forgemind"

    CreateObject("WScript.Shell").Run command, 0, False

End If
