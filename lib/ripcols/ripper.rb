module Ripcols
  class Ripper
    @@REQUIRED_PATTERNS = %i(HEADER_BEGIN HEADER_END LINE_END)
    def initialize(patterns, in_f=$stdin, out_f=$stdout, err_f=$stderr)
      unless @@REQUIRED_PATTERNS.all? { |req_pattern| patterns.include? req_pattern }
        raise ArgumentError, "all required keys not present.\n Required keys:  #{@@REQUIRED_PATTERNS}"
      end
      # @in_f = in_f
      @out_f = out_f
      @patterns = patterns.dup

      @patterns[  :HEADER_SEP] ||= /\s\s+/
      # @patterns[:LINE_COL_SEP] ||= /\s\s+/
      @patterns[    :LINE_SEP] ||= /\n/


      @hbeg_idx = nil
      @hend_idx = nil

      @fbuf = in_f.read
    end

    def parse
      headers = parse_head
      header_titles = headers.map { |(t)| t }
      lines = body_lines.split( @patterns[:LINE_SEP] )
      col_sep = @patterns[:LINE_COL_SEP]
      lines.map { |line| header_titles.zip( line.split col_sep ).to_h }
    end

    def parse_head
      hbuf = header_lines

      k = hbuf.lines.reduce([]) do |grouping, l|
        off = 0
        l.strip
          .split( @patterns[:'HEADER_SEP'] )
          .each { |w| bc = l.index(w, off);  off = ec = bc + w.length; insert_to( grouping , w, bc, ec);  }
        grouping
      end

      k.sort { |(_, abc), (_, bbc)| abc <=> bbc }
        .map { |(titles, bc, ec)| [titles.join(' '), bc, ec] }

    end


    private

    def body_lines
      header_lines unless @hend_idx
      @fbuf[@hend_idx..-1].lstrip 
    end

    def header_lines
      fbuf = @fbuf
      if @hbeg_idx && @hend_idx
        return fbuf[ @hbeg_idx .. @hend_idx ]
      end

      hbeg_idx = @patterns[:HEADER_BEGIN] =~ fbuf
      unless hbeg_idx
        raise ArgumentError, "Failed to located beginning of Header"
      end

      head_begin_buf = fbuf[ hbeg_idx .. -1 ]
      hend_idx = @patterns[:HEADER_END] =~ head_begin_buf
      unless hend_idx
        raise ArgumentError, @patterns[:HEADER_END], "Failed to locate ending of Header" 
      end

      @hbeg_idx = hbeg_idx
      @hend_idx = hbeg_idx + hend_idx

      head_begin_buf[ 0..hend_idx ]
    end


    # check whether given 2 groups appear within boundaries of each other
    # group = [ title, beginning_column, ending_col ]
    # note: the ending column is exclusive
    def overlap?( group_a, group_b )
      (_, a_bc, a_ec) = group_a
      (_, b_bc, b_ec) = group_b
      (b_bc.between?( a_bc, a_ec.pred ) || 
       b_ec.between?( a_bc, a_ec.pred ) || 
       a_bc.between?( b_bc, b_ec.pred ))
    end


    def insert_to( grouping , title, bc, ec )
      group = grouping.find { |group| overlap?(group, [title, bc, ec]) } 
      if group
        group[0].push( title )
        ibc, iec = group[1..2]
        group[1] = [bc, ibc].min
        group[2] = [ec, iec].max
      else
        grouping.push( [[title], bc, ec] )
      end
    end
  end
end
