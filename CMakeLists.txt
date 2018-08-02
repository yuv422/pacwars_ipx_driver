cmake_minimum_required (VERSION 3.3)

SET(CMAKE_ASM_NASM_OBJECT_FORMAT bin)
set(CMAKE_ASM_NASM_LINK_EXECUTABLE "cp <OBJECTS> <TARGET>")
project(pac_drv ASM_NASM)
SET(CMAKE_ASM_NASM_FLAGS "-I ${CMAKE_CURRENT_SOURCE_DIR}/")


set(SOURCE_FILES
        pac_drv.asm
        ipx.asm
        netware.asm
)

add_custom_command(
        OUTPUT
        ${CMAKE_CURRENT_SOURCE_DIR}/.pac_drv.asm
        DEPENDS
        ${SOURCE_FILES}
        COMMAND
        cp ${CMAKE_CURRENT_SOURCE_DIR}/pac_drv.asm ${CMAKE_CURRENT_SOURCE_DIR}/.pac_drv.asm
)

add_custom_target(
        generate-temp-file
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/.pac_drv.asm
)
add_executable(pac_drv.com .pac_drv.asm)
add_dependencies(pac_drv.com generate-temp-file)
