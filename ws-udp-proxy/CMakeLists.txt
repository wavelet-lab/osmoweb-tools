cmake_minimum_required(VERSION 3.16)
project(ws-udp-proxy LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)

# find_package(Qt5 REQUIRED COMPONENTS Core WebSockets)

find_package(Qt6Core       CONFIG REQUIRED)
find_package(Qt6WebSockets CONFIG REQUIRED)

add_definitions(-g -O0)

add_executable(ws-udp-proxy
    ws_udp_proxy.cpp ws_udp_proxy.h
    main.cpp
)

set_target_properties(ws-udp-proxy PROPERTIES
    WIN32_EXECUTABLE FALSE
    MACOSX_BUNDLE FALSE
)

target_link_libraries(ws-udp-proxy
    Qt6::Core
    Qt6::WebSockets
)

