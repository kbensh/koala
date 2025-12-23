#!/bin/sh

AUTO_COMMIT=false
while getopts "y" opt; do
    case $opt in
        y) AUTO_COMMIT=true ;;
        *) echo "Usage: $0 [-y] command..."; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

EXECID="$(date +%s%3N)"
SANDBOX_DIR="$(mktemp -d --suffix ".try-$EXECID")"
UNION_HELPER="unionfs"

export EXECID SANDBOX_DIR UNION_HELPER
tmpfstype=$(df --output=fstype "$SANDBOX_DIR" 2>/dev/null | tail -n +2)
if [ "$tmpfstype" = "overlay" ] && [ "$(id -u)" -eq "0" ]; then
    mount -t tmpfs tmpfs "$SANDBOX_DIR"
fi

mkdir -p "$SANDBOX_DIR/upperdir" "$SANDBOX_DIR/workdir" "$SANDBOX_DIR/temproot"

DIRS_AND_MOUNTS="$SANDBOX_DIR"/mounts
find / -maxdepth 1 >"$DIRS_AND_MOUNTS"
sort -u -o "$DIRS_AND_MOUNTS" "$DIRS_AND_MOUNTS"

while IFS="" read -r mountpoint; do
    if [ -d "$mountpoint" ] && ! [ -L "$mountpoint" ]; then
        mkdir -m "$(stat -c %a "$mountpoint")" -p "${SANDBOX_DIR}/upperdir/${mountpoint}" "${SANDBOX_DIR}/workdir/${mountpoint}" "${SANDBOX_DIR}/temproot/${mountpoint}"
    fi
done <"$DIRS_AND_MOUNTS"

chmod "$(stat -c %a /)" "$SANDBOX_DIR/temproot"

mount_and_execute="$SANDBOX_DIR"/mount_and_execute.sh
chroot_executable="$SANDBOX_DIR"/chroot_executable.sh
generated_script="$SANDBOX_DIR"/generated_script.sh

cat >"$mount_and_execute" <<"EOF"
#!/bin/sh
make_overlay() {
    mount -t overlay overlay -o userxattr -o "lowerdir=$2,upperdir=$1/upperdir/$3,workdir=$1/workdir/$3" "$1/temproot/$3"
}

mount_devices() {
    for dev in tty null zero full random urandom; do
        touch "$1/temproot/dev/$dev"
        mount -o bind /dev/$dev "$1/temproot/dev/$dev"
    done
}

# Mount loop
while IFS="" read -r mountpoint; do
    pure=${mountpoint##*:}
    [ ! -d "$pure" ] && continue
    if [ -L "$pure" ]; then
        ln -s $(readlink "$pure") "$SANDBOX_DIR/temproot/$pure"
        continue
    fi
    case "$pure" in (/|/dev|/proc) continue;; esac

    make_overlay "$SANDBOX_DIR" "$mountpoint" "$pure" 2>/dev/null
    if [ "$?" -ne 0 ]; then
        # Fallback to unionfs/mergerfs for nested mounts
        merger="$SANDBOX_DIR/mergerdir$(echo "$pure" | tr '/' '.')"
        mkdir "$merger"
        "$UNION_HELPER" "$mountpoint" "$merger" 2>/dev/null
        make_overlay "$SANDBOX_DIR" "$merger" "$pure" 2>/dev/null
    fi
done <"$SANDBOX_DIR/mounts"

mount_devices "$SANDBOX_DIR"

# Copy execution scripts into the sandbox
if ! [ -f "$SANDBOX_DIR/temproot/chroot_exec.sh" ]; then
    cp "$SANDBOX_DIR/chroot_executable.sh" "$SANDBOX_DIR/temproot/chroot_exec.sh"
    cp "$SANDBOX_DIR/generated_script.sh" "$SANDBOX_DIR/temproot/generated.sh"
fi

# Run the sandbox
unshare --root="$SANDBOX_DIR/temproot" /bin/sh /chroot_exec.sh
RET=$?

# Cleanup mounts inside namespace
umount "$SANDBOX_DIR/temproot/dev/"* 2>/dev/null
exit $RET
EOF

cat >"$chroot_executable" <<EOF
#!/bin/sh
mount -t proc proc /proc
ln -s /proc/self/fd/0 /dev/stdin
ln -s /proc/self/fd/1 /dev/stdout
ln -s /proc/self/fd/2 /dev/stderr
/bin/sh /generated.sh
EOF

echo "$@" > "$generated_script"
chmod +x "$mount_and_execute" "$chroot_executable" "$generated_script"
[ -t 0 ] && set -m

unshare --mount --map-root-user --user --pid --fork "$mount_and_execute"

changes=$(find "$SANDBOX_DIR/upperdir/" -type f -o \( -type c -size 0 \) -o -type d -o -type l)
analyze_changes() {
    echo "$changes" | while IFS= read -r file; do
        [ -z "$file" ] && continue
        local_file="${file#"$SANDBOX_DIR/upperdir"}"
        
        if [ -c "$file" ] && [ "$(stat -c %t,%T "$file")" = "0,0" ]; then
            echo "de $local_file"
        elif [ -d "$file" ]; then
            [ ! -e "$local_file" ] && echo "md $local_file"
        elif [ -L "$file" ]; then
             echo "ln $local_file"
        elif [ -f "$file" ]; then
            if [ -e "$local_file" ]; then echo "mo $local_file"; else echo "ad $local_file"; fi
        fi
    done
}

change_list=$(analyze_changes)

if [ -z "$change_list" ]; then
    echo "No changes detected."
    [ -n "$tmpfstype" ] && umount "$SANDBOX_DIR" 2>/dev/null
    exit 0
fi

echo ""
echo "--- Changes Detected ---"
echo "$change_list" | while read -r line; do
    type=$(echo "$line" | cut -d' ' -f1)
    file=$(echo "$line" | cut -d' ' -f2-)
    case $type in
        ad) echo "[ADDED]   $file" ;;
        mo) echo "[MODIFIED]$file" ;;
        de) echo "[DELETED] $file" ;;
        md) echo "[NEW DIR] $file" ;;
        ln) echo "[LINK]    $file" ;;
    esac
done
echo "------------------------"

if [ "$AUTO_COMMIT" = true ]; then
    response="y"
else
    printf "Commit these changes? [y/N] "
    read -r response
fi
case "$response" in
    [yY][eE][sS]|[yY])
        echo "Committing..."
        echo "$change_list" | while read -r line; do
            type=$(echo "$line" | cut -d' ' -f1)
            local_file=$(echo "$line" | cut -d' ' -f2-)
            sandbox_file="$SANDBOX_DIR/upperdir$local_file"
            
            case $type in
                ad|mo) 
                    rm -f "$local_file"
                    cp -a "$sandbox_file" "$local_file" 
                    ;;
                de) rm -rf "$local_file" ;;
                md) mkdir -p "$local_file" ;;
                ln) 
                    rm -f "$local_file"
                    cp -a "$sandbox_file" "$local_file"
                    ;;
            esac
        done
        echo "Done."
        ;;
    *)
        echo "Aborted. Changes discarded."
        ;;
esac

if [ "$(findmnt -n -o FSTYPE -T "$SANDBOX_DIR")" = "tmpfs" ]; then
    umount "$SANDBOX_DIR"
fi