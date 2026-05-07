// H5Log.hh
// Lightweight, dependency-free logger for HDF5Utils.
// Usable from rootcling without any external library linkage.
//
// Macros:
//   H5ERROR(fmt, ...)  — prints to stderr with [ClassName::Method] prefix
//   H5WARN(fmt, ...)   — prints to stderr with [ClassName::Method] prefix
//   H5INFO(fmt, ...)   — prints to stdout with [ClassName::Method] prefix
//
// The class and method names are extracted automatically from
// __PRETTY_FUNCTION__ at compile time (zero runtime overhead for the
// string parsing; the result is used only when the macro fires).

#pragma once

#include <cstdio>
#include <cstring>
#include <string>

namespace h5log_detail {

// Extract "ClassName::MethodName" from __PRETTY_FUNCTION__.
// Example input:  "bool H5DataReader::Open()"
// Example output: "H5DataReader::Open"
inline std::string extract_location(const char * pretty)
{
  if (!pretty) return "";

  // Find the opening parenthesis — that marks the end of the signature.
  const char * paren = std::strchr(pretty, '(');
  if (!paren) return pretty;

  // Walk back to find the start of "ClassName::Method".
  // Skip any leading return-type tokens (separated by spaces).
  const char * end = paren;  // exclusive end

  // Find the last space before '(' to skip the return type.
  const char * start = end;
  while (start > pretty && *(start - 1) != ' ') { --start; }

  // Strip any leading '*' (pointer return types).
  while (start < end && *start == '*') { ++start; }

  return std::string(start, end);
}

}  // namespace h5log_detail

// ── Public macros ──────────────────────────────────────────────────────────

#define H5ERROR(fmt, ...)                                                       \
  do {                                                                          \
    std::string _h5loc = h5log_detail::extract_location(__PRETTY_FUNCTION__);  \
    fprintf(stderr, "[%s] " fmt "\n", _h5loc.c_str(), ##__VA_ARGS__);          \
  } while (0)

#define H5WARN(fmt, ...)                                                        \
  do {                                                                          \
    std::string _h5loc = h5log_detail::extract_location(__PRETTY_FUNCTION__);  \
    fprintf(stderr, "[%s] " fmt "\n", _h5loc.c_str(), ##__VA_ARGS__);          \
  } while (0)

#define H5INFO(fmt, ...)                                                        \
  do {                                                                          \
    std::string _h5loc = h5log_detail::extract_location(__PRETTY_FUNCTION__);  \
    fprintf(stdout, "[%s] " fmt "\n", _h5loc.c_str(), ##__VA_ARGS__);          \
  } while (0)
