`default_nettype none

module scratch_video(
	input               rst,
	input               clk,
	output              pxl2_cen,
	output              pxl_cen,
	output              LHBL_dly,
	output              LVBL_dly,
	output              HS,
	output              VS,
	// PROM
	input      [ 8:0]   prog_addr,
	input      [ 7:0]   prog_data,
	input               prom_we,
	// Colours
	output     [ 3:0]   red,
	output     [ 3:0]   green,
	output     [ 3:0]   blue
);

wire       LHBL, LVBL;
wire [8:0] H, V;

jtframe_cen48 u_cen(
	.clk        ( clk       ),    // 48 MHz
	.cen12      ( pxl2_cen  ),
	.cen16      (           ),
	.cen8       (           ),
	.cen6       ( pxl_cen   ),
	.cen4       (           ),
	.cen4_12    (           ),
	.cen3       (           ),
	.cen3q      (           ),
	.cen1p5     (           ),
	.cen12b     (           ),
	.cen6b      (           ),
	.cen3b      (           ),
	.cen3qb     (           ),
	.cen1p5b    (           )
);

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

wire [15:0] rgb;
reg  [ 7:0] palette_addr;

jtframe_prom #(
	.dw ( 8 ),
	.aw ( 8 )
)
u_palette_lo(
	.clk     ( clk                    ),
	.cen     ( 1'b1                   ),
	.data    ( prog_data              ),
	.rd_addr ( palette_addr           ),
	.wr_addr ( prog_addr[8:1]         ),
	.we      ( prom_we & prog_addr[0] ),
	.q       ( rgb[7:0]               )
);

jtframe_prom #(
	.dw ( 8 ),
	.aw ( 8 )
)
u_palette_hi(
	.clk     ( clk                     ),
	.cen     ( 1'b1                    ),
	.data    ( prog_data               ),
	.rd_addr ( palette_addr            ),
	.wr_addr ( prog_addr[8:1]          ),
	.we      ( prom_we & ~prog_addr[0] ),
	.q       ( rgb[15:8]               )
);

always @( posedge clk ) if( pxl_cen ) begin
	palette_addr <= { V[7:4], H[7:4] };
end

wire [11:0] col_in, col_out;

assign col_in = rgb[11:0];

jtframe_blank #( .DLY(2), .DW(12) ) u_blank(
	.clk        ( clk       ),
	.pxl_cen    ( pxl_cen   ),
	.LHBL       ( LHBL      ),
	.LVBL       ( LVBL      ),
	.LHBL_dly   ( LHBL_dly  ),
	.LVBL_dly   ( LVBL_dly  ),
	.preLBL     (           ),
	.rgb_in     ( col_in    ),
	.rgb_out    ( col_out   )
);

assign { blue, green, red } = col_out;

endmodule
