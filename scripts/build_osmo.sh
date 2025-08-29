#!/usr/bin/env bash

me=$(basename "$0")

APT_CMD="sudo apt-get"
APT_UPDATE_ARGS="-y update"
APT_INSTALL_ARGS="-y install"
OSMO_INSTALL_PREFIX="/usr/local"

# Color definitions
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    BOLD=""
    RESET=""
fi

# Default values
force_remove=false
enable_docs=false
quiet_mode=false
osmo_path="${OSMO_PATH:-$(pwd)/osmo}"
cfg_path="${osmo_path}/config"
config_archive="config.tar.gz"

# Function to show usage
show_usage() {
    echo "${BOLD}Usage:${RESET} $1 [OPTIONS]"
    echo "${BOLD}Options:${RESET}"
    echo "  ${CYAN}-f, --force${RESET}    Force removal of the existing osmo directory."
    echo "  ${CYAN}-d, --docs${RESET}     Enable documentation generation (doxygen)"
    echo "  ${CYAN}-p, --path${RESET}     Specify a custom osmo build path (default: ./osmo)."
    echo "                 It also changes the config path accordingly"
    echo "                 so if you need to change config path,"
    echo "                 you need use -c options next after -p option."
    echo "  ${CYAN}-c, --cfg${RESET}      Specify a custom osmo config path (default: ./osmo/config)."
    echo "  ${CYAN}-q, --quiet${RESET}    Quiet mode - suppress output messages."
    echo "  ${CYAN}-h, --help${RESET}     Show this help message."
    echo ""
    echo "${BOLD}Environment variables:${RESET}"
    echo "  ${CYAN}OSMO_PATH${RESET}      Override default build path"
    exit 0
}

# Function for output (respects quiet mode)
log_output() {
    if [ "$quiet_mode" = false ]; then
        echo "$@"
    fi
}

# Function for error messages
log_error() {
    echo "${RED}Error:${RESET} $@" >&2
}

# Function for success messages
log_success() {
    if [ "$quiet_mode" = false ]; then
        echo "${GREEN}$@${RESET}"
    fi
}

# Function for warning messages
log_warning() {
    if [ "$quiet_mode" = false ]; then
        echo "${YELLOW}Warning:${RESET} $@"
    fi
}

# Function for info messages
log_info() {
    if [ "$quiet_mode" = false ]; then
        echo "${BLUE}$@${RESET}"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            force_remove=true
            shift
            ;;
        -d|--docs)
            enable_docs=true
            shift
            ;;
        -p|--path)
            osmo_path="$2"
            cfg_path="${osmo_path}/config"
            shift 2
            ;;
        -c|--cfg)
            cfg_path="$2"
            shift 2
            ;;
        -q|--quiet)
            quiet_mode=true
            shift
            ;;
        -h|--help)
            show_usage $me
            ;;
        *)
            log_error "Unknown option: $1\n" \
                      "Use ${CYAN}-h${RESET} or ${CYAN}--help${RESET} for usage information"
            exit 1
            ;;
    esac
done

# Function to remove old builds
remove_old_builds() {
    log_output "Removing old Osmo builds..."
    
    # Remove libraries
    sudo rm -f ${OSMO_INSTALL_PREFIX}/lib/libosmo*
    sudo rm -f ${OSMO_INSTALL_PREFIX}/lib64/libosmo*

    # Remove pkg-config files
    sudo rm -f ${OSMO_INSTALL_PREFIX}/lib/pkgconfig/libosmo*

    # Remove headers
    sudo rm -rf ${OSMO_INSTALL_PREFIX}/include/osmocom/

    # Remove binaries
    sudo rm -f ${OSMO_INSTALL_PREFIX}/bin/osmo-*

    # Refresh shared library cache
    sudo ldconfig

    log_success "Old builds removed successfully"
}

# Function to install required packages
install_required_packages() {
    log_output "Installing required packages..."

    $APT_CMD $APT_UPDATE_ARGS

    # Basic build tools
    $APT_CMD $APT_INSTALL_ARGS \
        build-essential \
        autoconf \
        automake \
        libtool \
        pkg-config \
        git \
        cmake

    # Core libraries for libosmocore
    $APT_CMD $APT_INSTALL_ARGS \
        libgnutls28-dev \
        libsctp-dev \
        libtalloc-dev \
        libpcsclite-dev \
        libusb-1.0-0-dev \
        libmnl-dev \
        libsystemd-dev

    # Network and RTP libraries
    $APT_CMD $APT_INSTALL_ARGS \
        liburing-dev \
        libortp-dev \
        libosip2-dev \
        libsofia-sip-ua-dev

    # Database libraries
    $APT_CMD $APT_INSTALL_ARGS \
        libsqlite3-dev \
        libdbi-dev \
        libdbd-sqlite3

    # SMPP and additional protocols
    $APT_CMD $APT_INSTALL_ARGS \
        libssl-dev \
        libc-ares-dev \
        libsmpp34-dev

    # Documentation tools (optional)
    if [ "$enable_docs" = true ]; then
        log_output "Installing documentation tools..."
        $APT_CMD $APT_INSTALL_ARGS \
            doxygen \
            graphviz
    fi
}

# Function to extract configuration files
extract_config_files() {
    local config_file="$1"
    local target_path="$2"

    log_output "Extracting configuration files..."

    if [ ! -f "$config_file" ]; then
        log_warning "Config archive not found: $config_file"
        log_output "Creating empty config directory: $target_path"
        mkdir -p "$target_path"
        return 0
    fi
    
    # Create target directory if it doesn't exist
    mkdir -p "$target_path"
    
    # Extract archive to config directory
    if tar -xzf "$config_file" -C "$target_path"; then
        log_success "Successfully extracted config files to: $target_path"
        return 0
    else
        log_error "Failed to extract config archive"
        return 1
    fi
}

# Function to get specific configure options for each repository
get_configure_options() {
    local repo_name="$1"
    local options="--prefix=${OSMO_INSTALL_PREFIX}"
    local doxygen_options=$([ "$enable_docs" = false ] && echo "--disable-doxygen" || echo "")

    case "$repo_name" in
        "libosmocore")
            options="$options $doxygen_options --enable-libsctp --enable-gnutls"
            ;;
        "libosmo-netif")
            options="$options $doxygen_options"
            ;;
        "libosmo-abis")
            options="$options --disable-dahdi --enable-ortp"
            ;;
        "libosmo-sccp")
            options="$options $doxygen_options"
            ;;
        "libosmo-sigtran")
            options="$options $doxygen_options"
            ;;
        "osmo-mgw")
            options="$options"
            ;;
        "osmo-hlr")
            options="$options"
            ;;
        "osmo-msc")
            options="$options --enable-smpp"
            ;;
        "osmo-bsc")
            options="$options"
            ;;
        "osmo-bts")
            options="$options --enable-trx"
            ;;
        *)
            options="$options"
            ;;
    esac
    
    echo "$options"
}

# Function to clone Osmo repositories
clone_osmo_repositories() {
    local osmo_path="$1"
    local repositories=(
        "https://gitea.osmocom.org/osmocom/libosmocore"
        "https://gitea.osmocom.org/osmocom/libosmo-netif"
        "https://gitea.osmocom.org/osmocom/libosmo-abis"
        "https://gitea.osmocom.org/osmocom/libosmo-sccp"
        "https://gitea.osmocom.org/osmocom/libosmo-sigtran"
        "https://gitea.osmocom.org/cellular-infrastructure/osmo-mgw"
        "https://gitea.osmocom.org/cellular-infrastructure/osmo-hlr"
        "https://gitea.osmocom.org/cellular-infrastructure/osmo-msc"
        "https://gitea.osmocom.org/cellular-infrastructure/osmo-bsc"
        "https://gitea.osmocom.org/cellular-infrastructure/osmo-bts"
    )

    log_output "Starting clone and build process..."

    cd "$osmo_path"
    
    # Clone repositories
    for repo in "${repositories[@]}"; do
        repo_name=$(basename "$repo" .git)
        log_output "Cloning $repo_name..."

        if git clone "$repo"; then
            log_success "Successfully cloned $repo_name"
        else
            log_error "Failed to clone $repo_name"
            return 1
        fi
    done

    log_success "All repositories cloned successfully!"
}

# Function to build Osmo repositories
build_osmo_repositories() {
    local osmo_path="$1"

    # Build repositories in dependency order
    local build_order=(
        "libosmocore"
        "libosmo-netif"
        "libosmo-abis"
        "libosmo-sccp"
        "libosmo-sigtran"
        "osmo-mgw"
        "osmo-hlr"
        "osmo-msc"
        "osmo-bsc"
        "osmo-bts"
    )

    log_output "Building repositories in dependency order..."

    for repo in "${build_order[@]}"; do
        log_output "Building $repo..."
        cd "$osmo_path/$repo" || continue

        # Standard autotools build process
        if [ -f "configure.ac" ] || [ -f "configure.in" ]; then
            # Recreate configuration files
            if ! autoreconf -fi; then
                log_error "Failed to run autoreconf for $repo"
                exit 1
            fi

            # Get specific configure options for the repository
            local configure_opts=$(get_configure_options "$repo")
            log_output "Configure options for $repo: $configure_opts"
            if ! ./configure $configure_opts; then
                log_error "Failed to configure $repo"
                exit 1
            fi

            # Build the project
            if ! make -j$(nproc); then
                log_error "Failed to build $repo"
                exit 1
            fi

            # Install the built project
            if ! sudo make install; then
                log_error "Failed to install $repo"
                exit 1
            fi
            
            if ! sudo ldconfig; then
                log_error "Failed to update library cache after installing $repo"
                exit 1
            fi
        else
            log_warning "No configure script found for $repo"
        fi

        log_success "Finished building $repo"
    done

    log_success "All repositories built successfully!"
    log_output "Osmo binaries installed to: ${BOLD}${OSMO_INSTALL_PREFIX}/bin/${RESET}"
}

# Main

# Check for existing directory
if [ -d "$osmo_path" ]; then
    if [ "$force_remove" = true ]; then
        log_output "Force flag detected. Removing existing directory: $osmo_path"
        rm -rf "$osmo_path"
    else
        log_error "Osmo path already exists: $osmo_path\n" \
                  "Use -f or --force flag to remove existing directory"
        exit 1
    fi
fi

mkdir -p "$osmo_path"

log_output "Building Osmo in path: ${BOLD}$osmo_path${RESET}"
log_output "Config path: ${BOLD}$cfg_path${RESET}"

# Remove old builds
remove_old_builds

# Install required packages
install_required_packages

# Extract configuration files
extract_config_files "$config_archive" "$cfg_path"

cd "$osmo_path"
osmo_path_full=$(pwd)

# Clone Osmo repositories
clone_osmo_repositories "$osmo_path_full"

# Call the function
build_osmo_repositories "$osmo_path_full"
