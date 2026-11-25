function aws-sso --description "AWS SSO login + AWS_PROFILE (wraps ~/.local/bin/aws-sso)"
    # A script cannot set variables in this shell, so run it in export mode and eval the output.
    if contains -- -h $argv; or contains -- --help $argv
        command aws-sso $argv
        return $status
    end
    set -l out (command aws-sso --export=fish $argv)
    or return $status
    eval $out
end
