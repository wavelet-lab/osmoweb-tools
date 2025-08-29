# OsmoWeb-Tools
[OsmoWeb-Tools](https://github.com/wavelet-lab/osmoweb-tools) is a repository with helper tools for integrating Osmocom’s mobile communication stack into web backends.

## Description
These tools provide scripts to build, manage, and monitor Osmocom components in a Debian-based environment.

**Repository structure:**
|- [scripts](#osmo-management) - Osmo management scripts
|- [ws-udp-proxy](#ws-udp-proxy) - Qt6-based WebSocket UDP proxy utility for bridging UDP traffic via WebSocket connections

## Osmo Management
These scripts simplify building and managing Osmocom backend components on Debian-based systems.

**Links to the parts:**
- [Building Osmo](#build-osmo-components)
- [Start Osmo Services](#start-osmo-services)
- [Stop Osmo Services](#stop-osmo-services)
- [Watch Osmo Logs](#watch-osmo-logs)

### Build Osmo components
This script runs under the current user, but it requires root privileges to install the necessary packages and to install the built Osmocom utilities and libraries into the system. Before starting, make sure your user account has sudo access.

Build all Osmo components from source code:
```bash
./scripts/build_osmo.sh [OPTIONS]
```

**Options:**
- `-f, --force` - Force removal of the existing osmo directory.
- `-d, --docs` - Enable documentation generation (doxygen).
- `-p, --path <path>` - Specify a custom osmo build path (default: ./osmo). It also changes the config path accordingly, so if you need to change the config path, you must use the `-c` option immediately after the `-p` option.
- `-c, --cfg <path>` - Specify a custom osmo config path (default: ./osmo/config).
- `-q, --quiet` -  Quiet mode – suppress output messages.
- `-h, --help` - Display help message.

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

### Start Osmo services

Start all Osmo services (HLR, STP, MGW, MSC, BSC):
```bash
./scripts/start_osmo.sh [OPTIONS]
```

**Options:**
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

OsmoWeb-Tools is [MIT licensed](https://github.com/wavelet-lab/osmoweb-tools/blob/main/LICENSE).

