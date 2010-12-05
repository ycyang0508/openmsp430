#!/usr/bin/tclsh
#------------------------------------------------------------------------------
# Copyright (C) 2001 Authors
#
# This source file may be used and distributed without restriction provided
# that this copyright statement is not removed from the file and that any
# derivative work contains the original copyright notice and the associated
# disclaimer.
#
# This source file is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation; either version 2.1 of the License, or
# (at your option) any later version.
#
# This source is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public
# License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this source; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#
#------------------------------------------------------------------------------
# 
# File Name: run_analysis.tcl
# 
# Author(s):
#             - Olivier Girard,    olgirard@gmail.com
#
#------------------------------------------------------------------------------
# $Rev: 17 $
# $LastChangedBy: olivier.girard $
# $LastChangedDate: 2009-08-04 23:15:39 +0200 (Tue, 04 Aug 2009) $
#------------------------------------------------------------------------------
package require Tclx

###############################################################################
#                         SET SOME GLOBAL VARIABLES                           #
###############################################################################

# Set tools
set SYNPLICITY      "C:\\\\Actel\\\\Libero_v8.5\\\\Synplify\\\\synplify_96A\\\\bin\\\\synplify.exe"
set LIBERO_DESIGNER "C:\\\\Actel\\\\Libero_v8.5\\\\Designer\\\\bin\\\\designer.exe"

# Set the FPGA:  architecture,    model,   package_syn  package_libero, speed-grade
set fpgaConfig {  ProASIC3L     A3P1000L     FBGA484     "484 FBGA"        Std}

# RTL Top Level module
set designTop "openMSP430_fpga"


###############################################################################
#                                 CLEANUP                                     #
###############################################################################
proc sleep {time} {
      after [expr $time*1000] set end 1
      vwait end
  }

		
# Cleanup
file delete -force ./WORK
file mkdir ./WORK
cd ./WORK


###############################################################################
#                              PERFORM SYNTHESIS                              #
###############################################################################

# Copy Synplify tcl command files
if [catch {open "../synplify.tcl" r} f_synplify_tcl] {
    puts "ERROR: Cannot open Synplify command file file ../synplify.tcl"
    exit 1
}

set synplify_tcl [read $f_synplify_tcl]
close $f_synplify_tcl

regsub -all {<DEVICE_FAMILY>}  $synplify_tcl "[string toupper [lindex $fpgaConfig 0]]" synplify_tcl
regsub -all {<DEVICE_NAME>}    $synplify_tcl "[string toupper [lindex $fpgaConfig 1]]" synplify_tcl
regsub -all {<DEVICE_PACKAGE>} $synplify_tcl "[string toupper [lindex $fpgaConfig 2]]" synplify_tcl
regsub -all {<SPEED_GRADE>}    $synplify_tcl "[string toupper [lindex $fpgaConfig 4]]" synplify_tcl
regsub -all {<TOP_LEVEL>}      $synplify_tcl $designTop                                synplify_tcl

set f_synplify_tcl [open "synplify.tcl" w]
puts $f_synplify_tcl $synplify_tcl
close $f_synplify_tcl

# Start synthesis
puts "START SYNTHESIS..."
flush stdout
set synplify_done 0
while {[string eq $synplify_done 0]} {

    sleep 10
    eval exec $SYNPLICITY synplify.tcl
    sleep 30

    # Wait until EDIF file is generated
    set synplify_timeout 0
    while {!([file exists "./rev_1/design_files.edn"] | ($synplify_timeout==100))} {
	set synplify_timeout [expr $synplify_timeout+1]
    }
    if ($synplify_timeout<100) {
	set synplify_done 1
    }

    # Kill the Synplify task with taskkill since it can't be properly closed with the synplify.tcl script
    sleep 10
    eval exec taskkill /IM synplify.exe
    sleep 20
    if {[string eq $synplify_done 0]} {
	sleep 180
    }
}
puts "SYNTHESIS DONE..."
flush stdout


###############################################################################
#                           PERFORM PLACE & ROUTE                             #
###############################################################################

# Copy Libero Designer tcl command files
if [catch {open "../libero_designer.tcl" r} f_libero_designer_tcl] {
    puts "ERROR: Cannot open Libero Designer command file file ../libero_designer.tcl"
    exit 1
}
set libero_designer_tcl [read $f_libero_designer_tcl]
close $f_libero_designer_tcl

regsub -all {<DEVICE_FAMILY>}  $libero_designer_tcl "[lindex $fpgaConfig 0]" libero_designer_tcl
regsub -all {<DEVICE_NAME>}    $libero_designer_tcl "[lindex $fpgaConfig 1]" libero_designer_tcl
regsub -all {<DEVICE_PACKAGE>} $libero_designer_tcl "[lindex $fpgaConfig 3]" libero_designer_tcl
regsub -all {<SPEED_GRADE>}    $libero_designer_tcl "[lindex $fpgaConfig 4]" libero_designer_tcl

set f_libero_designer_tcl [open "libero_designer.tcl" w]
puts $f_libero_designer_tcl $libero_designer_tcl
close $f_libero_designer_tcl
				

# Run place & route
puts "START PLACE & ROUTE..."
flush stdout
eval exec $LIBERO_DESIGNER script:libero_designer.tcl logfile:libero_designer.log
puts "PLACE & ROUTE DONE..."
flush stdout


###############################################################################
#                             REPORT SUMMARY                                  #
###############################################################################
	
# Extract timing information
if [catch {open "report_timing_max.txt" r} f_timing] {
    puts "ERROR: Cannot open timing file"
    exit 1
}
set timingFile [read $f_timing]
close $f_timing
regexp {SUMMARY(.*)END SUMMARY} $timingFile whole_match timing
puts $timing
puts "===================================================================================="

# Extract size information
if [catch {open "report_status.txt" r} f_area] {
    puts "ERROR: Cannot open status file: report_status.txt"
    exit 1
}
set areaFile [read $f_area]
close $f_area
regexp {(Compile report:.*?)Total:} $areaFile whole_match area1
regexp {(Core Information:.*?)I/O Function:} $areaFile whole_match area2
puts $area1
puts $area2
puts $f_logFile "===================================================================================="

cd ../
sleep 3

exit 0
