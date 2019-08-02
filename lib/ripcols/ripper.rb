module Ripcols

  class Ripper
    @@REQUIRED_PATTERNS = %i(HEADER_BEGIN HEADER_END LINE_END)

    def initialize(patterns, str, column_gap=3, out_f=$stdout, err_f=$stderr)
      unless @@REQUIRED_PATTERNS.all? { |req_pattern| patterns.include? req_pattern }
        raise ArgumentError, "all required keys not present.\n Required keys:  #{@@REQUIRED_PATTERNS}"
      end

      @COL_GAP = column_gap

      # @in_f = in_f
      @fbuf = str
      @out_f = out_f

      col_del = /\s{#{@COL_GAP},}/
      @patterns = patterns.dup
      @patterns[  :HEADER_SEP] ||= col_del
      @patterns[:LINE_COL_SEP] ||= col_del
      @patterns[    :LINE_SEP] ||= /\n/


      @hbuf = nil
      @bbuf = nil

      @line_column_begin = 0
    end

    def parse
      headers = parse_head
      lines = body_lines.split( @patterns[:LINE_SEP] )
      # col_sep = @patterns[:LINE_COL_SEP]
      lines.map { |line| columize_line(line, headers) }
    end


    def parse_head
      hbuf = header_lines
      k = hbuf.lines.reduce([]) do |grouping, l|
        off = 0
        l.strip
          .split( @patterns[:'HEADER_SEP'] )
          .each do |w|
            if w.empty?
              next
            end
            bc = l.index(w, off)
            off = ec = bc + w.length
            insert_to( grouping , w, bc, ec )
          end
        grouping
      end

      k = k.sort { |(_, abc), (_, bbc)| abc <=> bbc }
          .map { |(titles, bc, ec)| [titles.join(' '), bc, ec] }

      if k.first
        # todo: (possible BUG!)
        #  this code will break, when the initial columns dont begin from 0,
        #  its better to have some kind of hinting to know where the column
        #  begins.
        #
        # going with simplicity, beginning_column_position of 1st column be 0,
        k.first[1] = @line_column_begin
      end

      k
    end


    private

    # line : single line of string
    # headers : [ (title, bc, ec) ...+ ]
    #
    # OUTPUT
    # ======
    # columized_line : Hash
    # => {"col1": "matching stripped text", ...* }
    #
    # Note
    # ====
    # blank columns will not be part of the result.
    #
    def columize_line line, headers
      return Hash[] if headers.empty?

      ks = {}
      idx = 0
      delim = @patterns[:LINE_COL_SEP]
      unresolved = nil

      headers.each do |(title, bc, ec)|

        if unresolved
          if (unresolved[:text][:ec] + @COL_GAP) < bc
            head = unresolved[:header]
            ks[ head[:title] ] = unresolved[:text][:text]
            idx = unresolved[:text][:ec]
            unresolved = nil
          end
        end

        break unless bc_idx = line.index( /\S/, idx )
        ec_idx = line.index( delim, bc_idx ) || -1
        if (bc_idx - @COL_GAP) <= ec
          unresolved = nil
          idx = ec_idx

          ks[title] = line[bc_idx ... ec_idx]
        else
          unresolved = {
            "text":   Hash[:text, line[bc_idx ... ec_idx], :bc, bc_idx, :ec, ec_idx],
            "header": Hash[:title, title, :bc, bc, :ec, ec],
          }
        end

      end

      ks
    end


    def seperate_body_head
      fbuf = @fbuf
      hbeg_idx = @patterns[:HEADER_BEGIN] =~ fbuf
      unless hbeg_idx
        raise ArgumentError, "Failed to located beginning of Header"
      end

      head_begin_buf = fbuf[ hbeg_idx .. -1 ]
      hend_idx = @patterns[:HEADER_END] =~ head_begin_buf
      unless hend_idx
        raise ArgumentError, @patterns[:HEADER_END], "Failed to locate ending of Header"
      end

      @hbuf = head_begin_buf[ 0..hend_idx ]
      bbuf = $~.post_match

      lend_idx = @patterns[:LINE_END] =~ bbuf
      unless lend_idx
        raise ArgumentError, @patterns[:LINE_END], "Failed to locate ending of lines"
      end
      @bbuf = $~.pre_match
    end

    def header_lines
      return @hbuf if @hbuf
      seperate_body_head
      @hbuf
    end

    def body_lines
      return @bbuf if @bbuf
      seperate_body_head
      @bbuf
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
