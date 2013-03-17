IF(NOT EM_MCU)
	MESSAGE(FATAL_ERROR "Select your EnergyMicro chip using EM_MCU variable.")
ENDIF()

SET(${EMLIB_PREFIX} "")

STRING(TOLOWER "${EM_MCU}" EM_MCU_L)
STRING(TOUPPER "${EM_MCU}" EM_MCU_U)
#STRING(TOUPPER "${STM32_CHIP_TYPE}" STM32_CHIP_TYPE)

STRING(REGEX REPLACE "^([A-Z]+[0-9]+[A-Z]+)[0-9]+[A-Z]+[0-9]+$" "\\1" MCU_FAMILY ${EM_MCU_U})
IF(MCU_FAMILY STREQUAL ${EM_MCU_U})
	MESSAGE(FATAL_ERROR "Not Valid MCU: " ${MCU_FAMILY})
ENDIF()
STRING(TOLOWER "${MCU_FAMILY}" MCU_FAMILY_L)
STRING(TOUPPER "${MCU_FAMILY}" MCU_FAMILY_U)

SET(EMLIB_LIB_NAME ${EMLIB_PREFIX}${EM_MCU_L})
SET(EMLIB_SYSTEM_NAME system_${MCU_FAMILY_L}.c)
SET(EMLIB_STARTUP_NAME startup_${MCU_FAMILY_L}.s)


#MESSAGE(FATAL_ERROR "Stop")

IF(MCU_FAMILY_U STREQUAL "EFM32ZG")
	SET(TARGET_CORE "m0plus")
ELSEIF(MCU_FAMILY_U STREQUAL "EFM32WG")
	SET(TARGET_CORE "m4")
ELSE()
	SET(TARGET_CORE "m3")
ENDIF()

FIND_PATH(EMLIB_INCLUDE_DIR
	NAMES em_version.h core_c${TARGET_CORE}.h
	PATH_SUFFIXES include emlib
)
FIND_PATH(EMLIB_FAMILY_INCLUDE_DIR
	NAMES ${EM_MCU_L}.h system_${MCU_FAMILY_L}.h
	PATH_SUFFIXES include emlib/${MCU_FAMILY_U}
)

FIND_LIBRARY(EMLIB_LIBRARIES
	NAMES ${EMLIB_LIB_NAME}
	PATH_SUFFIXES lib
)

FIND_FILE(EMLIB_SYSTEM_SOURCE
	${EMLIB_SYSTEM_NAME}
	PATHS ${CMAKE_FIND_ROOT_PATH}/share/emlib/
)
FIND_FILE(EMLIB_STARTUP_SOURCE
	${EMLIB_STARTUP_NAME}
	PATHS ${CMAKE_FIND_ROOT_PATH}/share/emlib/
)
FIND_FILE(EMLIB_LINKER_SCRIPT
	efm32.ld.in
	PATHS ${CMAKE_FIND_ROOT_PATH}/share/emlib/
)
FIND_FILE(EMLIB_MCU_HEADER
	${EM_MCU_L}.h
	PATH_SUFFIXES include emlib/${MCU_FAMILY_U}
)

INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(EmLib DEFAULT_MSG EMLIB_LIBRARIES EMLIB_INCLUDE_DIR EMLIB_FAMILY_INCLUDE_DIR EMLIB_SYSTEM_SOURCE EMLIB_STARTUP_SOURCE EMLIB_LINKER_SCRIPT)

SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mcpu=cortex-${TARGET_CORE} -D${EM_MCU_U}")
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mcpu=cortex-${TARGET_CORE} -D${EM_MCU_U}")
SET(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -mcpu=cortex-${TARGET_CORE}")
SET(CMAKE_EXE_LINKER_FLAGS "-T${CMAKE_CURRENT_BINARY_DIR}/${EM_MCU_L}.ld ${CMAKE_EXE_LINKER_FLAGS} -Wl,--start-group -lgcc -lc -lcs3 -lcs3unhosted -Wl,--end-group")

#Copied from FindOpenSSL.cmake
function(from_hex HEX DEC)
  string(TOUPPER "${HEX}" HEX)
  set(_res 0)
  string(LENGTH "${HEX}" _strlen)

  while (_strlen GREATER 0)
    math(EXPR _res "${_res} * 16")
    string(SUBSTRING "${HEX}" 0 1 NIBBLE)
    string(SUBSTRING "${HEX}" 1 -1 HEX)
    if (NIBBLE STREQUAL "A")
      math(EXPR _res "${_res} + 10")
    elseif (NIBBLE STREQUAL "B")
      math(EXPR _res "${_res} + 11")
    elseif (NIBBLE STREQUAL "C")
      math(EXPR _res "${_res} + 12")
    elseif (NIBBLE STREQUAL "D")
      math(EXPR _res "${_res} + 13")
    elseif (NIBBLE STREQUAL "E")
      math(EXPR _res "${_res} + 14")
    elseif (NIBBLE STREQUAL "F")
      math(EXPR _res "${_res} + 15")
    else()
      math(EXPR _res "${_res} + ${NIBBLE}")
    endif()

    string(LENGTH "${HEX}" _strlen)
  endwhile()

  set(${DEC} ${_res} PARENT_SCOPE)
endfunction(from_hex)

FUNCTION(EMLIB_CONFIGURE_LINKER_SCRIPT)
	FILE(STRINGS ${EMLIB_MCU_HEADER} EMLIB_MCU_HEADER_CONTENT)
	FOREACH(TMP_STR ${EMLIB_MCU_HEADER_CONTENT})
		STRING(REGEX MATCH "FLASH_BASE[ ]+\\(.+\\)" MCU_FLASH_BASE ${TMP_STR})
		IF(MCU_FLASH_BASE)
			STRING(REGEX REPLACE "^.*(0x.+)UL.*$" "\\1" MCU_FLASH_BASE_VAL ${MCU_FLASH_BASE})
		ENDIF()
		STRING(REGEX MATCH "FLASH_SIZE[ ]+\\(.+\\)" MCU_FLASH_SIZE ${TMP_STR})
		IF(MCU_FLASH_SIZE)
			STRING(REGEX REPLACE "^.*0x(.+)UL.*$" "\\1" MCU_FLASH_SIZE ${MCU_FLASH_SIZE})
			from_hex(${MCU_FLASH_SIZE} MCU_FLASH_SIZE_VAL)
		ENDIF()
		STRING(REGEX MATCH "SRAM_BASE[ ]+\\(.+\\)" MCU_SRAM_BASE ${TMP_STR})
		IF(MCU_SRAM_BASE)
			STRING(REGEX REPLACE "^.*(0x.+)UL.*$" "\\1" MCU_SRAM_BASE_VAL ${MCU_SRAM_BASE})
		ENDIF()
		STRING(REGEX MATCH "SRAM_SIZE[ ]+\\(.+\\)" MCU_SRAM_SIZE ${TMP_STR})
		IF(MCU_SRAM_SIZE)
			STRING(REGEX REPLACE "^.*0x(.+)UL.*$" "\\1" MCU_SRAM_SIZE ${MCU_SRAM_SIZE})
			from_hex(${MCU_SRAM_SIZE} MCU_SRAM_SIZE_VAL)
		ENDIF()
	ENDFOREACH(TMP_STR)
	IF((NOT MCU_FLASH_BASE_VAL) OR (NOT MCU_FLASH_SIZE_VAL) OR (NOT MCU_SRAM_BASE_VAL) OR (NOT MCU_SRAM_SIZE_VAL))
		MESSAGE(FATAL_ERROR "Can't parse part description header for ${EM_MCU_L}")
	ENDIF()

	SET(FLASH_SIZE ${MCU_FLASH_SIZE_VAL})
	SET(RAM_SIZE ${MCU_SRAM_SIZE_VAL})
	SET(FLASH_ORIGIN ${MCU_FLASH_BASE_VAL})
	SET(RAM_ORIGIN ${MCU_SRAM_BASE_VAL})
	CONFIGURE_FILE(${EMLIB_LINKER_SCRIPT} ${CMAKE_CURRENT_BINARY_DIR}/${EM_MCU_L}.ld)
ENDFUNCTION(EMLIB_CONFIGURE_LINKER_SCRIPT)
