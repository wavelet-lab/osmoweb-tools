#!/usr/bin/env bash

if command -v apt-get &>/dev/null; then
	echo "Detected apt-get package manager. Installing dependencies..."
	sudo apt-get update
	sudo apt-get install -y build-essential cmake pkg-config qt6-base-dev qt6-websockets-dev
elif command -v dnf &>/dev/null; then
	echo "Detected dnf package manager. Installing dependencies..."
	sudo dnf install -y gcc-c++ cmake pkgconfig qt6-qtbase-devel qt6-qtwebsockets-devel
elif command -v yum &>/dev/null; then
	echo "Detected yum package manager. Installing dependencies..."
	sudo yum install -y epel-release
	sudo yum install -y gcc-c++ cmake pkgconfig qt6-qtbase-devel qt6-qtwebsockets-devel
elif command -v pacman &>/dev/null; then
	echo "Detected pacman package manager. Installing dependencies..."
	sudo pacman -S --noconfirm base-devel cmake pkgconf qt6-base qt6-websockets
elif command -v zypper &>/dev/null; then
	echo "Detected zypper package manager. Installing dependencies..."
	sudo zypper install -y gcc-c++ cmake pkg-config qt6-base-devel qt6-websockets-devel
else
	echo "Unsupported package manager."
	echo "Please install the following dependencies manually:"
	echo "- C++ compiler (gcc/clang)"
	echo "- CMake (version 3.16 or higher)"
	echo "- Qt6 Core development libraries"
	echo "- Qt6 WebSockets development libraries"
	exit 1
fi

echo "Dependencies installed successfully!"
exit 0
