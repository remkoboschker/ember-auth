example 'adapter init', (env) ->
  klass = Em.String.classify env
  opts  = {}

  it 'initializes the given adapter', ->
    opts["#{env}Adapter"] = 'dummy'
    spy  = sinon.collection.spy Em.Auth[klass].Dummy, 'create'
    auth = null
    auth = emAuth.create opts
    expect(spy).toHaveBeenCalledWithExactly { auth: auth }

  it 'throws if adapter not found', ->
    opts["#{env}Adapter"] = 'foo'
    expect(-> emAuth.create opts).toThrow()
