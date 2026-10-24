# fullstack-agent: give your AI a full stack - memory, voice, face, hands.
# Copyright (C) 2026 Jared Rhodenizer
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# The Windows twin of update.sh. Pulls the newest version of every installed
# piece, and of this repo. Your own files (your CLAUDE.md, your vault, your
# configs) live outside the repos' tracked files, so updates never touch them.
# If git reports a conflict on a config you edited, your edit wins.
#
#   powershell -ExecutionPolicy Bypass -File update.ps1
#   powershell -ExecutionPolicy Bypass -File update.ps1 -Owner someone-else
#
# -Owner only matters for a piece that arrived as a zip and has no .git yet:
# it names the GitHub account that piece gets wired to. A piece that is
# already a clone keeps whatever remote it has, so a fork stays a fork.
#
# Safe to update itself: PowerShell parses a whole .ps1 before running any of
# it, so a pull that rewrites this file mid-run cannot garble the run. (That
# is the bug that made update.bat dangerous; .bat files are read by offset.)

param(
  [string]$Owner = "jaredrhod"
)

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$HomeDir = Split-Path -Parent $Here

# A terminal opened before git was installed does not see it on PATH yet.
$Git = "git"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  $Git = "C:/Program Files/Git/cmd/git.exe"
  if (-not (Test-Path $Git)) {
    Write-Output "git is not installed, so nothing can be updated."
    Write-Output "Open a chat with your agent and say: install git and update everything."
    exit 1
  }
}

$Configs = @{
  "backtalk"      = "backtalk.json"
  "barehands"     = "barehands.json"
  "ai-visualizer" = "ai-visualizer.json"
}

$Failed = @()

foreach ($repo in @("fullstack-agent", "ai-memory-vault", "backtalk", "barehands", "ai-visualizer")) {
  $dir = Join-Path $HomeDir $repo
  if (-not (Test-Path $dir -PathType Container)) { continue }

  $cfg = $Configs[$repo]
  $cfgPath = $null
  if ($cfg) { $cfgPath = Join-Path $dir $cfg }
  $mine = $null
  if ($cfgPath) { $mine = "$cfgPath.mine" }

  if (-not (Test-Path (Join-Path $dir ".git"))) {
    Write-Output "== $repo (wiring to updates)"
    if ($cfgPath -and (Test-Path $cfgPath)) { Copy-Item $cfgPath $mine -Force }
    & $Git -C $dir init -q -b main
    & $Git -C $dir remote add origin "https://github.com/$Owner/$repo"
    & $Git -C $dir fetch -q origin
    if ($LASTEXITCODE -ne 0) {
      Write-Output "   couldn't reach github.com/$Owner/$repo; left as it was."
      if ($mine -and (Test-Path $mine)) { Remove-Item $mine -Force }
      Remove-Item (Join-Path $dir ".git") -Recurse -Force
      $Failed += $repo
      continue
    }
    & $Git -C $dir reset -q --hard origin/main
    & $Git -C $dir branch -q --set-upstream-to=origin/main main
    if ($mine -and (Test-Path $mine)) { Move-Item $mine $cfgPath -Force }
    Write-Output "   wired to updates. everything is current."
    continue
  }

  Write-Output "== $repo"
  & $Git -C $dir fetch -q origin
  if ($LASTEXITCODE -ne 0) {
    Write-Output "   couldn't reach the internet copy; skipped."
    $Failed += $repo
    continue
  }
  & $Git -C $dir log --oneline "..@{u}" | ForEach-Object { "   new: $_" }

  # A config that is still tracked by git (older installs) would block the
  # pull once you've edited it. Set yours aside, pull, then put it back.
  $migrate = $false
  if ($cfgPath -and (Test-Path $cfgPath)) {
    & $Git -C $dir ls-files --error-unmatch $cfg *> $null
    if ($LASTEXITCODE -eq 0) {
      Copy-Item $cfgPath $mine -Force
      & $Git -C $dir checkout -q -- $cfg
      $migrate = $true
    }
  }

  & $Git -C $dir pull -q --ff-only
  if ($LASTEXITCODE -ne 0) {
    Write-Output "   (couldn't fast-forward; your local edits win. See the note at the top of this script.)"
    $Failed += $repo
  }

  if ($migrate -and (Test-Path $mine)) { Move-Item $mine $cfgPath -Force }
}

Write-Output "update complete."
if ($Failed.Count -gt 0) {
  Write-Output "Not updated: $($Failed -join ', '). Ask your agent to look at why."
  exit 1
}
