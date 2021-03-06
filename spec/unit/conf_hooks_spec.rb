
#
# specifying flor
#
# Tue Mar 14 06:12:19 JST 2017
#

require 'spec_helper'


describe 'Flor unit' do

  before :each do

    @unit = Flor::Unit.new('envs/test/etc/conf.json')
    @unit.conf['unit'] = 'uconfhooks'
    #@unit.hook('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate
    @unit.start

    #$: << Dir.pwd unless $:.include?(Dir.pwd)
  end

  after :each do

    @unit.shutdown
  end

  describe 'a conf hook' do

    after :each do

      FileUtils.rm('envs/test/lib/hooks/dot.json', force: true)
    end

    it 'is handed the matching messages' do

      require 'unit/hooks/alpha'
        # require here, since this path is outside of envs/test/

      $seen = []

      hooks = [
        { point: 'receive', class: 'AlphaHook' }
      ]

      File.open('envs/test/lib/hooks/dot.json', 'wb') do |f|
        f.puts(Flor.to_djan(hooks, color: false))
      end

      r =
        @unit.launch(%{
          sequence
            noret _
        }, wait: true)

      expect(r['point']).to eq('terminated')
      expect($seen.size).to eq(6)
    end

    it 'intercepts launch messages' do

      require 'unit/hooks/alpha'
        # require here, since this path is outside of envs/test/

      $seen = []

      hooks = [
        { point: 'execute', nid: '0', class: 'AlphaHook' }
      ]

      File.open('envs/test/lib/hooks/dot.json', 'wb') do |f|
        f.puts(Flor.to_djan(hooks, color: false))
      end

      e0 = @unit.launch(%{ sequence \ noret _ })
      e1 = @unit.launch(%{ sequence \ noret _ })
      @unit.wait('idle')

      expect($seen.collect { |m| m['point'] }.uniq).to eq(%w[ execute ])
      expect($seen.collect { |m| m['nid'] }.uniq).to eq(%w[ 0 ])
      expect($seen.collect { |m| m['exid'] }.uniq.sort).to eq([ e0, e1 ].sort)
      expect($seen.size).to eq(4) # 2 + 2 consumed
    end

    it 'intercepts return messages' do

      require 'unit/hooks/alpha'
        # require here, since this path is outside of envs/test/

      $seen = []

      hooks = [
        { point: 'return', class: 'AlphaHook' }
      ]

      File.open('envs/test/lib/hooks/dot.json', 'wb') do |f|
        f.puts(Flor.to_djan(hooks, color: false))
      end

      @unit.launch(%q{ sequence \ task 'emil' }, wait: true)

      expect($seen.collect { |m| m['point'] }.uniq).to eq(%w[ return ])
      expect($seen.collect { |m| m['nid'] }.uniq).to eq([ '0_0' ])
      expect($seen.size).to eq(2) # 1 + 1 consumed
    end

    it 'intercepts terminated messages' do

      require 'unit/hooks/alpha'
        # require here, since this path is outside of envs/test/

      $seen = []

      hooks = [
        { point: 'terminated', class: 'AlphaHook' }
      ]

      File.open('envs/test/lib/hooks/dot.json', 'wb') do |f|
        f.puts(Flor.to_djan(hooks, color: false))
      end

      e0 = @unit.launch(%{ sequence \ noret _ })
      e1 = @unit.launch(%{ sequence \ noret _ })
      @unit.wait('idle')

      expect($seen.collect { |m| m['point'] }.uniq).to eq(%w[ terminated ])
      expect($seen.collect { |m| m['nid'] }.uniq).to eq([ nil ])
      expect($seen.collect { |m| m['exid'] }.uniq.sort).to eq([ e0, e1 ].sort)
      expect($seen.size).to eq(4) # 2 + 2 consumed
    end

    it 'intercepts cancel messages' do

      require 'unit/hooks/alpha'
        # require here, since this path is outside of envs/test/

      $seen = []

      hooks = [
        { point: 'cancel', class: 'AlphaHook' }
      ]

      File.open('envs/test/lib/hooks/dot.json', 'wb') do |f|
        f.puts(Flor.to_djan(hooks, color: false))
      end

      r = @unit.launch(%q{ sequence \ stall _ }, wait: '0_0 execute')

      @unit.cancel(r['exid'], '0_0')

      @unit.wait(r['exid'], 'terminated')

      expect($seen.collect { |m| m['point'] }.uniq).to eq(%w[ cancel ])
      expect($seen.collect { |m| m['nid'] }.uniq).to eq(%w[ 0_0 ])
      expect($seen.size).to eq(2) # 1 + 1 consumed
    end

    it 'intercepts failed messages' do

      require 'unit/hooks/alpha'
        # require here, since this path is outside of envs/test/

      $seen = []

      hooks = [
        { point: 'failed', class: 'AlphaHook' }
      ]

      File.open('envs/test/lib/hooks/dot.json', 'wb') do |f|
        f.puts(Flor.to_djan(hooks, color: false))
      end

      @unit.launch(%q{ sequence \ fail 'arghh' }, wait: true)

      sleep 0.350

      expect($seen.collect { |m| m['point'] }.uniq).to eq(%w[ failed ])
      expect($seen.collect { |m| m['error']['msg'] }.uniq).to eq(%w[ arghh ])
      expect($seen.collect { |m| m['nid'] }.uniq).to eq(%w[ 0 ])
      expect($seen.size).to eq(2) # 1 + 1 consumed
    end

    it 'may alter a message' do

      require 'unit/hooks/bravo'
        # require here, since this path is outside of envs/test/

      hooks = [
        { point: 'return', consumed: false, class: 'BravoHook' }
      ]

      File.open('envs/test/lib/hooks/dot.json', 'wb') do |f|
        f.puts(Flor.to_djan(hooks, color: false))
      end

      r = @unit.launch(%q{ sequence \ task 'emil' }, wait: 'terminated')

      expect(r['payload']['emil']).to eq("was not here")
    end
  end
end

