// lua.hpp
// Lua header files for C++
// <<extern "C">> not supplied automatically because Lua also compiles as C++

extern "C" {
#include "luaa.h"
#include "lualib.h"
#include "lauxlib.h"
}
