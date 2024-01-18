#pragma once

#ifdef __device__
#define FUNC_QUALIFIER __host__ __device__
#else
#define FUNC_QUALIFIER
#endif

#include <ranges>  // std::ranges::size
#include <utility> // std::forward

namespace tmp {
template <int Init, typename Pred, typename Step, typename F>
FUNC_QUALIFIER void static_for(F &&f) {
  if constexpr (Pred{}.template operator()<Init>()) {
    f.template operator()<Init>();
    static_for<Step{}.template operator()<Init>(), Pred, Step, F>(
        std::forward<F>(f));
  }
}

template <int J> struct constant {
  template <int> FUNC_QUALIFIER constexpr int operator()() { return J; }
};
template <int J> struct less_than {
  template <int I> FUNC_QUALIFIER constexpr bool operator()() { return I < J; }
};
template <int J> struct greater_than {
  template <int I> FUNC_QUALIFIER constexpr bool operator()() { return I > J; }
};
template <int J> struct less_than_eq {
  template <int I> FUNC_QUALIFIER constexpr bool operator()() { return I <= J; }
};
template <int J> struct greater_than_eq {
  template <int I> FUNC_QUALIFIER constexpr bool operator()() { return I >= J; }
};
template <int J> struct equal {
  template <int I> FUNC_QUALIFIER constexpr bool operator()() { return I == J; }
};
template <int J> struct not_equal {
  template <int I> FUNC_QUALIFIER constexpr bool operator()() { return I != J; }
};
template <int J = 1> struct increment {
  template <int I> FUNC_QUALIFIER constexpr int operator()() { return I + J; }
};
template <int J = 1> struct decrement {
  template <int I> FUNC_QUALIFIER constexpr int operator()() { return I - J; }
};
template <int J> struct divide {
  template <int I> FUNC_QUALIFIER constexpr int operator()() { return I / J; }
};
template <int J> struct multiply {
  template <int I> FUNC_QUALIFIER constexpr int operator()() { return I * J; }
};
// Based on https://stackoverflow.com/a/63436491/1476661 by @jan-schultke
template <int J> struct divide_ceil {
  template <int I> FUNC_QUALIFIER constexpr int operator()()
  {
    using Dividend = decltype(I);
    using Divisor = decltype(J);
    static constexpr auto x = I;
    static constexpr auto y = J;
    if constexpr (std::is_unsigned_v<Dividend> && std::is_unsigned_v<Divisor>) {
        // quotient is always positive
        return x / y + (x % y != 0);  // uint / uint
    }
    else if constexpr (std::is_signed_v<Dividend> && std::is_unsigned_v<Divisor>) {
        auto sy = static_cast<std::make_signed_t<Divisor>>(y);
        bool quotientPositive = x >= 0;
        return x / sy + (x % sy != 0 && quotientPositive);  // int / uint
    }
    else if constexpr (std::is_unsigned_v<Dividend> && std::is_signed_v<Divisor>) {
        auto sx = static_cast<std::make_signed_t<Dividend>>(x);
        bool quotientPositive = y >= 0;
        return sx / y + (sx % y != 0 && quotientPositive);  // uint / int
    }
    else {
        bool quotientPositive = (y >= 0) == (x >= 0);
        return x / y + (x % y != 0 && quotientPositive);  // int / int
    }
  }
};
template <typename Pred, typename TruePath, typename FalsePath> struct select {
  template <int I> FUNC_QUALIFIER constexpr int operator()() {
    if constexpr (Pred{}.template operator()<I>())
      return TruePath{}.template operator()<I>();
    else
      return FalsePath{}.template operator()<I>();
    }
};

template <auto InputRange, int Index, int N, typename F>
FUNC_QUALIFIER void static_range_for_impl(F &&f) {
  if constexpr (Index != N) {
    f.template operator()<InputRange[Index]>();
    static_range_for_impl<InputRange, Index + 1, N, F>(std::forward<F>(f));
  }
}

template <auto InputRange, int Index, int N, typename S, typename F>
FUNC_QUALIFIER void static_switch_impl(S &&s, F &&f) {
  if constexpr (Index != N) {
    if (s == InputRange[Index])
      f.template operator()<InputRange[Index]>();
    else
      static_switch_impl<InputRange, Index + 1, N, S, F>(
          std::forward<S>(s), std::forward<F>(f));
  }
}

template <auto SizedRange, typename F>
FUNC_QUALIFIER void static_range_for(F &&f) {
  static_range_for_impl<SizedRange, 0, std::ranges::size(SizedRange), F>(
      std::forward<F>(f));
}

template <auto SizedRange, typename S, typename F>
FUNC_QUALIFIER void static_switch(S &&s, F &&f) {
  static_switch_impl<SizedRange, 0, std::ranges::size(SizedRange), S, F>(
      std::forward<S>(s), std::forward<F>(f));
}
} // namespace tmp
