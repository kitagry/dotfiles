function fish_right_prompt
    set -l parts

    set -l kube_ctx (kubectl config current-context 2>/dev/null)
    if test -n "$kube_ctx"
        set -a parts (set_color yellow)"⎈ $kube_ctx"(set_color normal)
    end

    set -l gcloud_cfg_file "$HOME/.config/gcloud/active_config"
    if test -f "$gcloud_cfg_file"
        set -l gcloud_cfg (cat "$gcloud_cfg_file" 2>/dev/null)
        if test -n "$gcloud_cfg"
            set -a parts (set_color cyan)"☁ $gcloud_cfg"(set_color normal)
        end
    end

    if test (count $parts) -gt 0
        echo -n (string join " | " $parts)
    end
end
