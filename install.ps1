New-Item -Path C:\Users\kitad -Name .vimrc -Value .vimrc -ItemType SymbolicLink

$from_nvim_dir = '.config\nvim'
$to_nvim_dir = "$HOME/AppData/Local/nvim"
if ( -Not $(Test-Path $to_nvim_dir) ) {
  New-Item $to_nvim_dir -ItemType Directory
}
Get-ChildItem $from_nvim_dir | ForEach-Object {
  New-Item -Path $to_nvim_dir -Name $_.Name -Value $_.FullName -ItemType SymbolicLink
}

$from_efm_dir = '.config\efm-langserver'
$to_efm_dir = "$env:APPDATA/efm-langserver"
if ( -Not $(Test-Path $to_efm_dir) ) {
  New-Item $to_efm_dir -ItemType Directory
}
Get-ChildItem $from_efm_dir | ForEach-Object {
  New-Item -Path $to_efm_dir -Name $_.Name -Value $_.FullName -ItemType SymbolicLink
}
