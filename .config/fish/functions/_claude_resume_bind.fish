function _claude_resume_bind -d "キーバインドから claude-resume をコマンドラインに流して実行する"
    # bind handler の中で直接 claude を起こさず、通常のコマンド実行に乗せる (_ghq_cd と同じ流儀)
    commandline -r "claude-resume"
    commandline -f execute
end
