#!/usr/bin/env bash

# Script for formatting C++ code using clang-format

echo "Formatting C++ code using clang-format..."

# Format files in ws-udp-proxy
if [ -d "ws-udp-proxy" ]; then
	echo "Formatting files in ws-udp-proxy..."
	(
		cd ws-udp-proxy || exit
		# Use -exec to handle filenames safely
		find . -type f \( -name "*.cpp" -o -name "*.h" -o -name "*.c" \) -exec clang-format -i {} +
	)
fi

echo "Formatting completed!"
