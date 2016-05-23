#--
# Copyright (c) 2015-2016, John Mettraux, jmettraux+flon@gmail.com
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


module Flor

  class DummySequelAdapter < Sequel::Dataset

    class Db
      def supports_schema_parsing?; false; end
      def transaction(opts={}); yield; end
    end

    def initialize(opts)
      @opts = opts
      @db = Db.new
    end

    def fetch_rows(sql); yield([]); end

    DB = Sequel.connect(:adapter => Flor::DummySequelAdapter)
  end

  class FlorModel < Sequel::Model(DummySequelAdapter::DB)

    def data

      @data ||=
        begin
         d = Flor::Storage.from_blob(content)
         d['id'] = id
         d
        end
    end
  end

  class Execution < FlorModel

    def self.terminated

      self.where(status: 'terminated')
    end
  end

  class Timer < FlorModel
  end

  class Trap < FlorModel

    # returns [ remove, [ messages ] ]
    #
    def notify(executor, message)

      return [ false, [] ] unless match?(executor, message)

puts(
  "*** trapped: #{message['point']}\n" +
  "* data: #{self.data.inspect}\n" +
  "* values: #{self.values.select { |k, v| k != :content }.inspect}")
#p message
#p self.values
#p self.data
#p message['payload']
      exe = {
        'point' => 'execute',
        'from' => nid, # FIXME (OK only if same exid)
        'exid' => exid,
        'nid' => Flor.sub_nid("#{nid}_0", executor.counter_next('sub')),
        'cnid' => '0',
        'tree' => self.data['tree'],
        #'payload' => { 'msg' => message }
        'payload' => message['payload'] # FIXME
      }
#pp exe

      [ false, [ exe ] ]
    end

    protected

    def match?(executor, message)

      return false if in_trap_itself?(executor, message)

      return false if texid && texid != message['exid']
      return false if tnid && tnid != message['nid']
      return false if tpoints.any? && ! tpoints.include?(message['point'])
      true
    end

    def in_trap_itself?(executor, message)

      i = message['nid']

      loop do
        break unless i
        return true if i == nid
        node = executor.execution['nodes'][i]
        i = node['parent']
      end

      false
    end

    def tpoints

      @tpoints ||=
        (tpoint || '').split(',').collect(&:strip)
    end
  end

  class Trace < FlorModel
  end

  #class Task < Sequel::Model(DummySequelAdapter::DB)
  #end

  MODELS = [ :executions, :timers, :traps, :traces ]

  class Storage

    MODELS.each do |k|

      define_method(k) do

        s = self
        c = k.to_s[0..-2].capitalize

        @models[k] ||=
          Flor.const_set(
            "#{c}#{@db.hash.to_s.gsub('-', 'M')}",
            Class.new(Flor.const_get(c)) do
              self.dataset = s.db["flon_#{k}".to_sym]
            end)
      end
    end
  end

  class Scheduler

    MODELS.each do |k|

      define_method(k) { @storage.send(k) }
    end
  end
end

