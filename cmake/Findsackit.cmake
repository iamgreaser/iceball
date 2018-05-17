# - Try to find sackit
# Once done this will define
#
#  SACKIT_FOUND - system has sackit
#  sackit_INCLUDE_DIRS - the sackit include directory
#  sackit_LIBRARIES - the libraries needed to use sackit
#
# The build process used involve building and installing sackit in a seperate source tree;
# since sackit is now shipped with iceball and installed in-place, we no longer use system-wide paths.
# Enable them if you otherwise want to link against system-wide sackit.
# $SACKITDIR is an environment variable used for finding system-wide sackit.
#

# FIND_PATH(sackit_INCLUDE_DIRS sackit.h
#     PATHS
#     $ENV{SACKITDIR}
#     /usr/local
#     /usr
#     PATH_SUFFIXES include
#     )
#
# FIND_LIBRARY(sackit_LIBRARY
#     NAMES sackit
#     PATHS ${CMAKE_SOURCE_DIR}/xlibinc/
#     $ENV{SACKITDIR}
#     /usr/local
#     /usr
#     PATH_SUFFIXES lib
#     )
#

add_subdirectory(xlibinc/sackit)

FIND_PATH(sackit_INCLUDE_DIRS sackit.h PATHS ${CMAKE_CURRENT_SOURCE_DIR}/xlibinc/sackit/)
set(sackit_LIBRARY sackit)

# handle the QUIETLY and REQUIRED arguments and set SACKIT_FOUND to TRUE if
# all listed variables are TRUE
INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(sackit DEFAULT_MSG sackit_LIBRARY sackit_INCLUDE_DIRS)

SET(sackit_LIBRARIES ${sackit_LIBRARY})

MARK_AS_ADVANCED(sackit_LIBRARY sackit_LIBRARIES sackit_INCLUDE_DIRS)
