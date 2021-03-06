
class Flor::Pro::TypeOf < Flor::Procedure
  #
  # returns the type of argument or the incoming f.ret.
  #
  # ```
  # type-of "hello"   # ==> 'string'
  # type-of 1         # ==> 'number'
  # type-of 1.1       # ==> 'number'
  # type-of [ 'a' 1 ] # ==> 'array'
  # type-of { a: 1 }  # ==> 'object'
  #
  # type {}    # ==> 'object'
  # type true  # ==> 'boolean'
  # ```
  #
  # ## see also
  #
  # array?, number?, ...

  names %w[ type-of type ]

  def pre_execute

    @node['ret'] = receive_payload_ret

    unatt_unkeyed_children
  end

  def receive_payload_ret; payload['ret']; end # don't duplicate the ret

  def receive_last

    wrap('ret' => Flor.type(@node['ret']).to_s)
  end
end

