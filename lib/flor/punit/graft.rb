#--
# Copyright (c) 2015-2017, John Mettraux, jmettraux+flor@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Made in Japan.
#++


class Flor::Pro::Graft < Flor::Procedure

  names 'graft', 'import'

  def pre_execute

    @node['execute_message'] = Flor.dup(@message)
    @node['atts'] = []
  end

  def receive_last

    # look up subtree

    sub =
      att('tree', 'subtree', 'flow', 'subflow', nil)
    source_path, source =
      @executor.unit.loader.library(domain, sub, subflows: true)

    fail ArgumentError.new(
      "no subtree #{sub.inspect} found (domain #{domain.inspect})"
    ) unless source

    tree = Flor::Lang.parse(source, source_path, {})

    # graft subtree into parent node

    parent_tree = lookup_tree(parent)
    cid = Flor.child_id(nid)
    parent_tree[1][cid] = tree

    # re-apply self with subtree

    m = @node['execute_message']
    m['tree'] = tree

    [ m ]
  end
end

