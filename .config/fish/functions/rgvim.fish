function rgvim
    set -l rg_args
    set -l pattern

    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case -h --hidden
                set -a rg_args --hidden
                set i (math $i + 1)
            case -g --glob
                set i (math $i + 1)
                set -a rg_args --glob $argv[$i]
                set i (math $i + 1)
            case '*'
                set pattern $argv[$i..]
                break
        end
    end

    if test -z "$pattern"
        echo "Usage: rgvim [OPTIONS] PATTERN"
        echo "Options:"
        echo "  -h, --hidden      Include hidden files"
        echo "  -g, --glob GLOB   Add glob pattern"
        return 1
    end

    set file (rg --color=never --no-heading -n $rg_args $pattern . | fzf)
    if test -n "$file"
        set file_name (string split -f 1 : $file)
        set line (string split -f 2 : $file)
        $EDITOR $file_name -c ":$line"
    end
end
