#include "yuvi_vst_host_api.h"

#include <cstdlib>
#include <cstring>

// Phase 1 stub. No JUCE plugin-hosting logic is wired up yet — every
// function here is honest about doing nothing rather than fabricating
// plugin data. See README.md for prerequisites and the phased plan.

extern "C" {

char* yvh_scan_plugins(const char* /*directory*/) {
    const char* empty = "[]";
    char* out = static_cast<char*>(std::malloc(std::strlen(empty) + 1));
    std::strcpy(out, empty);
    return out;
}

YvhPluginHandle yvh_load_plugin(const char* /*path*/) {
    return nullptr;
}

void yvh_unload_plugin(YvhPluginHandle /*handle*/) {}

void yvh_set_gain(YvhPluginHandle /*handle*/, double /*normalized*/) {}

double yvh_get_level(YvhPluginHandle /*handle*/) {
    return -100.0;
}

void yvh_open_editor(YvhPluginHandle /*handle*/) {}

void yvh_close_editor(YvhPluginHandle /*handle*/) {}

void yvh_map_midi_cc(YvhPluginHandle /*handle*/, int /*cc_number*/, int32_t /*parameter_index*/) {}

void yvh_free_string(char* str) {
    std::free(str);
}

} // extern "C"
