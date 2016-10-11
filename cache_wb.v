//A cache for 32-bit mips
//Trevor Morris
//Tristan Seroff

//CACHE SIZING
//`define CACHE_LINE  //BLOCK_SIZE_BITS + TAG_WIDTH + 1(valid bit) + 1(dirty bit)
`define BLOCK_SIZE_BITS 128
`define NUM_BLOCKS 2048
`define WORD_SIZE 32
`define NUM_WAYS 2

//ADDRESSING
`define ADDRESS_WIDTH 32
`define TAG_WIDTH 17 //ADDRESS_WIDTH - INDEX_WIDTH - BLOCK_OFFSET_WIDTH - 2
`define INDEX_WIDTH 11 //log(2048)
`define BLOCK_OFFSET_WIDTH 2 //4 words/block

//CACHE LOGIC: write-back policy

//READ 
 //if miss and way[use] not dirty, load new block from MM
 //if miss and way[use] dirty, evict old block to MM, load new block from MM
 //if hit, read cache
 
 //WRITE
  //if hit, write to cache with hit and set dirty
  //if miss in both: check way[use]: if dirty, evict old block to MM, load new block from MM, write new data
  //if miss in both: check way[use[: if not dirty, write cache, set dirty = 1


module cache_wb(input clk, reset, read, write, mem_ready,
				input [`ADDRESS_WIDTH-1:0] address,
				input [`WORD_SIZE-1:0] write_data,
				input [`BLOCK_SIZE_BITS-1:0] load_block,
				output reg [`ADDRESS_WIDTH-1:0] load_block_address,
				output [`WORD_SIZE-1:0] read_data,
				output reg [`BLOCK_SIZE_BITS-1:0] evicted_block,
				output reg [`ADDRESS_WIDTH-1:0] evicted_address,
				output reg evict, load,
				output reg ready, wait_for_load);

	//ADDRESSING
	//divide address into tag, index, block_offset
	wire [`TAG_WIDTH-1:0] tag;
	wire [`INDEX_WIDTH-1:0] index;
	wire [`BLOCK_OFFSET_WIDTH-1:0] block_offset;
	assign tag = address[31:15];
	assign index = address[14:4];
	assign block_offset = address[3:2];
	
	//output from cache
	wire valid[`NUM_WAYS-1:0];
	wire dirty[`NUM_WAYS-1:0];
	wire [`TAG_WIDTH-1:0] way_tag[`NUM_WAYS-1:0];
	wire [`BLOCK_SIZE_BITS-1:0] way_block[`NUM_WAYS-1:0];
	
	wire done_load[`NUM_WAYS-1:0];
	wire done_write[`NUM_WAYS-1:0];

	//input to cache
	reg way_write[`NUM_WAYS-1:0];
	reg way_load[`NUM_WAYS-1:0];
	reg [`WORD_SIZE-1:0] way_write_data; //data to write to cache on hit
	reg [`BLOCK_SIZE_BITS-1:0] way_load_block; //block to load to cache on miss
				 
	//cache_way ways[`NUM_WAYS-1:0](clk, reset, way_write, way_load, address, way_write_data, way_load_block, valid, dirty, way_tag, way_block);

	genvar i;
	generate
		for (i=0; i<`NUM_WAYS; i=i+1) begin
        		cache_way ways(clk, reset, way_write[i], way_load[i], address, way_write_data, way_load_block, valid[i], dirty[i], way_tag[i], way_block[i],
				done_load[i], done_write[i]);
    		end
	endgenerate
	
	//next way to use on miss
	integer r;
	reg use_way[`NUM_BLOCKS-1:0];
	//reg uses;
	//reg wait_for_load;
	reg wait_for_write;
	reg write_ready, read_ready;
	reg wait_for_cache_write;
	
	//READING
	//determine if a way hit
	wire [`NUM_WAYS-1:0] way_hit;
	assign way_hit[0] = valid[0] && (way_tag[0] == tag);
	assign way_hit[1] = valid[1] && (way_tag[1] == tag);

	wire hit;
	assign hit = way_hit[0] | way_hit[1];

	
	
	//if there is a hit, assign output_block to the way's output
	wire [`BLOCK_SIZE_BITS-1:0] output_block;
	assign output_block = (way_hit[0]) ? way_block[0] : way_block[1];
		//select word from output_block
	mux4 #(32) wordMux(output_block[31:0],
						output_block[63:32],
						output_block[95:64],
						output_block[127:96],
						block_offset,
						read_data);
	
	
	always @(negedge clk) begin
		if(reset) begin
			//uses = 1'b0;
			load = 1'b0;
			way_write[0] = '0;
			way_write[1] = '0;
			way_load[0] = '0;
			way_load[1] = '0;
			way_write_data = 'x;
			way_load_block = 'x;
			ready = 1'b0;
			wait_for_load = 0;
			wait_for_write = 0;
			write_ready = 0;
			wait_for_cache_write = 0;
			read_ready = 0;
			for(r=0;r<`NUM_BLOCKS; r=r+1)
				use_way[r] = 0;
		end else if(wait_for_cache_write && done_write[use_way[index]]) begin
			ready = 1;
			wait_for_cache_write = 0;
			use_way[index] = !use_way[index];
		end else if(!wait_for_load) begin
			way_write[0] = 1'b0;
			way_write[1] = 1'b0;
			if(read_ready) begin
				use_way[index] = !use_way[index];
				read_ready = 0;
				way_load[0] = '0;
				way_load[1] = '0;
				ready = 1;
			end if(write_ready && done_load[use_way[index]]) begin
				way_load[0] = '0;
				way_load[1] = '0;
				//write to cache that hit
				way_write[0] = 1'b0;
				way_write[1] = 1'b0;
				if(way_hit[0]) begin
					way_write[0] = 1'b1;
					//ready
					wait_for_cache_write = 1;
					write_ready = 0;
				end if(way_hit[1]) begin
					way_write[1] = 1'b1;
					//ready
					write_ready = 0;
					wait_for_cache_write = 1;
				end
				
			end else if(read) begin
				if(hit) begin
					ready = 1;
					if (way_hit[0]) begin
						//output_block <= way_block[0];
						use_way[index] = 1;
					end else if(way_hit[1]) begin
						//output_block <= way_block[1];
						use_way[index] = 0;
					end
				end else begin
					ready = 0;
					//evict dirty block
					if(dirty[use_way[index]]) begin
						evict = 1;
						evicted_block = way_block[use_way[index]];
						evicted_address = {way_tag[use_way[index]], index, 4'b00};
					end
					//tel MM to load new block and start waiting for it
					load = 1'b1;
					load_block_address = address; 
					wait_for_load = 1;
					wait_for_write = 0;
				end
			end else if(write && !write_ready) begin
				way_write_data = write_data;
				if(hit) begin
					//write to cache that hit
					way_write[0] = 1'b0;
					way_write[1] = 1'b0;
					if(way_hit[0]) begin
						way_write[0] = 1'b1;
						use_way[index] = 1;
					end
					if(way_hit[1]) begin
						way_write[1] = 1'b1;
						use_way[index] = 0;
					end
					//ready
					ready = 1;
				end else begin
					way_write[0] = 1'b0;
					way_write[1] = 1'b0;
					ready = 0;
					//evict dirty block
					if(dirty[use_way[index]]) begin
						evict = 1;
						evicted_block = way_block[use_way[index]];
						evicted_address = {way_tag[use_way[index]], index, 4'b00};
					end
					load = 1'b1;
					load_block_address = address; 
					wait_for_load = 1;
					wait_for_write = 1;
				end 
			end
		end else begin
			ready = 0;
			if(wait_for_load && mem_ready) begin
				//on negedge, way will load data provided by MM
				evict = 0;
				way_load[use_way[index]] = 1'b1;
				way_load[!use_way[index]] = 1'b0;
				wait_for_load = 0;
				way_load_block = load_block;
				
				if(wait_for_write) begin
					//on next posedge, will write data
					wait_for_write = 0;
					write_ready = 1;
				end else begin
					read_ready = 1;
				end
			end
		end
	end
	
endmodule

//individual way of associative cache
module cache_way(input clk, reset, write, load,
				 input [`ADDRESS_WIDTH-1:0] address,
				 input [`WORD_SIZE-1:0] write_data, //copied on write
				 input [`BLOCK_SIZE_BITS-1:0] load_block, //copied on load
				 output v, dirty,
				 output [`TAG_WIDTH-1:0] tag,
				 output [`BLOCK_SIZE_BITS-1:0] block,
				 output reg done_load,
				 output reg done_write);
				 
//decompose address
wire [`TAG_WIDTH-1:0] addr_tag;
wire [`INDEX_WIDTH-1:0] addr_index;
wire [`BLOCK_OFFSET_WIDTH-1:0] addr_block_offset;


assign addr_tag = address[31:15];
assign addr_index = address[14:4];
assign addr_block_offset = address[3:2];
				 
//cache contains NUM_BLOCKS lines of the following:
reg memory_valid[`NUM_BLOCKS-1:0];
reg memory_dirty[`NUM_BLOCKS-1:0];
reg [`TAG_WIDTH-1:0] memory_tag[`NUM_BLOCKS-1:0];
reg [`BLOCK_SIZE_BITS-1:0] memory_block[`NUM_BLOCKS-1:0];

//for reset loop
integer i;

//read line at index
assign v = memory_valid[addr_index];
assign dirty = memory_dirty[addr_index];
assign tag = memory_tag[addr_index];
assign block = memory_block[addr_index];

always @(posedge clk) begin
	if (reset) begin
		for(i = 0; i < `NUM_BLOCKS; i = i + 1) begin
			memory_valid[i] <= '0;
			memory_dirty[i] <= '0;
			memory_tag[i] <= 'x;
			memory_block[i] <= '0;
		end
	end else begin
		done_write = 0;
		done_load = 0;
	if (load) begin
		memory_dirty[addr_index] <= 1'b0;
		memory_block[addr_index] <= load_block;
		memory_valid[addr_index] <= 1'b1;
		memory_tag[addr_index] <= addr_tag;
		done_load = 1;
	end
	if (write) begin
		memory_dirty[addr_index] <= 1'b1;
		case (addr_block_offset)
			2'b00: memory_block[addr_index][31:0] <= write_data;
			2'b01: memory_block[addr_index][63:32] <= write_data;
			2'b10: memory_block[addr_index][95:64] <= write_data;
			2'b11: memory_block[addr_index][127:96] <= write_data;
		endcase
		done_write = 1;
	end 
	end
end

endmodule
