# - Try to find sackit
# Once done this will define
#
#  SACKIT_FOUND - system has sackit
#  sackit_INCLUDE_DIRS - the sackit include directory
#  sackit_LIBRARIES - the libraries needed to use sackit
#
# $SACKITDIR is an environment variable used for finding sackit.
#

FIND_PATH(sackit_INCLUDE_DIRS sackit.h
    PATHS
    $ENV{SACKITDIR}
    /usr/local
    /usr
    PATH_SUFFIXES include
    )

FIND_LIBRARY(sackit_LIBRARY
    NAMES sackit
    PATHS
    $ENV{SACKITDIR}
    /usr/local
    /usr
    PATH_SUFFIXES lib
    )

# handle the QUIETLY and REQUIRED arguments and set SACKIT_FOUND to TRUE if
# all listed variables are TRUE
INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(sackit DEFAULT_MSG sackit_LIBRARY sackit_INCLUDE_DIRS)

SET(sackit_LIBRARIES ${sackit_LIBRARY})

MARK_AS_ADVANCED(sackit_LIBRARY sackit_LIBRARIES sackit_INCLUDE_DIRS)
