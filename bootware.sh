#!/usr/bin/env bash
#
# Bootstrap software installations with Ansible.


# Exit immediately if a command exists with a non-zero status.
set -e

#######################################
# Show CLI help information.
# Cannot use function name help, since help is a pre-existing command.
# Outputs:
#   Writes help information to stdout.
#######################################
usage() {
  case "$1" in
    bootstrap)
      cat 1>&2 <<EOF
Bootware bootstrap
Boostrap install computer software

USAGE:
    bootware bootstrap [OPTIONS]

OPTIONS:
    -c, --config <PATH>             Path to bootware user configuation file
    -d, --dev                       Run bootstrapping in development mode
    -h, --help                      Print help information
    -i, --inventory <IP-List>       Ansible host IP addesses
        --no-passwd                 Do not ask for user password
        --no-setup                  Skip Bootware dependency installation
    -p, --playbook <FILE-NAME>      Name of play to execute
        --password <PASSWORD>       Remote host user password
    -s, --skip <TAG-LIST>           Ansible playbook tags to skip
    -t, --tags <TAG-LIST>           Ansible playbook tags to select
    -u, --url <URL>                 URL of playbook repository
        --user <USER-NAME>          Remote host user login name
        --winrm                     Use WinRM connection instead of SSH
EOF
      ;;
    config)
      cat 1>&2 <<EOF
Bootware config
Download default Bootware configuration file

USAGE:
    bootware config [OPTIONS]

OPTIONS:
    -d, --dest <PATH>       Path to alternate download destination
    -e, --empty             Write empty configuration file
    -h, --help              Print help information
    -s, --source <URL>      URL to configuration file
EOF
      ;;
    main)
      cat 1>&2 <<EOF
$(version)
Boostrapping software installer

USAGE:
    bootware [OPTIONS] [SUBCOMMAND]

OPTIONS:
    -h, --help       Print help information
    -v, --version    Print version information

SUBCOMMANDS:
    bootstrap        Boostrap install computer software
    config           Generate default Bootware configuration file
    setup            Install dependencies for Bootware
    update           Update Bootware to latest version
EOF
      ;;
    setup)
      cat 1>&2 <<EOF
Bootware setup
Install dependencies for Bootware

USAGE:
    bootware setup [OPTIONS]

OPTIONS:
    -h, --help      Print help information
EOF
      ;;
    update)
      cat 1>&2 <<EOF
Bootware update
Update Bootware to latest version

USAGE:
    bootware update [OPTIONS]

OPTIONS:
    -h, --help                  Print help information
    -v, --version <VERSION>     Version override for update
EOF
      ;;
  esac
}

#######################################
# Assert that command can be found in system path.
# Will exit script with an error code if command is not in system path.
# Arguments:
#   Command to check availabilty.
# Outputs:
#   Writes error message to stderr if command is not in system path.
#######################################
assert_cmd() {
  # Flags:
  #   -v: Only show file path of command.
  if ! command -v "$1" > /dev/null; then
    error "Cannot find required $1 command on computer."
  fi
}

#######################################
# Subcommand to bootstrap software installations.
# Globals:
#   BOOTWARE_CONFIG
#   BOOTWARE_NOPASSWD
#   BOOTWARE_NOSETUP
#   BOOTWARE_PLAYBOOK
#   BOOTWARE_SKIP
#   BOOTWARE_TAGS
#   BOOTWARE_URL
#######################################
bootstrap() {
  # /dev/null is never a normal file.
  local _ask_passwd
  local _ask_passwd_winrm
  local _cmd="pull"
  local _config_path=${BOOTWARE_CONFIG:-"/dev/null"}
  local _inventory="127.0.0.1,"
  local _no_setup=${BOOTWARE_NOSETUP:-""}
  local _passwd
  local _playbook=${BOOTWARE_PLAYBOOK:-"main.yaml"}
  local _skip=${BOOTWARE_SKIP:-""}
  local _tags=${BOOTWARE_TAGS:-""}
  local _url=${BOOTWARE_URL:-"https://github.com/wolfgangwazzlestrauss/bootware.git"}
  local _use_playbook
  local _use_pull=1
  local _user_account=${USER:-root}
  local _winrm

  # Check if Ansible should ask for user password.
  #
  # Flags:
  #     -z: True if string has zero length.
  if [[ -z "${BOOTWARE_NOPASSWD}" ]]; then
    _ask_passwd=1
  fi

  # Parse command line arguments.
  for arg in "$@"; do
    case "$arg" in
      -c|--config)
        _config_path="$2"
        shift 2
        ;;
      -d|--dev)
        _cmd="playbook"
        _use_playbook=1
        _use_pull=""
        shift 1
        ;;
      -h|--help)
        usage "bootstrap"
        exit 0
        ;;
      -i|--inventory)
        _inventory="$2"
        shift 2
        ;;
      --no-passwd)
        _ask_passwd=""
        shift 1
        ;;
      --no-setup)
        _no_setup=1
        shift 1
        ;;
      -p|--playbook)
        _playbook="$2"
        shift 2
        ;;
      --password)
        _passwd="$2"
        shift 2
        ;;
      -s|--skip)
        _skip="$2"
        shift 2
        ;;
      -t|--tags)
        _tags="$2"
        shift 2
        ;;
      -u|--url)
        _url="$2"
        shift 2
        ;;
      --user)
        _user_account="$2"
        shift 2
        ;;
      --winrm)
        _cmd="playbook"
        _use_playbook=1
        _use_pull=""
        _winrm=1
        shift 1
        ;;
      *)
        shift 1 || true
        ;;
    esac
  done

  # Check if Ansible should ask for user password for WinRM connections.
  #
  # Flags:
  #     -n: True if the string has nonzero length.
  #     -z: True if string has zero length.
  if [[ -n "${_winrm}" ]] && [[ -z "${_passwd}" ]]; then
    _ask_passwd_winrm=1
  fi

  # Check if Bootware setup should be run.
  #
  # Flags:
  #     -z: True if string has zero length.
  if [[ -z "$_no_setup" ]]; then
    setup
  fi

  find_config_path "$_config_path"
  _config_path="$RET_VAL"

  echo "Executing Ansible ${_cmd:-pull}..."
  echo "Enter your user account password if prompted."

  ansible-${_cmd}  \
    ${_ask_passwd:+--ask-become-pass} \
    ${_ask_passwd_winrm:+--ask-pass} \
    ${_use_playbook:+--connection local} \
    ${_winrm:+--extra-vars "ansible_connection=winrm"} \
    ${_passwd:+--extra-vars "ansible_password=$_passwd"} \
    ${_winrm:+--extra-vars "ansible_pkg_mgr=scoop"} \
    --extra-vars "ansible_python_interpreter=auto_silent" \
    ${_winrm:+--extra-vars "ansible_user=$_user_account"} \
    ${_winrm:+--extra-vars "ansible_winrm_server_cert_validation=ignore"} \
    ${_winrm:+--extra-vars "ansible_winrm_transport=basic"} \
    --extra-vars "user_account=${_user_account}" \
    --extra-vars "@${_config_path}" \
    --inventory "${_inventory}" \
    ${_use_pull:+--url "$_url"} \
    ${_tags:+--tags "$_tags"} \
    ${_skip:+--skip-tags "$_skip"} \
    "${_playbook}"
}

#######################################
# Subcommand to generate or download Bootware configuration file.
# Globals:
#   HOME
# Arguments:
#   Parent directory of Bootware script.
# Outputs:
#   Writes status information to stdout.
#######################################
config() {
  local src_url="https://raw.githubusercontent.com/wolfgangwazzlestrauss/bootware/master/host_vars/bootware.yaml"
  local dst_file="${HOME}/.bootware/config.yaml"
  local empty_cfg=0

  assert_cmd mkdir

  # Parse command line arguments.
  for arg in "$@"; do
    case "$arg" in
      -d|--dest)
        dst_file="$2"
        shift 2
        ;;
      -e|--empty)
        empty_cfg=1
        shift 1
        ;;
      -h|--help)
        usage "config"
        exit 0
        ;;
      -s|--source)
        src_url="$2"
        shift 2
        ;;
      *)
        shift 1 || true
        ;;
    esac
  done

  mkdir -p "$(dirname "${dst_file}")"

  if [[ ${empty_cfg} == 1 ]]; then
    echo "Writing empty configuration file to ${dst_file}..."
    echo "passwordless_sudo: false" > "${dst_file}"
  else
    assert_cmd curl

    echo "Downloading configuration file to ${dst_file}..."

    # Download default configuration file.
    #
    # FLAGS:
    #   -L: Follow redirect request.
    #   -S: Show errors.
    #   -f: Use archive file. Must be third flag.
    #   -o <path>: Write output to path instead of stdout. 
    curl -LSfs "${src_url}" -o "${dst_file}"
  fi
}

#######################################
# Update dnf package lists.
#
# DNF's check-update command will give a 100 exit code if there are packages
# available to update. Thus both 0 and 100 must be treated as successfully
# exit codes.
#
# Arguments:
#   Whether to use sudo command.
#######################################
dnf_check_update() {
  ${1:+sudo} dnf check-update || { code=$?; [ ${code} -eq 100 ] && return 0; return ${code}; }
}

#######################################
# Print error message and exit script with error code.
# Outputs:
#   Writes error message to stderr if command is not in system path.
#######################################
error() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

#######################################
# Find path of Bootware configuation file.
# Globals:
#   HOME
# Arguments:
#   User supplied configuration path.
# Outputs:
#   Writes error message to stderr if unable to find configuration file.
# Retunrs:
#   Configuration file path.
#######################################
find_config_path() {
  if test -f "$1" ; then
    RET_VAL="$1"
  elif test -f "$(pwd)/bootware.yaml" ; then
    RET_VAL="$(pwd)/bootware.yaml"
  elif test -f "$HOME/.bootware/config.yaml" ; then
    RET_VAL="$HOME/.bootware/config.yaml"
  else
    printf "Unable to find Bootware configuation file.\n"
    config --empty
    RET_VAL="$HOME/.bootware/config.yaml"
  fi

  echo "Using $RET_VAL as configuration file."
}

# Subcommand to configure boostrapping services and utilities.
setup() {
  local arg
  local os_type

  assert_cmd uname

  # Parse command line arguments.
  for arg in "$@"; do
    case "${arg}" in
      -h|--help)
        usage "setup"
        exit 0
        ;;
      *)
        shift 1 || true
        ;;
    esac
  done

  # Get operating system.
  #
  # FLAGS:
  #     -s: Print the kernel name.
  os_type=$(uname -s)

  case "${os_type}" in
    Darwin)
      setup_macos
      ;;
    Linux)
      setup_linux
      ;;
    *)
      error "Operting system ${os_type} is not supported."
      ;;
  esac

  ansible-galaxy collection install community.general > /dev/null
  ansible-galaxy collection install community.windows > /dev/null
}

# Configure boostrapping services and utilities for Arch distributions.
setup_arch() {
  # Install dependencies for Bootware.
  #
  # Flags:
  #   -x: Check if execute permission is granted.
  if ! [ -x "$(command -v ansible)" ]; then
    echo "Installing Ansible..."
    ${1:+sudo} pacman --noconfirm -Suy
    ${1:+sudo} pacman --noconfirm -S ansible
  fi

  if ! [ -x "$(command -v curl)" ]; then
    echo "Installing Curl..."
    ${1:+sudo} pacman --noconfirm -Suy
    ${1:+sudo} pacman -S --noconfirm curl
  fi

  if ! [ -x "$(command -v git)" ]; then
    echo "Installing Git..."
    ${1:+sudo} pacman --noconfirm -Suy
    ${1:+sudo} pacman -S --noconfirm git
  fi
}

# Configure boostrapping services and utilities for Debian distributions.
setup_debian() {
  # Install dependencies for Bootware.
  #
  # Flags:
  #   -x: Check if execute permission is granted.
  if ! [ -x "$(command -v ansible)" ]; then
    # Ansible is install with Python3, since many Debian systems package Ansible
    # version 2.7, which does not support Ansible collections.
    echo "Installing Ansible..."
    ${1:+sudo} apt-get -qq update
    ${1:+sudo} apt-get -qq install -y python3 python3-pip python3-apt

    # Not all Python installations have setuptools or wheel installed and it
    # must be installed as a separate step before other packages.
    ${1:+sudo} python3 -m pip install setuptools wheel
    ${1:+sudo} python3 -m pip install ansible
  fi

  if ! [ -x "$(command -v curl)" ]; then
    echo "Installing Curl..."
    ${1:+sudo} apt-get -qq update
    ${1:+sudo} apt-get -qq install -y curl
  fi

  if ! [ -x "$(command -v git)" ]; then
    echo "Installing Git..."
    ${1:+sudo} apt-get -qq update
    ${1:+sudo} apt-get -qq install -y git
  fi
}

# Configure boostrapping services and utilities for Fedora distributions.
setup_fedora() {
  # Install dependencies for Bootware.
  #
  # Flags:
  #   -x: Check if execute permission is granted.
  if ! [ -x "$(command -v ansible)" ]; then
    echo "Installing Ansible..."
    dnf_check_update "$1"
    ${1:+sudo} dnf install -y ansible
  fi

  if ! [ -x "$(command -v curl)" ]; then
    echo "Installing Curl..."
    dnf_check_update "$1"
    ${1:+sudo} dnf install -y curl
  fi

  if ! [ -x "$(command -v git)" ]; then
    echo "Installing Git..."
    dnf_check_update "$1"
    ${1:+sudo} dnf install -y git
  fi
}

# Configure boostrapping services and utilities for Linux.
setup_linux() {
  local use_sudo

  if [[ ${EUID} != 0 ]]; then
    use_sudo=1
  fi

  # Install dependencies for Bootware base on available package manager.
  #
  # Flags:
  #   -v: Only show file path of command.
  if command -v pacman &>/dev/null ; then
    setup_arch ${use_sudo}
  elif command -v apt-get &>/dev/null ; then
    setup_debian ${use_sudo}
  elif command -v dnf &>/dev/null ; then
    setup_fedora ${use_sudo}
  else
    error "Unable to find supported package manager."
  fi
}

# Configure boostrapping services and utilities for MacOS.
setup_macos() {
  assert_cmd curl

  # Install XCode command line tools if not already installed.
  #
  # Homebrew depends on the XCode command line tools.
  if ! xcode-select -p &>/dev/null ; then
    echo "Installing command line tools for XCode..."
    sudo xcode-select --install
  fi

  # Install Homebrew if not already installed.
  #
  # FLAGS:
  #     -L: Follow redirect request.
  #     -S: Show errors.
  #     -f: Fail silently on server errors.
  #     -s: Disable progress bars.
  #     -x: Check if execute permission is granted.
  if ! [ -x "$(command -v brew)" ]; then
    echo "Installing Homebrew..."
    curl -LSfs "https://raw.githubusercontent.com/Homebrew/install/master/install.sh" | bash
  fi

  # Install Ansible if not already installed.
  if ! [ -x "$(command -v ansible)" ]; then
    echo "Installing Ansible..."
    brew install ansible
  fi

  # Install Git if not already installed.
  if ! [ -x "$(command -v git)" ]; then
    echo "Installing Git.."
    brew install git
  fi
}

#######################################
# Subcommand to update Bootware script
# Arguments:
#   Parent directory of Bootware script.
# Outputs:
#   Writes status information and updated Bootware version to stdout.
#######################################
update() {
  local dst_file
  local src_url
  local use_sudo
  local version="master"

  assert_cmd chmod
  assert_cmd curl

  # Cannot use realpath command, since it is not built into MacOS.
  #
  # Flags:
  #   -P: Resolve any symbolic links in the path.
  dst_file="$(cd "$(dirname "$0")"; pwd -P)/$(basename "$0")"

  # Parse command line arguments.
  for arg in "$@"; do
    case "${arg}" in
      -h|--help)
        usage "update"
        exit 0
        ;;
      -v|--version)
        version="$2"
        shift 2
        ;;
      *)
        shift 1 || true
        ;;
    esac
  done

  src_url="https://raw.githubusercontent.com/wolfgangwazzlestrauss/bootware/${version}/bootware.sh"

  # Use sudo for system installation if user is not root.
  #
  # Flags:
  #   -O: True if file is owned by the current user.
  if [[ ! -O "${dst_file}" || ${EUID} != 0 ]]; then
    assert_cmd sudo
    use_sudo=1
  fi

  echo "Updating Bootware..."

  ${use_sudo:+sudo} curl -LSfs "${src_url}" -o "${dst_file}"
  ${use_sudo:+sudo} chmod 755 "${dst_file}"

  echo "Updated to version $(bootware --version)."
}

#######################################
# Print Bootware version string.
# Outputs:
#   Bootware version string.
#######################################
version() {
  echo "Bootware 0.3.0"
}

#######################################
# Script entrypoint.
#######################################
main() {
  # Parse command line arguments.
  for arg in "$@"; do
    case "${arg}" in
      bootstrap)
        shift 1
        bootstrap "$@"
        exit 0
        ;;
      config)
        shift 1
        config "$@"
        exit 0
        ;;
      setup)
        shift 1
        setup "$@"
        exit 0
        ;;
      update)
        shift 1
        update "$@"
        exit 0
        ;;
      -v|--version)
        version
        exit 0
        ;;
      *)
        shift 1 || true
        ;;
    esac
  done

  usage "main"
}

main "$@"
