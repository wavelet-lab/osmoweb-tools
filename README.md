# OsmoWeb-Tools
[OsmoWeb-Tools](https://github.com/wavelet-lab/osmoweb-tools) is a repository with helper tools for integrating Osmocom’s mobile communication stack into web backends.

## Description
These tools provide scripts to build, manage, and monitor Osmocom components across different Linux distributions.

**Repository structure:**
```
├── scripts/         - Osmo management scripts
└── ws-udp-proxy/    - Qt6-based WebSocket UDP proxy utility for bridging UDP traffic via WebSocket connections
```

**Components:**
- [scripts](#osmo-management) - Osmo management scripts
- [ws-udp-proxy](#ws-udp-proxy) - Qt6-based WebSocket UDP proxy utility for bridging UDP traffic via WebSocket connections

## Osmo Management
These scripts simplify building and managing Osmocom backend components on various Linux distributions.

**Supported distributions:**
- **Debian/Ubuntu** (apt-get)
- **Fedora/RHEL 8+** (dnf)
- **CentOS/RHEL 7** (yum)
- **Arch Linux** (pacman)
- **openSUSE/SLES** (zypper)

The build script automatically detects your package manager and installs the appropriate development packages for your distribution.

**Links to the parts:**
- [Building Osmo](#build-osmo-components)
- [Docker Osmo](#docker-osmo)
- [Start Osmo Services](#start-osmo-services)
- [Stop Osmo Services](#stop-osmo-services)
- [Watch Osmo Logs](#watch-osmo-logs)
- [Control Osmo via VTY](#control-osmo-via-vty)

### Build Osmo components
This script runs under the current user, but it requires root privileges to install the necessary packages and to install the built Osmocom utilities and libraries into the system. Before starting, make sure your user account has sudo access.

The script automatically detects your package manager and installs the appropriate development packages for your Linux distribution.

Build all Osmo components from source code:
```bash
./scripts/build_osmo.sh [OPTIONS]
```

**Options:**
- `-f, --force` - Force removal of the existing osmo directory.
- `-d, --docs` - Enable documentation generation (doxygen).
- `-p, --path <path>` - Specify a custom osmo build path (default: ./osmo). When changing the build path with `-p`, use `-c` to set a custom config path.
- `-c, --cfg <path>` - Specify a custom osmo config path (default: ./osmo/config).
- `-q, --quiet` - Quiet mode – suppress output messages.
- `-h, --help` - Display help message.

**Supported package managers:**
- apt (Debian/Ubuntu)
- dnf (Fedora/RHEL 8+)
- yum (CentOS/RHEL 7)
- pacman (Arch Linux)
- zypper (openSUSE/SLES)

**Environment variables:**
- `OSMO_PATH` - Override default build path.

**Examples:**
```bash
# Basic build
./scripts/build_osmo.sh

# Build with documentation and force rebuild
./scripts/build_osmo.sh -f -d

# Build to a custom path
./scripts/build_osmo.sh -p /opt/osmo
```

### Docker Osmo

Build and run the Osmocom backend in Docker without installing Osmocom libraries and binaries on the host:

```bash
./scripts/docker_osmo.sh [OPTIONS] COMMAND
```

**Commands:**
- `build` - Build the Docker image from Osmocom source repositories.
- `start` - Start Osmo services with Docker Compose.
- `stop` - Stop and remove the Docker Compose service.
- `restart` - Recreate and start the Docker Compose service.
- `logs` - Follow Osmo service log files.
- `status` - Follow Docker container status messages.
- `shell` - Open a shell inside the running container.
- `control SERVICE` - Connect to a service VTY from inside the container.

**Service selectors for `control`:**
- As argument: `osmo-stp`, `osmo-hlr`, `osmo-mgw`, `osmo-msc`, `osmo-bsc`, `osmo-bts-trx`, `osmo-trx`
- Or as flags: `--stp`, `--hlr`, `--mgw`, `--msc`, `--bsc`, `--bts-trx`, `--trx`

**Options:**
- `-b, --bts` - Start also the BTS (Base Transceiver Station) service.
- `-t, --trx {drv}` - Start also `osmo-trx-{drv}` if that binary is available in the image.
- `-d, --docs` - Build the Docker image with documentation tools.
- `-p, --path <path>` - Specify a custom host data path (default: `./osmo`). It also changes config and log paths accordingly.
- `-c, --cfg <path>` - Specify a custom host config path (default: `./osmo/config`).
- `-l, --log <path>` - Specify a custom host log path (default: `./osmo/logs`).
- `-q, --quiet` - Quiet mode.
- `-h, --help` - Display help message.

The wrapper creates the host config and log directories if needed. If the config directory is empty, it extracts the default configs from `scripts/config.tar.gz`.

**Examples:**
```bash
# Build the image
./scripts/docker_osmo.sh build

# Start STP, HLR, MGW, MSC and BSC in Docker
./scripts/docker_osmo.sh start

# Start with BTS
./scripts/docker_osmo.sh -b start

# Follow logs
./scripts/docker_osmo.sh logs

# Follow container status messages
./scripts/docker_osmo.sh status

# Connect to MSC VTY
./scripts/docker_osmo.sh control osmo-msc

# Connect to BSC VTY using flag form
./scripts/docker_osmo.sh control --bsc

# Stop services
./scripts/docker_osmo.sh stop
```

For a private Docker network setup where another backend container talks to Osmo
without publishing VTY ports on the host, use the internal Compose example:

```bash
docker compose -f docker-compose.internal.yml up -d
```

In the same Compose network, other services can reach Osmo by service name, for
example `osmo:4242` for BSC VTY or `osmo:4254` for MSC VTY. The internal example
uses `expose` instead of `ports`, so those ports are documented for Compose
services but not published on the host.

### Start Osmo services

Start all Osmo services (HLR, STP, MGW, MSC, BSC, BTS, TRX):
```bash
./scripts/start_osmo.sh [OPTIONS]
```

**Options:**
- `-b, --bts` - Start also the BTS (Base Transceiver Station) service.
- `-t, --trx {drv}` - Start also the TRX (Transceiver) service with driver {drv}. Valid drivers include: usdr, uhd, usrp, lms, bladeRF, etc. The `-t` option requires the `osmo-bts-trx` program to be running; you can start it yourself, or pass `-b` and the script will start `osmo-bts-trx` for you.
- `-p, --path <path>` - Specify a custom osmo build path (default: ./osmo). It also changes the config and log paths accordingly, so if you need to change config or log paths, you must use the `-c` or `-l` options immediately after the `-p` option.
- `-c, --cfg <path>` - Specify a custom osmo config path (default: ./osmo/config).
- `-l, --log <path>` - Specify a custom osmo log path (default: ./osmo/logs).
- `-q, --quiet` - Quiet mode – suppress output messages.
- `-h, --help` - Display help message.

**Environment variables:**
- `OSMO_PATH` - Override default build path.

This script:
- Verifies all required binaries exist.
- Checks configuration files.
- Creates the logs directory if needed.
- Starts all services in the background with logging to the specified directory.

**Log files:**
- `logs/osmo-stp.log` - Signaling Transfer Point.
- `logs/osmo-hlr.log` - Home Location Register.  
- `logs/osmo-mgw.log` - Media Gateway.
- `logs/osmo-msc.log` - Mobile Switching Center.
- `logs/osmo-bsc.log` - Base Station Controller.
- `logs/osmo-bts-trx.log` - Base Transceiver Station Controller.
- `logs/osmo-trx-{drv}.log` - Transceiver.

**Examples:**
```bash
# Start with default settings
./scripts/start_osmo.sh

# Start with a custom osmo path
./scripts/start_osmo.sh -p /opt/osmo

# Start with custom config and log paths
./scripts/start_osmo.sh -c /etc/osmo -l /var/log/osmo

# Start in quiet mode
./scripts/start_osmo.sh -q

# Start including BTS and TRX with native usdr backend
./scripts/start_osmo.sh -b -t usdr
```

### Stop Osmo services

Gracefully stop all running Osmo processes:
```bash
./scripts/stop_osmo.sh [OPTIONS]
```

**Options:**
- `-q, --quiet` - Quiet mode – suppress output messages.
- `-h, --help` - Display help message.

This script:
1. Finds all running osmo processes.
2. Sends SIGTERM for graceful shutdown (10 seconds timeout).
3. Forces termination with SIGKILL if needed.
4. Verifies that all processes are stopped.

**Configuration variables** (editable in the script):
- `GRACEFUL_TIMEOUT=10` - Seconds to wait for graceful shutdown.
- `CHECK_INTERVAL=1` - Seconds between status checks.  
- `FINAL_TIMEOUT=2` - Seconds to wait after a forced kill.

**Examples:**
```bash
# Stop all services with output
./scripts/stop_osmo.sh

# Stop all services in quiet mode
./scripts/stop_osmo.sh -q
```

### Watch Osmo logs

Monitor all Osmo service logs in real-time:
```bash
./scripts/watch_osmo_logs.sh [OPTIONS]
```

**Options:**
- `-p, --path <path>` - Specify a custom osmo build path (default: ./osmo). It also changes the log paths accordingly, so if you need to change log paths, you must use the `-l` option immediately after the `-p` option.
- `-l, --log <path>` - Specify a custom osmo log path (default: ./osmo/logs).
- `-q, --quiet` - Quiet mode – suppress output messages.
- `-h, --help` - Display help message.

**Environment variables:**
- `OSMO_PATH` - Override default build path.

This script:
- Checks if the log directory exists.
- Monitors all `.log` files in the specified directory.
- Displays real-time log updates using `tail -f`.

**Examples:**
```bash
# Watch default logs
./scripts/watch_osmo_logs.sh

# Watch logs from a custom path
./scripts/watch_osmo_logs.sh -p /opt/osmo

# Watch logs from a specific log directory
./scripts/watch_osmo_logs.sh -l /var/log/osmo
```

### Control Osmo via VTY

Quickly connect to a service's VTY (telnet) port:

```bash
./scripts/control_osmo.sh [OPTIONS] [SERVICE]
```

**Service selectors:**
- As argument: `osmo-stp`, `osmo-hlr`, `osmo-mgw`, `osmo-msc`, `osmo-bsc`, `osmo-bts-trx`, `osmo-trx`
- Or as flags: `--stp`, `--hlr`, `--mgw`, `--msc`, `--bsc`, `--bts-trx`, `--trx`

The script automatically maps services to default VTY ports on localhost:
- STP 4239, HLR 4258, MGW 4243, MSC 4254, BSC 4242

**Options:**
- `-q, --quiet` - Quiet mode – suppress output messages.
- `-h, --help` - Display help message.

Note: Requires a telnet client (e.g., `telnet`/`inetutils-telnet`).

**Examples:**
```bash
# Connect to MSC VTY
./scripts/control_osmo.sh osmo-msc

# Connect to BSC VTY using flag form
./scripts/control_osmo.sh --bsc

# Quiet mode
./scripts/control_osmo.sh -q osmo-stp
```

## ws-udp-proxy

The `ws-udp-proxy` is a Qt6-based WebSocket UDP proxy utility that bridges UDP traffic via WebSocket connections. This tool serves as a testing gateway for integrating Osmocom utilities with web-based backends, specifically designed to work with the web version of osmo-bts.

📖 **For detailed documentation, building instructions, and usage examples, see: [ws-udp-proxy/README.md](ws-udp-proxy/README.md)**

### Purpose and Testing Architecture

This utility is designed for **testing and development purposes** to enable seamless integration between:

- **Frontend**: Special web version of `osmo-bts` that uses WebSocket instead of UDP
- **Backend**: Traditional Osmocom components that communicate via UDP
- **ws-udp-proxy**: Acts as a protocol bridge/gateway for testing scenarios

### Features

- **Dual Mode Operation**: Works as both WebSocket client and server
- **Multi-Socket Support**: Handles three UDP sockets for different data types
- **Clock Synchronization**: Special handling for timing-critical "IND CLOCK" messages
- **Binary & Text Support**: Handles both text commands and binary data transfers
- **Testing Gateway**: Replaces the WS-UDP gateway on backend for development and testing

### Quick Start

```bash
cd ws-udp-proxy
./install_dependencies.sh
mkdir build && cd build
cmake .. && make -j$(nproc)
```

### Integration with Web-Based Osmocom

The ws-udp-proxy serves as a testing bridge in the web-enabled Osmocom architecture:

[Web osmo-bts] ⬅ WebSocket ➡ [ws-udp-proxy] ⬅ UDP ➡ [Backend Osmocom Components]

**Data Flow:**
1. **Web osmo-bts** (frontend) ➡ WebSocket ➡ **ws-udp-proxy** ➡ UDP ➡ **Osmocom Components** (backend)
2. **Osmocom Components** (backend) ➡ UDP ➡ **ws-udp-proxy** ➡ WebSocket ➡ **Web osmo-bts** (frontend)

This architecture enables testing and development of web-based mobile network components while maintaining compatibility with existing UDP-based Osmocom infrastructure.

## License

OsmoWeb-Tools is licensed under the [MIT License](https://github.com/wavelet-lab/osmoweb-tools/blob/main/LICENSE).
