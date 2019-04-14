set_global_assignment -entity "video_clock_for_DE" -library "lib_video_clock_for_DE" -name IP_TOOL_NAME "Qsys"
set_global_assignment -entity "video_clock_for_DE" -library "lib_video_clock_for_DE" -name IP_TOOL_VERSION "17.1"
set_global_assignment -entity "video_clock_for_DE" -library "lib_video_clock_for_DE" -name IP_TOOL_ENV "Qsys"
set_global_assignment -library "lib_video_clock_for_DE" -name SPD_FILE [file join $::quartus(sip_path) "../video_clock_for_DE.spd"]
set_global_assignment -library "lib_video_clock_for_DE" -name MISC_FILE [file join $::quartus(sip_path) "../../video_clock_for_DE.qsys"]

set_global_assignment -library "lib_video_clock_for_DE" -name MISC_FILE [file join $::quartus(sip_path) "video_clock_for_DE.vhd"]
set_global_assignment -library "lib_video_clock_for_DE" -name MISC_FILE [file join $::quartus(sip_path) "submodules/video_clock_for_DE_video_pll_0.vhd"]
set_global_assignment -library "lib_video_clock_for_DE" -name MISC_FILE [file join $::quartus(sip_path) "submodules/altera_up_avalon_reset_from_locked_signal.v"]
set_global_assignment -library "lib_video_clock_for_DE" -name MISC_FILE [file join $::quartus(sip_path) "submodules/video_clock_for_DE_video_pll_0_video_pll.vo"]
