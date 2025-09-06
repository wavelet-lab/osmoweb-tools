#!/usr/bin/env bash

# shellcheck source-path=SCRIPTDIR

me=$(basename "$0")

# Source shared library (relative to this script's location)
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd)"
# shellcheck source=lib/libosmolog.sh
. "${SCRIPT_DIR}/lib/libosmolog.sh"

# Constants
OSMO_INSTALL_PREFIX="/usr/local"

# Default values
force_remove=false
enable_docs=false
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
	echo "${BOLD}Supported package managers:${RESET}"
	echo "  • apt-get (Debian/Ubuntu)"
	echo "  • dnf (Fedora/RHEL 8+)"
	echo "  • yum (CentOS/RHEL 7)"
	echo "  • pacman (Arch Linux)"
	echo "  • zypper (openSUSE/SLES)"
	echo ""
	echo "${BOLD}Environment variables:${RESET}"
	echo "  ${CYAN}OSMO_PATH${RESET}      Override default build path"
	exit 0
}

# Use library logging; default level info
export LOG_LEVEL=${LOG_LEVEL:-info}
export QUIET=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	-f | --force)
		force_remove=true
		shift
		;;
	-d | --docs)
		enable_docs=true
		shift
		;;
	-p | --path)
		osmo_path="$2"
		cfg_path="${osmo_path}/config"
		shift 2
		;;
	-c | --cfg)
		cfg_path="$2"
		shift 2
		;;
	-q | --quiet)
		export QUIET=true
		shift
		;;
	-h | --help)
		show_usage "$me"
		;;
	*)
		log_error "Unknown option: $1"
		log_info "Use -h or --help for usage information"
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

# Package manager detection and configuration
PACKAGE_MANAGER=""
PKG_CMD=""
PKG_UPDATE_ARGS=""
PKG_INSTALL_ARGS=""

# Function to detect package manager
detect_package_manager() {
	if command -v apt-get >/dev/null 2>&1; then
		PACKAGE_MANAGER="apt"
		PKG_CMD="sudo apt-get"
		PKG_UPDATE_ARGS="-y update"
		PKG_INSTALL_ARGS="-y install"
	elif command -v dnf >/dev/null 2>&1; then
		PACKAGE_MANAGER="dnf"
		PKG_CMD="sudo dnf"
		PKG_UPDATE_ARGS="makecache"
		PKG_INSTALL_ARGS="-y install"
	elif command -v yum >/dev/null 2>&1; then
		PACKAGE_MANAGER="yum"
		PKG_CMD="sudo yum"
		PKG_UPDATE_ARGS="makecache"
		PKG_INSTALL_ARGS="-y install"
	elif command -v pacman >/dev/null 2>&1; then
		PACKAGE_MANAGER="pacman"
		PKG_CMD="sudo pacman"
		PKG_UPDATE_ARGS="-Sy"
		PKG_INSTALL_ARGS="-S --noconfirm"
	elif command -v zypper >/dev/null 2>&1; then
		PACKAGE_MANAGER="zypper"
		PKG_CMD="sudo zypper"
		PKG_UPDATE_ARGS="refresh"
		PKG_INSTALL_ARGS="-n install"
	else
		log_error "No supported package manager found (apt, dnf, yum, pacman, zypper)"
		exit 1
	fi

	log_output "Detected package manager: $PACKAGE_MANAGER"
}

# Function to check if a package is available
check_package_available() {
	local package="$1"

	case "$PACKAGE_MANAGER" in
	"apt")
		apt-cache search "^${package}$" | grep -q "^${package}"
		;;
	"dnf")
		dnf list available "$package" >/dev/null 2>&1
		;;
	"yum")
		yum list available "$package" >/dev/null 2>&1
		;;
	"pacman")
		pacman -Ss "^${package}$" >/dev/null 2>&1
		;;
	"zypper")
		zypper se -x "$package" >/dev/null 2>&1
		;;
	*)
		# If we can't check, assume it's available
		return 0
		;;
	esac
}

# Function to get build packages
get_build_packages() {
	case "$PACKAGE_MANAGER" in
	"apt")
		echo "build-essential autoconf automake libtool pkg-config git cmake"
		;;
	"dnf" | "yum")
		echo "gcc gcc-c++ make autoconf automake libtool pkgconfig git cmake"
		;;
	"pacman")
		echo "base-devel autoconf automake libtool pkgconf git cmake"
		;;
	"zypper")
		echo "gcc gcc-c++ make autoconf automake libtool pkg-config git cmake"
		;;
	esac
}

# Function to get core packages
get_core_packages() {
	case "$PACKAGE_MANAGER" in
	"apt")
		echo "libgnutls28-dev libsctp-dev libtalloc-dev libpcsclite-dev libusb-1.0-0-dev libmnl-dev libsystemd-dev"
		;;
	"dnf" | "yum")
		echo "gnutls-devel lksctp-tools-devel libtalloc-devel pcsc-lite-devel libusb1-devel libmnl-devel systemd-devel"
		;;
	"pacman")
		echo "gnutls lksctp-tools talloc pcsclite libusb libmnl systemd-libs"
		;;
	"zypper")
		echo "libgnutls-devel lksctp-tools-devel libtalloc-devel pcsc-lite-devel libusb-1_0-devel libmnl-devel systemd-devel"
		;;
	esac
}

# Function to get network packages
get_network_packages() {
	case "$PACKAGE_MANAGER" in
	"apt")
		local apt_packages="libortp-dev libosip2-dev libsofia-sip-ua-dev"
		# liburing-dev may not be available on older Ubuntu versions
		if check_package_available "liburing-dev"; then
			apt_packages+=" liburing-dev"
		fi
		echo "$apt_packages"
		;;
	"dnf" | "yum")
		echo "liburing-devel ortp-devel libosip2-devel sofia-sip-devel"
		;;
	"pacman")
		echo "liburing ortp libosip2 sofia-sip"
		;;
	"zypper")
		echo "liburing-devel libortp-devel libosip2-devel libsofia-sip-ua-devel"
		;;
	esac
}

# Function to get database packages
get_database_packages() {
	case "$PACKAGE_MANAGER" in
	"apt")
		echo "libsqlite3-dev libdbi-dev libdbd-sqlite3"
		;;
	"dnf" | "yum")
		echo "sqlite-devel libdbi-devel libdbi-dbd-sqlite"
		;;
	"pacman")
		echo "sqlite libdbi"
		;;
	"zypper")
		echo "sqlite3-devel libdbi-devel libdbi-drivers-dbd-sqlite3"
		;;
	esac
}

# Function to get SSL packages
get_ssl_packages() {
	case "$PACKAGE_MANAGER" in
	"apt")
		local apt_packages="libssl-dev libc-ares-dev"
		# libsmpp34-dev may not be available, try to install what's available
		if check_package_available "libsmpp34-dev"; then
			apt_packages+=" libsmpp34-dev"
		fi
		echo "$apt_packages"
		;;
	"dnf" | "yum")
		echo "openssl-devel c-ares-devel"
		;;
	"pacman")
		echo "openssl c-ares"
		;;
	"zypper")
		echo "libopenssl-devel libcares-devel"
		;;
	esac
}

# Function to get documentation packages
get_doc_packages() {
	case "$PACKAGE_MANAGER" in
	"apt")
		echo "doxygen graphviz"
		;;
	"dnf" | "yum")
		echo "doxygen graphviz"
		;;
	"pacman")
		echo "doxygen graphviz"
		;;
	"zypper")
		echo "doxygen graphviz"
		;;
	esac
}

# Function to install packages with error handling
install_package_group() {
	local group_name="$1"
	local packages="$2"
	local critical="$3" # true/false - whether failure should stop the script

	if [ -z "$packages" ]; then
		log_warning "No $group_name packages defined for $PACKAGE_MANAGER"
		return 0
	fi

	log_output "Installing $group_name..."
	# shellcheck disable=SC2086 # intentional word splitting for package manager args and package list
	if $PKG_CMD $PKG_INSTALL_ARGS $packages; then
		log_success "$group_name installed successfully"
		return 0
	else
		if [ "$critical" = "true" ]; then
			log_error "Failed to install critical $group_name packages"
			exit 1
		else
			log_warning "Some $group_name packages may not be available on this distribution"
			return 1
		fi
	fi
}

# Function to install required packages
install_required_packages() {
	log_output "Installing required packages using $PACKAGE_MANAGER..."

	# Detect package manager if not already done
	if [ -z "$PACKAGE_MANAGER" ]; then
		detect_package_manager
	fi

	# Update package cache
	log_output "Updating package cache..."
	# shellcheck disable=SC2086 # intentional word splitting for package manager args
	if ! $PKG_CMD $PKG_UPDATE_ARGS; then
		log_error "Failed to update package cache"
		exit 1
	fi

	# Install package groups
	install_package_group "build tools" "$(get_build_packages)" "true"
	install_package_group "core libraries" "$(get_core_packages)" "true"
	install_package_group "network libraries" "$(get_network_packages)" "true"
	install_package_group "database libraries" "$(get_database_packages)" "true"

	# SSL packages - install each separately for better error handling
	SSL_PACKAGES=$(get_ssl_packages)
	for pkg in $SSL_PACKAGES; do
		install_package_group "SSL package ($pkg)" "$pkg" "false"
	done

	# Documentation tools (optional)
	if [ "$enable_docs" = true ]; then
		install_package_group "documentation tools" "$(get_doc_packages)" "false"
	fi

	log_success "Package installation completed"
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
	local options
	options="--prefix=${OSMO_INSTALL_PREFIX}"
	local doxygen_options
	doxygen_options=$([ "$enable_docs" = false ] && echo "--disable-doxygen" || echo "")

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
	"osmo-mgw") ;;
	"osmo-hlr") ;;
	"osmo-msc")
		options="$options --enable-smpp"
		;;
	"osmo-bsc") ;;
	"osmo-bts")
		options="$options --enable-trx"
		;;
	*)
		:
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

	cd "$osmo_path" || exit

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
	local osmo_path
	osmo_path="$1"

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
			local configure_opts
			configure_opts=$(get_configure_options "$repo")
			log_output "Configure options for $repo: $configure_opts"
			# Convert options string into an array to preserve word boundaries and avoid SC2086
			# shellcheck disable=SC2206 # we intentionally split the options into an array
			local opts_array=($configure_opts)
			if ! ./configure "${opts_array[@]}"; then
				log_error "Failed to configure $repo"
				exit 1
			fi

			# Build the project
			if ! make -j"$(nproc)"; then
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
		log_error "Osmo path already exists: $osmo_path"
		log_info "Use -f or --force flag to remove existing directory"
		exit 1
	fi
fi

mkdir -p "$osmo_path"

log_output "Building Osmo in path: ${BOLD}$osmo_path${RESET}"
log_output "Config path: ${BOLD}$cfg_path${RESET}"

# Remove old builds
remove_old_builds

# Detect package manager
detect_package_manager

# Install required packages
install_required_packages

# Extract configuration files
extract_config_files "$config_archive" "$cfg_path"

cd "$osmo_path" || exit
osmo_path_full=$(pwd)

# Clone Osmo repositories
clone_osmo_repositories "$osmo_path_full"

# Call the function
build_osmo_repositories "$osmo_path_full"
