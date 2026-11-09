// cxx23-compat.hpp — build the dext as C++23 on toolchains whose DriverKit SDK
// cannot compile C++26 (Xcode 26.x: safe_allocation.h redeclares placement
// operator new without the constexpr C++26's <new> gives it).
//
// Force-included by `build-signed.sh --cxx23` via
//   -std=gnu++23 -include tools/cxx23-compat.hpp -Wno-c++26-extensions
// It is NOT part of the normal (C++26, Xcode 27) build and the sources never
// include it directly. Everything here fills a C++26 library gap the driver
// relies on; language-level extensions (`= delete("reason")`) are accepted by
// clang in C++23 mode with a warning, which the flag above silences.
#pragma once

// <new> must come before any DriverKit header in every TU: once libc++ has
// been entered (this header does that), the SDK's safe_allocation.h stops
// including <new> and only forward-declares placement operator new, and that
// bare redeclaration is only legal AFTER libc++'s own attributed declaration.
#include <new>
#include <version>

#if !defined(__cpp_lib_saturation_arithmetic)
#include <limits>
#include <type_traits>

namespace std {
// P0543 saturation arithmetic — only the overload the driver uses.
template <class T>
    requires std::is_integral_v<T>
[[nodiscard]] constexpr T add_sat(T x, T y) noexcept {
    T r;
    if (!__builtin_add_overflow(x, y, &r)) return r;
    if constexpr (std::is_signed_v<T>) {
        return y > 0 ? std::numeric_limits<T>::max() : std::numeric_limits<T>::min();
    } else {
        return std::numeric_limits<T>::max();
    }
}
}  // namespace std
#endif
