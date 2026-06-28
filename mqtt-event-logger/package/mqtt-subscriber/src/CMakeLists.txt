# CMakeLists.txt
#
# CMake file for mqtt subscriber.
# Includes Paho C and C++ libraries as submodules.

cmake_minimum_required(VERSION 3.13)
project(MqttSubscriber VERSION 1.0.0 LANGUAGES C CXX)

# Set the output directories for compiled libraries and binaries
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)


# ==============================================================================
# 1. Configure and Build Paho MQTT C Submodule
# ==============================================================================
# Configuration options to only build shared libraries and avoid tests/samples
set(PAHO_BUILD_SHARED        ON  CACHE BOOL "Build shared library"   FORCE)
set(PAHO_BUILD_STATIC        OFF CACHE BOOL "Build static library"   FORCE)
set(PAHO_BUILD_SAMPLES       OFF CACHE BOOL "Build samples"          FORCE)
set(PAHO_ENABLE_TESTING      OFF CACHE BOOL "Enable tests"           FORCE)
set(PAHO_ENABLE_CPACK        OFF CACHE BOOL "Enable CPack"           FORCE)

# Force SSL to ON because we might need the '3as' (async + SSL) variant
set(PAHO_WITH_SSL            ON  CACHE BOOL "Enable SSL/TLS support" FORCE)

# Add folder path to paho.mqtt.c submodule directory
add_subdirectory(paho.mqtt.c)

# Create namespace aliases that paho.mqtt.cpp searches for internally
add_library(eclipse-paho-mqtt-c::paho-mqtt3a  ALIAS paho-mqtt3a)
add_library(eclipse-paho-mqtt-c::paho-mqtt3c  ALIAS paho-mqtt3c)
add_library(eclipse-paho-mqtt-c::paho-mqtt3as ALIAS paho-mqtt3as)
add_library(eclipse-paho-mqtt-c::paho-mqtt3cs ALIAS paho-mqtt3cs)


# ==============================================================================
# 2. Trick the find_package() Call in Paho MQTT C++
# ==============================================================================
# We generate a minimal package configuration layout inside the build tree.
# This prevents the subdirectories from throwing errors when searching for an installed layout.
set(FAKE_CONFIG_DIR "${CMAKE_BINARY_DIR}/fake-paho-c-config")
file(MAKE_DIRECTORY "${FAKE_CONFIG_DIR}")

file(WRITE "${FAKE_CONFIG_DIR}/eclipse-paho-mqtt-cConfig.cmake" "
    set(eclipse-paho-mqtt-c_FOUND   TRUE)
    set(eclipse-paho-mqtt-c_VERSION \"1.3.16\")
    set(PAHO_MQTT_C_INCLUDE_DIRS    \"${CMAKE_CURRENT_SOURCE_DIR}/paho.mqtt.c/src\")
    # Falls das C++-Skript alte Variablen nutzt, stellen wir diese bereit:
    set(PAHO_MQTT_C_LIBRARIES       paho-mqtt3a paho-mqtt3c paho-mqtt3as paho-mqtt3cs) 
")

file(WRITE "${FAKE_CONFIG_DIR}/eclipse-paho-mqtt-cConfigVersion.cmake" "
    set(PACKAGE_VERSION             \"1.3.16\")
    set(PACKAGE_VERSION_COMPATIBLE  TRUE)
    set(PACKAGE_VERSION_EXACT       TRUE)
")

# Append our mock configuration directory to CMake search paths
list(APPEND CMAKE_PREFIX_PATH "${FAKE_CONFIG_DIR}")


# ==============================================================================
# 3. Inject Target into the Export Set
# ==============================================================================
# Modern Paho C++ includes an installer script that demands the underlying C 
# dependency be part of its designated export target group ("PahoMqttCpp").
# We register our local C target here so that CMake's validation succeeds.
install(TARGETS paho-mqtt3a paho-mqtt3c paho-mqtt3as paho-mqtt3cs EXPORT PahoMqttCpp)


# ==============================================================================
# 4. Configure and Build Paho MQTT C++ Submodule
# ==============================================================================
# Configuration options to only build shared libraries and avoid tests/samples
set(PAHO_BUILD_SHARED        ON  CACHE BOOL "Build shared library"   FORCE)
set(PAHO_BUILD_STATIC        OFF CACHE BOOL "Build static library"   FORCE)
set(PAHO_BUILD_SAMPLES       OFF CACHE BOOL "Build samples"          FORCE)
set(PAHO_BUILD_DOCUMENTATION OFF CACHE BOOL "Build documentation"    FORCE)

# Tell the C++ library NOT to look inside its own empty "externals" directory
set(PAHO_WITH_MQTT_C         OFF CACHE BOOL "Build internal Paho C"  FORCE)

# Add folder path to paho.mqtt.c submodule directory
add_subdirectory(paho.mqtt.cpp)


# ==============================================================================
# 5. MQTT Subscriber Application Target
# ==============================================================================
# Define mqtt subscriber as binary application target
add_executable(mqtt_subscriber mqtt_subscriber.cpp)

# Require C++17 standard as mandated by paho.mqtt.cpp
target_compile_features(mqtt_subscriber PRIVATE cxx_std_17)

# Manually supply the include paths to the raw source submodules.
# This grants the executable access to the mqtt library headers.
target_include_directories(mqtt_subscriber PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/paho.mqtt.c/src
    ${CMAKE_CURRENT_SOURCE_DIR}/paho.mqtt.cpp/include
)

# Link mqtt subscriber directly against the Paho C++ target
# The C++ target automatically brings along the required C dependency
target_link_libraries(mqtt_subscriber PRIVATE paho-mqttpp3-shared)