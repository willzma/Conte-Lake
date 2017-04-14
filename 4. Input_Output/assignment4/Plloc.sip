set_global_assignment -entity "Plloc" -library "lib_Plloc" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "Plloc" -library "lib_Plloc" -name IP_TOOL_VERSION "14.0"
set_global_assignment -entity "Plloc" -library "lib_Plloc" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_Plloc" -name SPD_FILE [file join $::quartus(sip_path) "Plloc.spd"]

set_global_assignment -library "lib_Plloc" -name MISC_FILE [file join $::quartus(sip_path) "Plloc_sim/Plloc.vo"]
