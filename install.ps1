New-Item -Path C:\Users\kitad -Name .vimrc -Value .vimrc -ItemType SymbolicLink

$from_nvim_dir = '.config\nvim'
$nvim_dir = "$HOME/AppData/Local/nvim"
Get-ChildItem $from_nvim_dir | ForEach-Object {
  New-Item -Path $nvim_dir -Name $_.Name -Value $_.FullName -ItemType SymbolicLink
}
