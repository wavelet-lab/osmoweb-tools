# ws-udp-proxy

WebSocket UDP Proxy is a Qt6-based testing utility that bridges UDP traffic via WebSocket connections. This tool is specifically designed for testing and development of web-based Osmocom integrations, serving as a protocol gateway between WebSocket-enabled frontend applications and UDP-based backend components.

## Purpose

This utility serves as a **testing gateway** that enables:

- **Web osmo-bts** (frontend) to communicate with traditional Osmocom components via WebSocket
- **Backend testing** by replacing the WS-UDP gateway functionality 
- **Development environment** setup for web-enabled mobile network components

### Architecture

[Web osmo-bts] ⬅ WebSocket ➡ [ws-udp-proxy] ⬅ UDP ➡ [Osmocom Backend Components]

The web version of osmo-bts uses WebSocket instead of UDP, while traditional Osmocom components continue using UDP communication. This proxy bridges that gap for testing purposes.

## Dependencies

The following libraries are required for building:

### Automatic Installation
You can install all required dependencies automatically using the provided script:
```bash
./install_dependencies.sh
```

This script automatically detects your package manager (apt, dnf, yum, pacman, zypper) and installs the appropriate packages.

### Manual Installation

#### Ubuntu/Debian (APT):
```bash
sudo apt-get update
sudo apt-get install build-essential cmake pkg-config qt6-base-dev qt6-websockets-dev
```

#### Fedora (DNF):
```bash
sudo dnf install gcc-c++ cmake pkgconfig qt6-qtbase-devel qt6-qtwebsockets-devel
```

#### CentOS/RHEL (YUM):
```bash
# Enable EPEL repository first
sudo yum install epel-release
sudo yum install gcc-c++ cmake pkgconfig qt6-qtbase-devel qt6-qtwebsockets-devel
```

#### Arch Linux (Pacman):
```bash
sudo pacman -S base-devel cmake pkgconf qt6-base qt6-websockets
```

#### openSUSE/SUSE (Zypper):
```bash
sudo zypper install gcc-c++ cmake pkg-config qt6-base-devel qt6-websockets-devel
```

## Building

```bash
mkdir build
cd build
cmake ..
make -j$(nproc)
```

## Usage

The application supports both client and server modes for WebSocket connections:

### Client mode (connect to WebSocket server):
```bash
./ws-udp-proxy -u ws://127.0.0.1:8880 -p 5000 -r 6000 -d
```

### Server mode (create WebSocket server):
```bash
./ws-udp-proxy -p 5000 -r 6000 -l 8880 -b 127.0.0.1 -d
```

### Parameters:
- `-p, --base-port PORT` - UDP base port for receiving (default 5000)
- `-r, --remote-port PORT` - UDP base port for sending (default 6000)
- `-l, --ws-port PORT` - WebSocket server port (0 = client mode, default 0)
- `-u, --ws-url URL` - URL to connect to WebSocket server (default ws://localhost:8880)
- `-b, --ws-bind ADDR` - WebSocket bind address (default 127.0.0.1)
- `-d, --debug` - enable debug output
- `-h, --help` - display help message

### Functionality:
- Qt6-based WebSocket implementation
- Support for text and binary WebSocket messages
- Bidirectional bridging between WebSocket and UDP protocols
- Support for both client and server modes
- Special handling for clock synchronization messages
- **Testing gateway** for web-enabled Osmocom components
- **Protocol bridge** between WebSocket frontend and UDP backend
- **Development tool** for osmo-bts web integration testing

### UDP Sockets:
The application creates three UDP sockets with consecutive port numbers:
- **UDP socket 0**: Clock synchronization (CLOCK) - handles "IND CLOCK" messages
- **UDP socket 1**: Command data (CMD) - handles text commands
- **UDP socket 2**: Binary data (DATA) - handles binary data transfers

All sockets use the base port as a starting point (e.g., if base port is 5000, sockets will be on ports 5000, 5001, 5002).

## Testing Scenarios

### Testing with Web osmo-bts
When testing the web version of osmo-bts, the proxy acts as a bridge:

1. **Start the proxy in server mode** (listens for WebSocket connections):
```bash
./ws-udp-proxy -l 8880 -p 5000 -r 6000 -d
```

2. **Configure web osmo-bts** to connect to `ws://localhost:8880`

3. **Start backend Osmocom components** configured to communicate on UDP ports 6000-6002

### Testing Backend Integration
For testing backend communication without a web frontend:

1. **Start the proxy in client mode** (connects to existing WebSocket server):
```bash
./ws-udp-proxy -u ws://backend-server:8880 -p 5000 -r 6000 -d
```

2. **Send UDP packets** to ports 5000-5002 to test WebSocket forwarding

This allows testing the WebSocket-UDP bridge functionality independently of the full web osmo-bts setup.
