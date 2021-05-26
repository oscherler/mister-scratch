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

reg  [3:0] r, g, b;

always @( posedge clk ) if( pxl_cen ) begin
	r <= 4'h0;
	g <= H[4] == 1'b0 ? 4'h0 : 4'hf;
	b <= V[4] == 1'b0 ? 4'h0 : 4'hf;
end

wire [11:0] col_in, col_out;

assign col_in = { r, g, b };

jtframe_blank #( .DLY(0), .DW(12) ) u_blank(
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

assign { red, green, blue } = col_out;

endmodule
