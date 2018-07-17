
module Flor

  def self.parse(input, fname=nil, opts={})

    opts = fname if fname.is_a?(Hash) && opts.empty?

    #Raabro.pp(Flor::Parser.parse(input, debug: 2), colours: true)
    #Raabro.pp(Flor::Parser.parse(input, debug: 3), colours: true)

    if r = Flor::Parser.parse(input, opts)
      r << fname if fname
      r
    else
      r = Flor::Parser.parse(input, opts.merge(error: true))
      fail Flor::ParseError.new(r, fname)
    end
  end

  class ParseError < StandardError

    attr_reader :line, :column, :offset, :msg, :visual, :fname

    def initialize(error_array, fname)

#puts "-" * 80
#p error_array
#puts error_array.last
#puts "-" * 80
      @line, @column, @offset, @msg, @visual = error_array
      @fname = fname

      super("syntax error at line #{@line} column #{@column}")
    end
  end

  module Parser include Raabro

    # parsing

    def ws_star(i); rex(nil, i, /[ \t]*/); end
    def retnew(i); rex(nil, i, /[\r\n]*/); end
    def dot(i); str(nil, i, '.'); end
    def colon(i); str(nil, i, ':'); end
    def semicolon(i); str(nil, i, ';'); end
    def comma(i); str(nil, i, ','); end
    def dquote(i); str(nil, i, '"'); end
    def dollar(i); str(nil, i, '$'); end
    def pipe12(i); rex(:pipe12, i, /\|{1,2}/); end

    def pstart(i); str(nil, i, '('); end
    def pend(i); str(nil, i, ')'); end
    def sbstart(i); str(nil, i, '['); end
    def sbend(i); str(nil, i, ']'); end
    def pbstart(i); str(nil, i, '{'); end
    def pbend(i); str(nil, i, '}'); end

    def null(i); str(:null, i, 'null'); end

    def number(i)
      rex(:number, i, /[-+]?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?/)
    end

    def tru(i); str(nil, i, 'true'); end
    def fls(i); str(nil, i, 'false'); end
    def boolean(i); alt(:boolean, i, :tru, :fls); end

    def colon_eol(i); seq(:colo, i, :colon, :eol); end
    def semicolon_eol(i); seq(nil, i, :semicolon, :eol); end
      #
    def rf_slice(i)
      seq(:refsl, i, :exp, :comma_qmark_eol, :exp)
    end
    def colon_exp(i)
      seq(nil, i, :colon_eol, :exp_qmark)
    end
    def rf_steps(i)
      seq(:refst, i, :exp_qmark, :colon_exp, :colon_exp, '?')
    end
    def rf_sqa_index(i)
      alt(nil, i, :rf_slice, :rf_steps, :exp)
    end
    def rf_sqa_semico_index(i)
      seq(nil, i, :semicolon_eol, :rf_sqa_index)
    end
    def rf_sqa_idx(i)
      seq(:refsq, i, :sbstart, :rf_sqa_index, :rf_sqa_semico_index, '*', :sbend)
    end
    def rf_dot_idx(i)
      seq(nil, i, :dot, :rf_symbol)
    end
    def rf_index(i); alt(nil, i, :rf_dot_idx, :rf_sqa_idx); end
    def rf_symbol(i); rex(:refsym, i, /[^.:;| \b\f\n\r\t"',()\[\]{}#\\]+/); end
      #
    def reference(i); seq(:ref, i, :rf_symbol, :rf_index, '*'); end

    def dqsc(i)

      rex(:dqsc, i, %r{
        (
          \\["\\\/bfnrt] |
          \\u[0-9a-fA-F]{4} |
          \$(?!\() |
          [^\$"\\\b\f\n\r\t]
        )+
      }x)
    end

    def npipe(i); rex(:npipe, i, /[^|)]+/); end

    def dpipe(i)

      seq(:dpipe, i, :eol, :ws_star, :pipe12, :eol, :ws_star, :npipe)
    end

    def dvar(i); rex(:dvar, i, /nid/); end # only "nid" for now
    def dvar_or_node(i); alt(nil, i, :dvar, :node); end

    def dpar(i)

      seq(
        :dpar, i,
        :dollar, :pstart, :eol, :ws_star,
        :dvar_or_node,
        :dpipe, '*',
        :eol, :ws_star, :pend)
    end

    def dpar_or_dqsc(i); alt(nil, i, :dpar, :dqsc); end

    def dqstring(i)
      seq(:dqstring, i, :dquote, :dpar_or_dqsc, '*', :dquote)
    end

    def sqstring(i)
      rex(:sqstring, i, %r{
        '(
          \\['\\\/bfnrt] |
          \\u[0-9a-fA-F]{4} |
          [^'\\\b\f\n\r\t]
        )*'
      }x)
    end

    def rxstring(i)

      rex(:rxstring, i, %r{
        /(
          \\[\/bfnrt] |
          \\u[0-9a-fA-F]{4} |
          [^/\b\f\n\r\t]
        )*/[a-z]*
      }x)
    end

    def comment(i); rex(nil, i, /#[^\r\n]*/); end

    def eol(i); seq(nil, i, :ws_star, :comment, '?', :retnew); end
    def postval(i); rep(nil, i, :eol, 0); end

    def comma_eol(i); seq(nil, i, :comma, :eol, :ws_star); end
    def sep(i); alt(nil, i, :comma_eol, :ws_star); end

    def comma_qmark_eol(i); seq(nil, i, :comma, '?', :eol); end
    def coll_sep(i); alt(nil, i, :comma_qmark_eol, :ws_star); end

    def ent(i)
      seq(:ent, i, :key, :postval, :colon, :postval, :exp, :postval)
    end
    def ent_qmark(i)
      rep(nil, i, :ent, 0, 1)
    end

    def exp_qmark(i); rep(nil, i, :exp, 0, 1); end

    def obj(i); eseq(:obj, i, :pbstart, :ent_qmark, :coll_sep, :pbend); end
    def arr(i); eseq(:arr, i, :sbstart, :exp_qmark, :coll_sep, :sbend); end

    def par(i)
      seq(:par, i, :pstart, :eol, :ws_star, :node, :eol, :ws_star, :pend)
    end

    def val(i)
      altg(:val, i,
        :panode, :par,
        :reference, :sqstring, :dqstring, :rxstring,
        :arr, :obj,
        :number, :boolean, :null)
    end
    def val_ws(i); seq(nil, i, :val, :ws_star); end

    # precedence
    #  %w[ or or ], %w[ and and ],
    #  %w[ equ == != <> ], %w[ lgt < > <= >= ], %w[ sum + - ], %w[ prd * / % ],

    def ssmod(i); str(:sop, i, /%/); end
    def ssprd(i); rex(:sop, i, /[\*\/]/); end
    def sssum(i); rex(:sop, i, /[+-]/); end
    def sslgt(i); rex(:sop, i, /(<=?|>=?)/); end
    def ssequ(i); rex(:sop, i, /(==?|!=|<>)/); end
    def ssand(i); str(:sop, i, 'and'); end
    def ssor(i); str(:sop, i, 'or'); end

    def smod(i); seq(nil, i, :ssmod, :eol, '?'); end
    def sprd(i); seq(nil, i, :ssprd, :eol, '?'); end
    def ssum(i); seq(nil, i, :sssum, :eol, '?'); end
    def slgt(i); seq(nil, i, :sslgt, :eol, '?'); end
    def sequ(i); seq(nil, i, :ssequ, :eol, '?'); end
    def sand(i); seq(nil, i, :ssand, :eol, '?'); end
    def sor(i); seq(nil, i, :ssor, :eol, '?'); end

    def emod(i); jseq(:exp, i, :val_ws, :smod); end
    def eprd(i); jseq(:exp, i, :emod, :sprd); end
    def esum(i); jseq(:exp, i, :eprd, :ssum); end
    def elgt(i); jseq(:exp, i, :esum, :slgt); end
    def eequ(i); jseq(:exp, i, :elgt, :sequ); end
    def eand(i); jseq(:exp, i, :eequ, :sand); end
    def eor(i); jseq(:exp, i, :eand, :sor); end

    alias exp eor

    def key(i); seq(:key, i, :exp); end
    def keycol(i); seq(nil, i, :key, :ws_star, :colon, :eol, :ws_star); end

    def att(i); seq(:att, i, :sep, :keycol, '?', :exp); end
    def head(i); seq(:head, i, :exp); end
    def indent(i); rex(:indent, i, /[ \t]*/); end
    def node(i); seq(:node, i, :indent, :head, :att, '*'); end

    def linjoin(i); rex(nil, i, /[ \t]*[\\|;][ \t]*/); end
    def outjnl(i); seq(nil, i, :linjoin, :comment, '?', :retnew); end
    def outnlj(i); seq(nil, i, :ws_star, :comment, '?', :retnew, :linjoin); end
    def outdent(i); alt(:outdent, i, :outjnl, :outnlj, :eol); end

    def line(i)
      seq(:line, i, :node, '?', :outdent)
    end
    def panode(i)
      seq(:panode, i, :pstart, :eol, :ws_star, :line, '*', :eol, :pend)
    end

    def flor(i); rep(:flor, i, :line, 0); end

    # rewriting

    def line_number(t)

      t.input.string[0..t.offset].scan("\n").count + 1
    end
    alias ln line_number

    def rewrite_par(t)

      Nod.new(t.lookup(:node), nil).to_a
    end

    def rewrite_node(t)

      Nod.new(t, nil).to_a
    end

    def rewrite_ref(t)

#puts "-" * 80
#Raabro.pp(t, colours: true)
#p [ :children, t.subgather(nil).length ]

      tts = t.subgather(nil)

      if tts.length == 1
        tt = tts.first
        [ tt.string, [], ln(tt) ]
      else
        [ '_ref', tts.collect { |tt| rewrite(tt) }, ln(t) ]
      end
    end

    def rewrite_refsym(t)

      s = t.string

      if s.match(/\A\d+\z/)
        [ '_num', s.to_i, ln(t) ]
      else
        [ '_sqs', s, ln(t) ]
      end
    end

    def rewrite_refsq(t)

      tts = t.subgather(nil)

      if tts.length == 1
        rewrite(tts.first)
      else
        [ '_arr', tts.collect { |tt| rewrite(tt) }, ln(t) ]
      end
    end

    def rewrite_refsl(t)

      st, co = t.subgather(nil)

      [ '_obj', [
        [ '_sqs', 'start', ln(st) ], rewrite(st),
        [ '_sqs', 'count', ln(co) ], rewrite(co),
      ], ln(t) ]
    end

    def rewrite_refst(t)

#puts "-" * 80
#Raabro.pp(t, colours: true)
      ts = t.subgather(nil).collect { |tt| tt.name == :colo ? ':' : tt }
      ts.unshift(0) if ts.first == ':'                # begin
      ts.push(':') if ts.count { |t| t == ':' } < 2   #
      ts.push(1) if ts.last == ':'                    # step
      ts.insert(2, -1) if ts[2] == ':'                # end

      be, _, en, _, st = ts
      be = be.is_a?(Integer) ? [ '_num', be, ln(t) ] : rewrite(be)
      en = en.is_a?(Integer) ? [ '_num', en, ln(t) ] : rewrite(en)
      st = st.is_a?(Integer) ? [ '_num', st, ln(t) ] : rewrite(st)

      [ '_obj', [
        [ '_sqs', 'start', be[2] ], be,
        [ '_sqs', 'end', en[2] ], en,
        [ '_sqs', 'step', st[2] ], st,
      ], ln(t) ]
    end

    UNESCAPE = {
      "'" => "'", '"' => '"', '\\' => '\\', '/' => '/',
      'b' => "\b", 'f' => "\f", 'n' => "\n", 'r' => "\r", 't' => "\t"
    }
    def restring(s)
      s.gsub(
        /\\(?:(['"\\\/bfnrt])|u([\da-fA-F]{4}))/
      ) {
        $1 ? UNESCAPE[$1] : [ "#$2".hex ].pack('U*')
      }
    end

    def rewrite_dqsc(t); [ '_sqs', restring(t.string), ln(t) ]; end
    def rewrite_dvar(t); [ '_dvar', t.string, ln(t) ]; end

    def rewrite_dpipe(t)

      n = (t.lookup(:pipe12).string == '|') ? '_dpipe' : '_dor'
      s = t.lookup(:npipe).string.strip

      [ n, s, ln(t) ]
    end

    def rewrite_dpar(t)

      cn = t.subgather(nil).collect { |tt| rewrite(tt) }

      if cn.size == 1
        cn[0]
      else
        [ '_dol', t.subgather(nil).collect { |tt| rewrite(tt) }, ln(t) ]
      end
    end

    def rewrite_dqstring(t)

      cn = t.subgather(nil).collect { |tt| rewrite(tt) }

      if cn.size == 1 && cn[0][0] == '_sqs'
        cn[0]
      else
        [ '_dqs', cn, ln(t) ]
      end
    end

    def rewrite_sqstring(t); [ '_sqs', restring(t.string[1..-2]), ln(t) ]; end
    def rewrite_rxstring(t); [ '_rxs', t.string, ln(t) ]; end

    def rewrite_boolean(t); [ '_boo', t.string == 'true', line_number(t) ]; end
    def rewrite_null(t); [ '_nul', nil, line_number(t) ]; end

    def rewrite_number(t)

      s = t.string; [ '_num', s.index('.') ? s.to_f : s.to_i, ln(t) ]
    end

    def rewrite_obj(t)

      l = ln(t)

      cn =
        t.subgather(nil).inject([]) do |a, tt|
          a << rewrite(tt.c0.c0)
          a << rewrite(tt.c4)
        end
      cn = [ [ '_att', [ [ '_', [], l ] ], l ] ] if cn.empty?

      [ '_obj', cn, l ]
    end

    def rewrite_arr(t)

      l = ln(t)

      cn = t.subgather(nil).collect { |n| rewrite(n) }
      cn = [ [ '_att', [ [ '_', [], l ] ], l ] ] if cn.empty?

      [ '_arr', cn, l ]
    end

    def rewrite_val(t)

      rewrite(t.c0)
    end

    def invert(operation, operand)

      l = operand[2]

      case operation
      when '+'
        if operand[0] == '_num' && operand[1].is_a?(Numeric)
          [ operand[0], - operand[1], l ]
        else
          [ '-', [ operand ], l ]
        end
      when '*'
        [ '/', [ [ 'num', 1, l ], operand ], l ]
      else
fail "don't know how to invert #{operation.inspect}" # FIXME
      end
    end

    def rewrite_exp(t)

#puts "-" * 80
##puts caller[0, 7]
#Raabro.pp(t, colours: true)
      return rewrite(t.c0) if t.children.size == 1

      cn = t.children.collect { |ct| ct.lookup(nil) }

      operation = cn.find { |ct| ct.name == :sop }.string

      operator = operation
      operands = []

      cn.each do |ct|
        if ct.name == :sop
          operator = ct.string
        else
          o = rewrite(ct)
          o = invert(operation, o) if operator != operation
          operands << o
        end
      end

      [ operation, operands, operands.first[2] ]
    end

    class Nod

      attr_accessor :parent, :indent
      attr_reader :type, :children

      def initialize(tree, outdent)

        @parent = nil
        @indent = -1
        @head = 'sequence'
        @children = []
        @line = 0

        @outdent = outdent ? outdent.strip : nil
        @outdent = nil if @outdent && @outdent.size < 1

        read(tree) if tree
      end

      def append(node)

        if @outdent
          if @outdent.index('\\')
            node.indent = self.indent + 2
          elsif @outdent.index('|') || @outdent.index(';')
            node.indent = self.indent
          end
          @outdent = nil
        end

        if node.indent > self.indent
          @children << node
          node.parent = self
        else
          @parent.append(node)
        end
      end

      def to_a

        return [ @head, @children, @line ] unless @children.is_a?(Array)
        return @head if @head.is_a?(Array) && @children.empty?

        cn = @children.collect(&:to_a)

        as, non_atts = cn.partition { |c| c[0] == '_att' }
        atts, suff = [], nil

        as.each do |c|

          c1 = c[1]; c10 = c1.size == 1 && c1[0]
          suff = [] if c10 && c10[1] == [] && %w[ if unless ].include?(c10[0])

          (suff || atts) << c
        end

        atts, non_atts = ta_rework_arr_or_obj(atts, non_atts)

        core = [ @head, atts + non_atts, @line ]
        core = core[0] if core[0].is_a?(Array) && core[1].empty?
        core = ta_rework_core(core) if core[0].is_a?(Array)

        return core unless suff

        [ suff.shift[1][0][0], [ suff.first[1].first, core ], @line ]
      end

      protected

      def ta_rework_arr_or_obj(atts, non_atts)

        return [ atts, non_atts ] unless (
          @head.is_a?(Array) &&
          non_atts.empty? &&
          %w[ _arr _obj ].include?(@head[0]))

        cn = @head[1] + atts + non_atts
        @head = @head[0]

        cn.partition { |c| c[0] == '_att' }
      end

      def ta_rework_core(core)

        hd, cn, ln = core
        s = @tree.lookup(:head).string.strip

        [ '_head', [
          [ '_sqs', s, ln ],
          hd,
          [ '__head', cn, ln ]
        ], ln ]
      end

      def read(tree)

        @tree = tree

        @indent = tree.lookup(:indent).string.length

        ht = tree.lookup(:head)
        @line = Flor::Parser.line_number(ht)

        @head = Flor::Parser.rewrite(ht.c0)
        @head = @head[0] if @head[0].is_a?(String) && @head[1] == []

        atts = tree.children[2..-1]
          .inject([]) { |as, ct|

            kt = ct.children.size == 3 ? ct.children[1].lookup(:key) : nil
            v = Flor::Parser.rewrite(ct.clast)

            if kt
              k = Flor::Parser.rewrite(kt.c0)
              as.push([ '_att', [ k, v ], k[2] ])
            else
              as.push([ '_att', [ v ], v[2] ])
            end }

        @children.concat(atts)

        rework_subtraction if @head == '-'
        rework_addition if @head == '+' || @head == '-'
      end

      def rework_subtraction

        return unless @children.size == 1

        c = @children.first
        return unless c[0] == '_att' && c[1].size == 1

        c = c[1].first

        if c[0] == '_num'
          @head = '_num'
          @children = - c[1]
        elsif %w[ - + ].include?(c[0])
          @head = c[0]
          @children = c[1]
          @children[0] = Flor::Parser.invert('+', @children[0])
        end
      end

      def rework_addition

        katts, atts, cn = @children
          .inject([ [], [], [] ]) { |cn, ct|
            if ct[0] == '_att'
              cn[ct[1].size == 2 ? 0 : 1] << ct
            else
              cn[2] << ct
            end
            cn }

        @children =
          katts + atts.collect { |ct| ct[1].first } + cn
      end
    end

    def rewrite_flor(t)

      prev = root = Nod.new(nil, nil)

      t.gather(:line).each do |lt|
        nt = lt.lookup(:node); next unless nt
        ot = lt.children.last.string
        n = Nod.new(nt, ot)
        prev.append(n)
        prev = n
      end

      root.children.count == 1 ? root.children.first.to_a : root.to_a
    end
    alias rewrite_panode rewrite_flor
  end # module Parser

  def self.unescape_u(cs)

    s = ''; 4.times { s << cs.next }

    [ s.to_i(16) ].pack('U*')
  end

  def self.unescape(s)

    sio = StringIO.new

    cs = s.each_char

    loop do

      c = cs.next

      break unless c

      if c == '\\'
        case cn = cs.next
        when 'u' then sio.print(unescape_u(cs))
        when '\\', '"', '\'' then sio.print(cn)
        when 'b' then sio.print("\b")
        when 'f' then sio.print("\f")
        when 'n' then sio.print("\n")
        when 'r' then sio.print("\r")
        when 't' then sio.print("\t")
        else sio.print("\\#{cn}")
        end
      else
        sio.print(c)
      end
    end

    sio.string
  end
end

