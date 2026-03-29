cmake_minimum_required (VERSION 3.20)

# Suppress CMP0175: external Papyrus.cmake uses VERBATIM with APPEND in
# add_custom_command, which is not supported. Setting OLD silences the
# warning without modifying the upstream module.
#
# Reference: https://cmake.org/cmake/help/latest/policy/CMP0175.html
cmake_policy(SET CMP0175 OLD)

project(
    OCreatures
    VERSION 1.4
    LANGUAGES NONE
)

# ---------------------------------------------------------------------------
# Options & Core Paths
# ---------------------------------------------------------------------------

# SkyrimSE_PATH: absolute path to the game directory. 
# Defaults to the standard Steam library location if not provided.
if(NOT DEFINED SkyrimSE_PATH OR SkyrimSE_PATH STREQUAL "")
    set(SkyrimSE_PATH "E:/Steam/steamapps/common/Skyrim Special Edition"
        CACHE PATH "Path to Skyrim Special Edition installation")
endif()

# ---------------------------------------------------------------------------
# Module Paths
# ---------------------------------------------------------------------------

list(APPEND CMAKE_MODULE_PATH
    #"${CMAKE_CURRENT_SOURCE_DIR}/cmake"
    "${CMAKE_CURRENT_SOURCE_DIR}/external/BethesdaCMakeModules/Modules"
)

include(Papyrus)

# ---------------------------------------------------------------------------
# Papyrus Scripts
# ---------------------------------------------------------------------------

file(GLOB Papyrus_SOURCES
    CONFIGURE_DEPENDS
    "src/scripts/source/*.psc"
)

Papyrus_Add(
    "Papyrus"
    GAME ${SkyrimSE_PATH}
    IMPORTS 
        "${CMAKE_CURRENT_SOURCE_DIR}/scripts"
        "${SkyrimSE_PATH}/Data/Scripts/Source"
        "${SkyrimSE_PATH}/Data/Source/Scripts"
    SOURCES ${Papyrus_SOURCES}
    OPTIMIZE ANONYMIZE
)