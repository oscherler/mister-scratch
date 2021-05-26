# MiSTer Scratch

Learning MiSTer FPGA core development by building a core from scratch using jotego’s `jtframe` framework.

## Setting Up

**Note:** This document currently assumes that you have a Linux machine or VM with Quartus 17.1 and `jtframe` dependencies installed. Sorry for taking that shortcut, but that’s a job for a whole other document.

The first step is to add [`jtframe`][jtframe] as a submodule. I chose commit `2793a532971`, as it was the version used by the [Bubble Bobble][jtbubl] core when I started with `jtframe`:

```
git submodule add https://github.com/jotego/jtframe modules/jtframe
cd modules/jtframe
git checkout 2793a532971
cd ../..
```

We also copy [`setprj.sh`][setprj] from the Bubble Bobble core, and add a `Makefile` for shortcuts:

```
compile:
	jtcore -mr scratch
	@rmdir mist sidi

copy:
	scp mister/output_1/jtscratch.rbf root@192.168.1.118:/media/fat/

clean:
	rm -rf log/ mist/ mister/ sidi/

.PHONY: compile copy clean
```

Replace `192.168.1.118` with the IP address of your DE10-Nano.

[jtframe]: https://github.com/jotego/jtframe
[jtbubl]: https://github.com/jotego/jtbubl
[setprj]: https://github.com/jotego/jtbubl/blob/420e631825f0bcd64ad48f8357c50185aa756f9c/setprj.sh

## Minimal Core

For a minimal core that does nothing, we only need three files, that we put in the `hdl` folder:

* `jtscratch.qip`: the list of HDL files to compile;
* `jtscratch.def`: defining macros to configure the core;
* `scratch_game.v`: the Verilog file that contains the top-level entity of our core, that will be instantiated by `jtframe`.

`hdl/jtscratch.qip`:

```
# scratch
set_global_assignment -name VERILOG_FILE [file join $::quartus(qip_path) scratch_game.v ]
```

`hdl/jtscratch.def`:

```
[all]
CORENAME="SCRATCH"
GAMETOP=scratch_game
BUTTONS=3
COLORW=4
VIDEO_WIDTH=256
VIDEO_HEIGHT=224

[mister]
JTFRAME_OSD_NOLOAD
JTFRAME_ARX=5
JTFRAME_ARY=4
```

`hdl/scratch_game.v`:

Note that the `red`, `green`, and `blue` ports are on 4 bits, matching the `COLORW` macro in `jtscratch.def`.

```
//================================================================================
//  SCRATCH GAME
//
//  Scratch top-level module
//================================================================================

`default_nettype none

module scratch_game(
	input           rst,
	input           clk,          // 48 MHz
	output          pxl2_cen,     // 12   MHz
	output          pxl_cen,      //  6   MHz
	output   [3:0]  red,          // 
	output   [3:0]  green,        // 
	output   [3:0]  blue,         // 
	output          LHBL_dly,     // Horizontal Blank, possibly delayed
	output          LVBL_dly,     // Vertical Blank, possibly delayed
	output          HS,           // Horizontal video sync output
	output          VS,           // Vertical video sync output
	// cabinet I/O
	input   [ 1:0]  start_button,
	input   [ 1:0]  coin_input,
	input   [ 6:0]  joystick1,
	input   [ 6:0]  joystick2,
	// SDRAM interface
	input           downloading,
	output          dwnld_busy,
	input           loop_rst,
	output          sdram_req,
	output  [21:0]  sdram_addr,
	input   [31:0]  data_read,
	input           data_rdy,
	input           sdram_ack,
	output          refresh_en,
	// ROM LOAD
	input   [24:0]  ioctl_addr,
	input   [ 7:0]  ioctl_data,
	input           ioctl_wr,
	output  [21:0]  prog_addr,
	output  [ 7:0]  prog_data,
	output  [ 1:0]  prog_mask,
	output          prog_we,
	output          prog_rd,
	// DIP switches
	input   [31:0]  status,
	input   [31:0]  dipsw,
	input           dip_pause,
	inout           dip_flip,
	input           dip_test,
	input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
	// Sound output
	output  signed [15:0] snd,
	output          sample,
	output          game_led,
	input           enable_psg,
	input           enable_fm,
	// Debug
	input   [ 3:0]  gfx_en
);

endmodule
```

The important parts here are:

* We add the `scratch_game.v` Verilog file to `jtscratch.qip` so that it gets compiled;
* The name (`scratch_game`) of the module we define in `scratch_game.v` is configured as `GAMETOP` in `jtscratch.def`;
* The input and output ports of the `scratch_game` module match its instantiation by `jtframe` in `modules/jtframe/hdl/mister/jtframe_emu.sv`:

	```
	`GAMETOP u_game
	(
		.rst          ( game_rst         ),
		// clock inputs
		// By default clk is 48MHz, but JTFRAME_CLK96 overrides it to 96MHz
		.clk          ( clk_rom          ),
	...
	```

We can now build our core-that-does-nothing. Make sure you have sourced `setprj.sh` for the shell session, and type `make`:

```
source setprj.sh
make
```

On my machine, it takes seven minutes, complains that “some SDRAM signals are not IO registers,” and prints a large “FAIL scratch” in ASCII art, but the resulting RBF file still runs, as we don’t use the SDRAM.

The RBF is located at `mister/output_1/jtscratch.rbf`, and you can install it on your MiSTer by sending to `/media/fat` it via SSH using `make copy`, or by copying it via SMB at the root of the `fat` share.
