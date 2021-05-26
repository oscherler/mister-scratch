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

scratch_video u_video(
	.rst      ( rst      ),
	.clk      ( clk      ),
	.pxl2_cen ( pxl2_cen ),
	.pxl_cen  ( pxl_cen  ),
	.LHBL_dly ( LHBL_dly ),
	.LVBL_dly ( LVBL_dly ),
	.HS       ( HS       ),
	.VS       ( VS       ),
	.red      ( red      ),
	.green    ( green    ),
	.blue     ( blue     )
);

endmodule
