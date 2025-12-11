#!/bin/sh
#
# Created by constructor 3.13.0
#
# NAME:  Miniforge3
# VER:   25.11.0-0
# PLAT:  linux-64
# MD5:   3805a4a380ca4cd3626126218d603f9a

set -eu
unset LD_LIBRARY_PATH LD_PRELOAD LD_AUDIT

if ! echo "$0" | grep '\.sh$' > /dev/null; then
    printf 'Please run using "bash"/"dash"/"sh"/"zsh", but not "." or "source".\n' >&2
    exit 1
fi
if [ "$(uname)" = "Linux" ]; then
    min_glibc_version="2.17"
    system_glibc_version="${CONDA_OVERRIDE_GLIBC:-}"
    if [ "${system_glibc_version}" = "" ]; then
        case "$(ldd --version 2>&1)" in
            *musl*)
                # musl ldd will report musl version; call libc.so directly
                # see https://github.com/conda/constructor/issues/850#issuecomment-2343756454
                libc_so="$(find /lib /usr/local/lib /usr/lib -name 'libc.so.*' -print -quit 2>/dev/null)"
                if [ -z "${libc_so}" ]; then
                    libc_so="$(strings /etc/ld.so.cache | grep '^/.*/libc\.so.*' | head -1)"
                fi
                if [ -z "${libc_so}" ]; then
                    echo "Warning: Couldn't find libc.so; won't be able to determine GLIBC version!" >&2
                    echo "Override by setting CONDA_OVERRIDE_GLIBC" >&2
                    system_glibc_version="0.0"
                else
                    system_glibc_version=$("${libc_so}" --version | awk 'NR==1{ sub(/\.$/, ""); print $NF}')
                fi
            ;;
            *)
                # ldd reports glibc in the last field of the first line
                system_glibc_version=$(ldd --version | awk 'NR==1{print $NF}')
            ;;
        esac
    fi
    # shellcheck disable=SC2183 disable=SC2046
    int_min_glibc_version="$(printf "%02d%02d%02d" $(echo "$min_glibc_version" | sed 's/\./ /g'))"
    # shellcheck disable=SC2183 disable=SC2046
    int_system_glibc_version="$(printf "%02d%02d%02d" $(echo "$system_glibc_version" | sed 's/\./ /g'))"
    if [ "$int_system_glibc_version" -lt "$int_min_glibc_version" ]; then
        echo "Installer requires GLIBC >=${min_glibc_version}, but system has ${system_glibc_version}."
        exit 1
    fi
fi

# Export variables to make installer metadata available to pre/post install scripts
# NOTE: If more vars are added, make sure to update the examples/scripts tests too
export INSTALLER_NAME='Miniforge3'
export INSTALLER_VER='25.11.0-0'
export INSTALLER_PLAT='linux-64'
export INSTALLER_TYPE="SH"
# Installers should ignore pre-existing configuration files.
unset CONDARC
unset MAMBARC

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
THIS_FILE=$(basename "$0")
THIS_PATH="$THIS_DIR/$THIS_FILE"
PREFIX="${HOME:-/opt}/miniforge3"
BATCH=0
FORCE=0
KEEP_PKGS=1
SKIP_SCRIPTS=0
INIT_CONDA=0
TEST=0
REINSTALL=0
USAGE="
usage: $0 [options]

Installs ${INSTALLER_NAME} ${INSTALLER_VER}
-b           run install in batch mode (without manual intervention),
             it is expected the license terms (if any) are agreed upon
-f           no error if install prefix already exists
-h           print this help message and exit
-p PREFIX    install prefix, defaults to $PREFIX, must not contain spaces.
-s           skip running pre/post-link/install scripts
-u           update an existing installation
-t           run package tests after installation (may install conda-build)
-c           run 'conda init' after installation (only applies to batch mode)
"
while getopts "bifhkp:sutc" x; do
    case "$x" in
        h)
            printf "%s\\n" "$USAGE"
            exit 2
        ;;
        b)
            BATCH=1
            ;;
        i)
            BATCH=0
            ;;
        f)
            FORCE=1
            ;;
        k)
            KEEP_PKGS=1
            ;;
        p)
            PREFIX="$OPTARG"
            ;;
        s)
            SKIP_SCRIPTS=1
            ;;
        u)
            FORCE=1
            ;;
        t)
            TEST=1
            ;;
        c)
            INIT_CONDA=1
            ;;
        ?)
            printf "ERROR: did not recognize option '%s', please try -h\\n" "$x"
            exit 1
            ;;
    esac
done

# For pre- and post-install scripts
export INSTALLER_UNATTENDED="$BATCH"

# For testing, keep the package cache around longer
CLEAR_AFTER_TEST=0
if [ "$TEST" = "1" ] && [ "$KEEP_PKGS" = "0" ]; then
    CLEAR_AFTER_TEST=1
    KEEP_PKGS=1
fi

if [ "$BATCH" = "0" ] # interactive mode
then
    if [ "$(uname -m)" != "x86_64" ]; then
        printf "WARNING:\\n"
        printf "    Your operating system appears not to be x86_64, but you are trying to\\n"
        printf "    install a x86_64 version of %s.\\n" "${INSTALLER_NAME}"
        printf "    Are sure you want to continue the installation? [yes|no]\\n"
        printf "[no] >>> "
        read -r ans
        ans=$(echo "${ans}" | tr '[:lower:]' '[:upper:]')
        if [ "$ans" != "YES" ] && [ "$ans" != "Y" ]
        then
            printf "Aborting installation\\n"
            exit 2
        fi
    fi
    if [ "$(uname)" != "Linux" ]; then
        printf "WARNING:\\n"
        printf "    Your operating system does not appear to be Linux, \\n"
        printf "    but you are trying to install a Linux version of %s.\\n" "${INSTALLER_NAME}"
        printf "    Are sure you want to continue the installation? [yes|no]\\n"
        printf "[no] >>> "
        read -r ans
        ans=$(echo "${ans}" | tr '[:lower:]' '[:upper:]')
        if [ "$ans" != "YES" ] && [ "$ans" != "Y" ]
        then
            printf "Aborting installation\\n"
            exit 2
        fi
    fi

    printf "\\n"
    printf "Welcome to %s %s\\n" "${INSTALLER_NAME}" "${INSTALLER_VER}"
    printf "\\n"
    printf "In order to continue the installation process, please review the license\\n"
    printf "agreement.\\n"
    printf "Please, press ENTER to continue\\n"
    printf ">>> "
    read -r dummy
    pager="cat"
    if command -v "more" > /dev/null 2>&1; then
      pager="more"
    fi
    "$pager" <<'EOF'
Miniforge installer code uses BSD-3-Clause license as stated below.

Binary packages that come with it have their own licensing terms
and by installing miniforge you agree to the licensing terms of individual
packages as well. They include different OSI-approved licenses including
the GNU General Public License and can be found in pkgs/<pkg-name>/info/licenses
folders.

Miniforge installer comes with a bootstrapping executable that is used
when installing miniforge and is deleted after miniforge is installed.
The bootstrapping executable uses micromamba, cli11, cpp-filesystem,
curl, c-ares, krb5, libarchive, libev, lz4, nghttp2, openssl, libsolv,
nlohmann-json, reproc and zstd which are licensed under BSD-3-Clause,
MIT and OpenSSL licenses. Licenses and copyright notices of these
projects can be found at the following URL.
https://github.com/conda-forge/micromamba-feedstock/tree/master/recipe.

=============================================================================

Copyright (c) 2019-2022, conda-forge
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors
may be used to endorse or promote products derived from this software without
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

EOF
    printf "\\n"
    printf "Do you accept the license terms? [yes|no]\\n"
    printf ">>> "
    read -r ans
    ans=$(echo "${ans}" | tr '[:lower:]' '[:upper:]')
    while [ "$ans" != "YES" ] && [ "$ans" != "NO" ]
    do
        printf "Please answer 'yes' or 'no':\\n"
        printf ">>> "
        read -r ans
        ans=$(echo "${ans}" | tr '[:lower:]' '[:upper:]')
    done
    if [ "$ans" != "YES" ]
    then
        printf "The license agreement wasn't approved, aborting installation.\\n"
        exit 2
    fi

    expand_user_input() {
        expanded_prefix=$(echo "${1}" | sed -r "s#^~#$HOME#")
        if command -v envsubst > /dev/null 2>&1; then
            envsubst << EOF
$expanded_prefix
EOF
        else
            echo "$expanded_prefix"
        fi
    }

    printf "\\n"
    printf "%s will now be installed into this location:\\n" "${INSTALLER_NAME}"
    printf "%s\\n" "$PREFIX"
    printf "\\n"
    printf "  - Press ENTER to confirm the location\\n"
    printf "  - Press CTRL-C to abort the installation\\n"
    printf "  - Or specify a different location below\\n"
    if ! command -v envsubst > /dev/null 2>&1; then
        printf "    Note: environment variables will NOT be expanded.\\n"
    fi
    printf "\\n"
    printf "[%s] >>> " "$PREFIX"
    read -r user_prefix
    if [ "$user_prefix" != "" ]; then
        case "$user_prefix" in
            *\ * )
                printf "ERROR: Cannot install into directories with spaces\\n" >&2
                exit 1
                ;;
            *)
                PREFIX="$(expand_user_input "${user_prefix}")"
                ;;
        esac
    fi
fi # !BATCH
case "$PREFIX" in
    *\ * )
        printf "ERROR: Cannot install into directories with spaces\\n" >&2
        exit 1
        ;;
esac

if [ "$FORCE" = "0" ] && [ -e "$PREFIX" ]; then
    printf "ERROR: File or directory already exists: '%s'\\n" "$PREFIX" >&2
    printf "If you want to update an existing installation, use the -u option.\\n" >&2
    exit 1
elif [ "$FORCE" = "1" ] && [ -e "$PREFIX" ]; then
    REINSTALL=1
fi

total_installation_size_kb="644082"
total_installation_size_mb="$(( total_installation_size_kb / 1024 ))"
if ! mkdir -p "$PREFIX"; then
    printf "ERROR: Could not create directory: '%s'.\\n" "$PREFIX" >&2
    printf "Check permissions and available disk space (%s MB needed).\\n" "$total_installation_size_mb" >&2
    exit 1
fi

free_disk_space_kb="$(df -Pk "$PREFIX" | tail -n 1 | awk '{print $4}')"
free_disk_space_kb_with_buffer="$((free_disk_space_kb - 50 * 1024))"  # add 50MB of buffer
if [ "$free_disk_space_kb_with_buffer" -lt "$total_installation_size_kb" ]; then
    printf "ERROR: Not enough free disk space. Only %s MB are available, but %s MB are required (leaving a 50 MB buffer).\\n" \
        "$((free_disk_space_kb_with_buffer / 1024))" "$total_installation_size_mb" >&2
    exit 1
fi

# pwd does not convert two leading slashes to one
# https://github.com/conda/constructor/issues/284
PREFIX=$(cd "$PREFIX"; pwd | sed 's@//@/@')
export PREFIX

printf "PREFIX=%s\\n" "$PREFIX"

# 3-part dd from https://unix.stackexchange.com/a/121798/34459
# Using a larger block size greatly improves performance, but our payloads
# will not be aligned with block boundaries. The solution is to extract the
# bulk of the payload with a larger block size, and use a block size of 1
# only to extract the partial blocks at the beginning and the end.
extract_range () {
    # Usage: extract_range first_byte last_byte_plus_1
    blk_siz=16384
    dd1_beg=$1
    dd3_end=$2
    range_size=$(( dd3_end - dd1_beg ))
    if [ $blk_siz -gt $range_size ]; then
        blk_siz=$range_size
    fi
    dd1_end=$(( ( dd1_beg / blk_siz + 1 ) * blk_siz ))
    dd1_cnt=$(( dd1_end - dd1_beg ))
    dd2_end=$(( dd3_end / blk_siz ))
    dd2_beg=$(( ( dd1_end - 1 ) / blk_siz + 1 ))
    dd2_cnt=$(( dd2_end - dd2_beg ))
    dd3_beg=$(( dd2_end * blk_siz ))
    dd3_cnt=$(( dd3_end - dd3_beg ))
    dd if="$THIS_PATH" bs=1 skip="${dd1_beg}" count="${dd1_cnt}" 2>/dev/null
    dd if="$THIS_PATH" bs="${blk_siz}" skip="${dd2_beg}" count="${dd2_cnt}" 2>/dev/null
    dd if="$THIS_PATH" bs=1 skip="${dd3_beg}" count="${dd3_cnt}" 2>/dev/null
}

# the line marking the end of the shell header and the beginning of the payload
last_line=$(grep -anm 1 '^@@END_HEADER@@' "$THIS_PATH" | sed 's/:.*//')
# first payload: conda.exe
# second payload (optional): supporting files for conda.exe (only in conda-standalone onedir)
# third payload: conda packages
# the start of the first payload, in bytes, indexed from zero
boundary0=$(head -n "${last_line}" "${THIS_PATH}" | wc -c | sed 's/ //g')
# the start of the second payload / the end of the first payload, plus one
boundary1=$(( boundary0 + 17202392 ))
# the start of the third payload / the end of the second payload, plus one
boundary2=$(( boundary1 + 0 ))
# the end of the third payload, plus one
boundary3=$(( boundary2 + 68403200 ))

# verify the MD5 sum of the tarball appended to this header
MD5=$(extract_range "${boundary0}" "${boundary3}" | md5sum -)

if ! echo "$MD5" | grep 3805a4a380ca4cd3626126218d603f9a >/dev/null; then
    printf "WARNING: md5sum mismatch of tar archive\\n" >&2
    printf "expected: 3805a4a380ca4cd3626126218d603f9a\\n" >&2
    printf "     got: %s\\n" "$MD5" >&2
fi

cd "$PREFIX"

# disable sysconfigdata overrides, since we want whatever was frozen to be used
unset PYTHON_SYSCONFIGDATA_NAME _CONDA_PYTHON_SYSCONFIGDATA_NAME

# the first binary payload: the standalone conda executable
printf "Unpacking bootstrapper...\n"
CONDA_EXEC="$PREFIX/micromamba"
extract_range "${boundary0}" "${boundary1}" > "$CONDA_EXEC"
chmod +x "$CONDA_EXEC"
# In case there are packages that depend on _conda
ln -s "$CONDA_EXEC" "$PREFIX"/_conda

export TMP_BACKUP="${TMP:-}"
export TMP="$PREFIX/install_tmp"
mkdir -p "$TMP"

# Check whether the virtual specs can be satisfied
# We need to specify CONDA_SOLVER=classic for conda-standalone
# to work around this bug in conda-libmamba-solver:
# https://github.com/conda/conda-libmamba-solver/issues/480
# micromamba needs an existing pkgs_dir to operate even offline,
# but we haven't created $PREFIX/pkgs yet... give it a temp location
# shellcheck disable=SC2050

# Create $PREFIX/.nonadmin if the installation didn't require superuser permissions
if [ "$(id -u)" -ne 0 ]; then
    touch "$PREFIX/.nonadmin"
fi

# the third binary payload: the tarball of packages
printf "Unpacking payload...\n"
extract_range "${boundary2}" "${boundary3}" | \
    CONDA_QUIET="$BATCH" "$CONDA_EXEC" constructor --extract-tarball --prefix "$PREFIX"

PRECONDA="$PREFIX/preconda.tar.bz2"
CONDA_QUIET="$BATCH" \
"$CONDA_EXEC" constructor --prefix "$PREFIX" --extract-tarball < "$PRECONDA" || exit 1
rm -f "$PRECONDA"

CONDA_QUIET="$BATCH" \
"$CONDA_EXEC" constructor --prefix "$PREFIX" --extract-conda-pkgs || exit 1

MSGS="$PREFIX/.messages.txt"
touch "$MSGS"
export FORCE
test -d ~/.conda || mkdir -p ~/.conda >/dev/null 2>/dev/null || test -d ~/.conda || mkdir ~/.conda

printf "\nInstalling base environment...\n\n"
shortcuts=""
# shellcheck disable=SC2086
CONDA_PROTECT_FROZEN_ENVS="0" \
CONDA_ROOT_PREFIX="$PREFIX" \
CONDA_REGISTER_ENVS="true" \
CONDA_SAFETY_CHECKS=disabled \
CONDA_EXTRA_SAFETY_CHECKS=no \
CONDA_CHANNELS="conda-forge/" \
CONDA_PKGS_DIRS="$PREFIX/pkgs" \
CONDA_QUIET="$BATCH" \
"$CONDA_EXEC" install --offline --file "$PREFIX/conda-meta/initial-state.explicit.txt" -yp "$PREFIX" $shortcuts --no-rc || exit 1
mkdir -p "$PREFIX/envs"
for env_pkgs in "${PREFIX}"/pkgs/envs/*/; do
    env_name=$(basename "${env_pkgs}")
    if [ "$env_name" = "*" ]; then
        continue
    fi
    printf "\nInstalling %s environment...\n\n" "${env_name}"
    mkdir -p "$PREFIX/envs/$env_name"

    if [ -f "${env_pkgs}channels.txt" ]; then
        env_channels=$(cat "${env_pkgs}channels.txt")
        rm -f "${env_pkgs}channels.txt"
    else
        env_channels="conda-forge/"
    fi
    env_shortcuts=""
    # shellcheck disable=SC2086
    CONDA_PROTECT_FROZEN_ENVS="0" \
    CONDA_ROOT_PREFIX="$PREFIX" \
    CONDA_REGISTER_ENVS="true" \
    CONDA_SAFETY_CHECKS=disabled \
    CONDA_EXTRA_SAFETY_CHECKS=no \
    CONDA_CHANNELS="$env_channels" \
    CONDA_PKGS_DIRS="$PREFIX/pkgs" \
    CONDA_QUIET="$BATCH" \
    "$CONDA_EXEC" install --offline --file "$PREFIX/envs/$env_name/conda-meta/initial-state.explicit.txt" -yp "$PREFIX/envs/$env_name" $env_shortcuts --no-rc || exit 1
done
# ----- add condarc
cat <<EOF >"$PREFIX/.condarc"
channels:
  - conda-forge
mirrored_channels:
  conda-forge:
    - https://conda.anaconda.org/conda-forge
    - https://prefix.dev/conda-forge

EOF

POSTCONDA="$PREFIX/postconda.tar.bz2"
CONDA_QUIET="$BATCH" \
"$CONDA_EXEC" constructor --prefix "$PREFIX" --extract-tarball < "$POSTCONDA" || exit 1
rm -f "$POSTCONDA"
rm -rf "$PREFIX/install_tmp"
export TMP="$TMP_BACKUP"

if [ -f "$MSGS" ]; then
  cat "$MSGS"
fi
rm -f "$MSGS"
if [ "$KEEP_PKGS" = "0" ]; then
    rm -rf "$PREFIX"/pkgs
else
    # Attempt to delete the empty temporary directories in the package cache
    # These are artifacts of the constructor --extract-conda-pkgs
    find "$PREFIX/pkgs" -type d -empty -exec rmdir {} \; 2>/dev/null || :
fi

cat <<'EOF'
installation finished.
EOF

if [ "${PYTHONPATH:-}" != "" ]; then
    printf "WARNING:\\n"
    printf "    You currently have a PYTHONPATH environment variable set. This may cause\\n"
    printf "    unexpected behavior when running the Python interpreter in %s.\\n" "${INSTALLER_NAME}"
    printf "    For best results, please verify that your PYTHONPATH only points to\\n"
    printf "    directories of packages that are compatible with the Python interpreter\\n"
    printf "    in %s: %s\\n" "${INSTALLER_NAME}" "$PREFIX"
fi

_maybe_run_conda_init() {
    case $SHELL in
        # We call the module directly to avoid issues with spaces in shebang
        *zsh) "$PREFIX/bin/python" -m conda init zsh ;;
        *) "$PREFIX/bin/python" -m conda init ;;
    esac
    if [ -f "$PREFIX/bin/mamba" ]; then
        # If the version of mamba is <2.0.0, we preferably use the `mamba` python module
        # to perform the initialization.
        #
        # Otherwise (i.e. as of 2.0.0), we use the `mamba shell init` command
        if [ "$("$PREFIX/bin/mamba" --version | head -n 1 | cut -d' ' -f2 | cut -d'.' -f1)" -lt 2 ]; then
            case $SHELL in
                # We call the module directly to avoid issues with spaces in shebang
                *zsh) "$PREFIX/bin/python" -m mamba.mamba init zsh ;;
                *) "$PREFIX/bin/python" -m mamba.mamba init ;;
            esac
        else
            case $SHELL in
                *zsh) "$PREFIX/bin/mamba" shell init --shell zsh ;;
                *) "$PREFIX/bin/mamba" shell init ;;
            esac
        fi
    fi
}

if [ "$BATCH" = "0" ]; then
    DEFAULT=no
    # Interactive mode.

    printf "Do you wish to update your shell profile to automatically initialize conda?\\n"
    printf "This will activate conda on startup and change the command prompt when activated.\\n"
    printf "If you'd prefer that conda's base environment not be activated on startup,\\n"
    printf "   run the following command when conda is activated:\\n"
    printf "\\n"
    printf "conda config --set auto_activate_base false\\n"
    printf "\\n"
    printf "Note: You can undo this later by running \`conda init --reverse \$SHELL\`\\n"
    printf "\\n"
    printf "Proceed with initialization? [yes|no]\\n"
    printf "[%s] >>> " "$DEFAULT"„
    read -r ans
    if [ "$ans" = "" ]; then
        ans=$DEFAULT
    fi
    ans=$(echo "${ans}" | tr '[:lower:]' '[:upper:]')
    if [ "$ans" != "YES" ] && [ "$ans" != "Y" ]
    then
        printf "\\n"
        printf "You have chosen to not have conda modify your shell scripts at all.\\n"
        printf "To activate conda's base environment in your current shell session:\\n"
        printf "\\n"
        printf "eval \"\$(%s/bin/conda shell.YOUR_SHELL_NAME hook)\" \\n" "$PREFIX"
        printf "\\n"
        printf "To install conda's shell functions for easier access, first activate, then:\\n"
        printf "\\n"
        printf "conda init\\n"
        printf "\\n"
    else
        _maybe_run_conda_init
    fi

    printf "Thank you for installing %s!\\n" "${INSTALLER_NAME}"
elif [ "$INIT_CONDA" = "1" ]; then
        printf "Initializing '%s' with 'conda init'...\\n" "$PREFIX"
        _maybe_run_conda_init
fi
if [ "$TEST" = "1" ]; then
    printf "INFO: Running package tests in a subshell\\n"
    NFAILS=0
    (# shellcheck disable=SC1091
     . "$PREFIX"/bin/activate
     which conda-build > /dev/null 2>&1 || conda install -y conda-build
     if [ ! -d "$PREFIX/conda-bld/${INSTALLER_PLAT}" ]; then
         mkdir -p "$PREFIX/conda-bld/${INSTALLER_PLAT}"
     fi
     cp -f "$PREFIX"/pkgs/*.tar.bz2 "$PREFIX/conda-bld/${INSTALLER_PLAT}/"
     cp -f "$PREFIX"/pkgs/*.conda "$PREFIX/conda-bld/${INSTALLER_PLAT}/"
     if [ "$CLEAR_AFTER_TEST" = "1" ]; then
         rm -rf "$PREFIX/pkgs"
     fi
     conda index "$PREFIX/conda-bld/${INSTALLER_PLAT}/"
     conda-build --override-channels --channel local --test --keep-going "$PREFIX/conda-bld/${INSTALLER_PLAT}/"*.tar.bz2
    ) || NFAILS=$?
    if [ "$NFAILS" != "0" ]; then
        if [ "$NFAILS" = "1" ]; then
            printf "ERROR: 1 test failed\\n" >&2
            printf "To re-run the tests for the above failed package, please enter:\\n"
            printf ". %s/bin/activate\\n" "$PREFIX"
            printf "conda-build --override-channels --channel local --test <full-path-to-failed.tar.bz2>\\n"
        else
            printf "ERROR: %s test failed\\n" $NFAILS >&2
            printf "To re-run the tests for the above failed packages, please enter:\\n"
            printf ". %s/bin/activate\\n" "$PREFIX"
            printf "conda-build --override-channels --channel local --test <full-path-to-failed.tar.bz2>\\n"
        fi
        exit $NFAILS
    fi
fi

exit 0