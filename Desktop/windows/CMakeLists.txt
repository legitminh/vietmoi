add_library(SieuvietTSF SHARED TextService.cpp exports.def)
target_link_libraries(SieuvietTSF PRIVATE sieuviet-desktop ole32 oleaut32 uuid user32 gdi32 advapi32 shell32)
set_target_properties(SieuvietTSF PROPERTIES PREFIX "")
add_executable(SieuvietSettings WIN32 Settings.cpp)
target_link_libraries(SieuvietSettings PRIVATE sieuviet-desktop ole32 uuid user32 gdi32 shell32)
if(MINGW)
  target_link_options(SieuvietSettings PRIVATE -municode)
  # LLVM-MinGW statically links libc++ so the adapter needs only OS DLLs plus
  # the explicitly loaded, packaged Swift engine/runtime.
  target_link_options(SieuvietTSF PRIVATE -static)
  target_link_options(SieuvietSettings PRIVATE -static)
endif()
install(TARGETS SieuvietTSF SieuvietSettings RUNTIME DESTINATION . LIBRARY DESTINATION .)
install(FILES install.ps1 install-copy.json DESTINATION .)
