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

_Git tag: `minimal-core`_

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

## Video

_Git tag: `video-grid`_

Next we will add some video output. First we add a new file, `hdl/scratch_video.v`. This module will take `rst` and `clk`, the 48 MHz system clock, as inputs, and generate:

* The 6 MHz and 12 MHz pixel clock enables, `pxl_cen` and `pxl2_cen`;
* The horizontal and vertical blanking signals, `LHBL_dly` and `LVBL_dly`;
* The horizontal and vertical sync signaly, `HS` and `VS`;
* The RGB pixel values, `red`, `green`, and `blue`.

For the pixel clock enables, we use the `jtframe_cen48` module, that takes the 48 MHz system clock and generates a number of clock enable signals from it.

For the blanking and sync signals, we use the `jtframe_vtimer` (video timer) module. It takes a number of parameters to configure the desired video mode, based on the value of its horizontal and vertical counters. We are going to choose a resolution of 256x224 pixels, so we take the values we found in Bubble Bobble and adjust them a bit:

* the horizontal blanking signal starts after 255 pixels (`HB_START`);
* the horizontal sync signal starts 32 pixels later (front porch), at 287 (`HS_START`);
* by default, the horizontal sync signal lasts for 27 pixels;
* the horizontal blanking signal ends 69 pixels later (back porch), at 383 (`HB_END`);
* the vertical blanking signal starts after 223 lines (`VB_START`);
* the vertical sync signal starts 10 lines later (front porch), at 233 (`VS_START`);
* by default, the vertical sync signal lasts for 3 lines;
* the vertical blanking signal ends 30 lines later (back porch), at 263 (`VB_END`).

In addition to the blanking and sync signals, we also output the horizontal and vertical counters, `H` and `vdump`, to generate our grid.

```
jtframe_vtimer #(
	.HB_START( 9'd255 ),
	.HS_START( 9'd287 ),
	.HB_END  ( 9'd383 ),
	.VB_START( 9'd223 ),
	.VS_START( 9'd233 ),
	.VB_END  ( 9'd263 )
)
u_timer(
	.clk        ( clk           ),
	.pxl_cen    ( pxl_cen       ),
	.vdump      ( V             ),
	.vrender    (               ),
	.vrender1   (               ),
	.H          ( H             ),
	.Hinit      (               ),
	.Vinit      (               ),
	.LHBL       ( LHBL          ),
	.LVBL       ( LVBL          ),
	.HS         ( HS            ),
	.VS         ( VS            )
);
```

For the grid, we are going to test bit 4 of the horizontal and vertical counters, to draw 16x16 pixel squares:

```
reg  [3:0] r, g, b;

always @( posedge clk ) if( pxl_cen ) begin
	r <= 4'h0;
	g <= H[4] == 1'b0 ? 4'h0 : 4'hf;
	b <= V[4] == 1'b0 ? 4'h0 : 4'hf;
```

When bit 4 of the horizontal counter is 0, we output a green horizontal band. When bit 4 of the vertical counter is 0, we output a blue vertical band. When they intersect, we get a cyan square.

Finally, we pass the video signals to a `jtframe_blank` instance, that will set the pixels to black during horizontal and vertical blanking. It can also delay the blanking signals, but I’m not sure what it’s used for.

Before compiling and running it, we have to add the Verilog files of the modules we added to the `jtscratch.qip` file, like so (we already had `scratch_game.v`):

```
# scratch
set_global_assignment -name VERILOG_FILE [file join $::quartus(qip_path) scratch_game.v ]
set_global_assignment -name VERILOG_FILE [file join $::quartus(qip_path) scratch_video.v ]

# jtframe
set_global_assignment -name VERILOG_FILE [file join $::quartus(qip_path) ../modules/jtframe/hdl/clocking/jtframe_cen48.v ]
set_global_assignment -name VERILOG_FILE [file join $::quartus(qip_path) ../modules/jtframe/hdl/video/jtframe_vtimer.v ]
set_global_assignment -name VERILOG_FILE [file join $::quartus(qip_path) ../modules/jtframe/hdl/video/jtframe_blank.v ]
```

The result is a grid like below. We can see that it is shifted right by one pixel, but we are going to investigate that later. Maybe it’s what the delay in `jtframe_blank` is for, but my tests have not been very successful.

## Palette RAM

_Git tag: `palette-ram`_

For the next step, we are going to add a memory to hold a colour palette, and make the video display this palette. For the moment we are going to fill the palette at synthesis time using a `.hex` file.

In `scratch_video.v`, we replace the lines between `reg  [3:0] r, g, b;` and `assign col_in = { r, g, b };` with:

```
wire [15:0] rgb;
reg  [ 7:0] palette_addr;

jtframe_ram #(
	.dw         ( 16            ),
	.aw         (  8            ),
	.simhexfile ( ""            ),
	.synfile    ( "palette.hex" )
)(
	.clk  ( clk          ),
	.cen  ( 1'b1         ),
	.data (              ),
	.addr ( palette_addr ),
	.we   ( 1'b0         ),
	.q    ( rgb          )
);

always @( posedge clk ) if( pxl_cen ) begin
	palette_addr <= { V[7:4], H[7:4] };
end

wire [11:0] col_in, col_out;

assign col_in = rgb[11:0];
```

We create a RAM with 8 bits of address and 16 bits of data, and fill it at synthesis time with hex file `hdl/palette.hex`, which looks like this:

```
0000
0111
0222
0333
0444
0555
0666
0777
0888
...
```

As we have four bits per pixel in our core, the three rightmost hex digits of the RAM data each represent the value of a colour component. We choose the four least significant bits (LSBs) to represent the red component, then green, and finally blue. The four most significant bits (MSBs) are unused and left at 0.

Next we change the `always` block to generate the address for the palette RAM instead of the grid we had before. We take bits 4 to 7 of the horizontal counter, which will increment the palette address by one position every 16 pixels, displaying 16 colours per line, as we have 256 pixels on a line. And to the left of that, we append bits 4 to 7 of the vertical counter, which will increment the palette address by 16 positions every 16 lines. This will result in 16x16-pixel colour blocks, displaying the first 224 colours of our palette.

Finally, we assign the data output of the palette RAM to the `col_in` wire we already have, and we just need to change the order of the colours in the assignment from `col_out` to match the order we decided on, red being on the left:

```
assign { blue, green, red } = col_out;
```

After adding the `jtframe_ram` source file to the `.qip` file, we can compile the core, and look at the result.

```
set_global_assignment -name VERILOG_FILE [file join $::quartus(qip_path) ../modules/jtframe/hdl/ram/jtframe_ram.v ]
```

We can see that the palette starts two pixels to the right of the edge of the screen, and the rightmost pixels wrap around to the left. This is because it takes a couple of pixel clock cycles to generate the coulour data. At least one with the `<=` assignment in the `always` block (the second pixel probably comes from the fact that, in `jtframe_vtimer`, the `H` counter is initialised to `HB_END = 383`.) To remedy this, we are going to add a delay of two pixels to the blanking signals, using the `DLY` parameter of the `jtframe_blank` module:

```
jtframe_blank #( .DLY(2), .DW(12) ) u_blank(
...
```
