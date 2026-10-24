@echo off & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1" %* & pause & exit /b
rem fullstack-agent: updates every installed piece, by handing off to update.ps1.
rem Copyright (C) 2026 Jared Rhodenizer
rem SPDX-License-Identifier: AGPL-3.0-or-later
rem
rem WHY EVERYTHING IS ON THE FIRST LINE, because the reason is worth knowing
rem before anyone rearranges it.
rem
rem cmd reads a .bat by byte offset, going back to the file on disk after each
rem command. The update can pull a new version of this very file, so any line
rem cmd has not read yet may be garbage by the time it gets there. A single
rem line is read in full before any of it runs, and its `exit /b` ends the
rem script before cmd ever looks at the disk again.
rem
rem An earlier version guarded against this by copying itself into a folder
rem under LOCALAPPDATA and running the copy. That is exactly what malicious
rem software does, and antivirus warned people about it. Never bring it back.
rem
rem The real work lives in update.ps1. PowerShell parses a whole script before
rem running it, so that file can safely update itself.
