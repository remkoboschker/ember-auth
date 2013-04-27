describe 'Em.Auth.Module.Rememberable', ->
  auth         = null
  spy          = null
  rememberable = null

  beforeEach ->
    Em.run ->
      auth = Em.Auth.create
        responseAdapter: 'dummy'
        modules: ['rememberable']
      rememberable = auth.module.rememberable
  afterEach ->
    auth.destroy() if auth
    sinon.collection.restore()

  it 'remember on signInSuccess', ->
    follow 'events', auth, 'signInSuccess',  rememberable, 'remember'
  it 'forget on signInError', ->
    follow 'events', auth, 'signInError',    rememberable, 'forget'
  it 'forget on signOutSuccess', ->
    follow 'events', auth, 'signOutSuccess', rememberable, 'forget'

  describe '#recall', ->
    beforeEach ->
      spy = sinon.collection.spy auth, 'signIn'

    describe 'signed in', ->
      beforeEach -> Em.run -> auth._session.start()

      it 'does nothing', ->
        Em.run -> rememberable.recall()
        expect(spy).not.toHaveBeenCalled()

    describe 'retrieveToken fails', ->
      beforeEach ->
        sinon.collection.stub rememberable, 'retrieveToken', -> null

      it 'does nothing', ->
        Em.run -> rememberable.recall()
        expect(spy).not.toHaveBeenCalled()

    describe 'not signed in', ->
      beforeEach -> Em.run -> auth._session.clear()

      describe 'retrieveToken succeeds', ->
        beforeEach ->
          Em.run -> auth.rememberableTokenKey = 'key'
          sinon.collection.stub rememberable, 'retrieveToken', -> 'foo'

        it 'calls signIn', ->
          Em.run -> rememberable.recall()
          expect(spy).toHaveBeenCalledWithExactly { data: { key: 'foo' } }

        it 'is customizable', ->
          Em.run -> rememberable.recall { foo: 'bar' }
          expect(spy).toHaveBeenCalledWithExactly
            foo: 'bar'
            data: { key: 'foo' }

        it 'marks sign in as originating from recall', ->
          Em.run -> rememberable.recall()
          expect(rememberable.fromRecall).toBeTruthy()

  describe '#remember', ->
    storeTokenSpy = null
    forgetSpy     = null

    beforeEach ->
      storeTokenSpy = sinon.collection.spy rememberable, 'storeToken'
      forgetSpy     = sinon.collection.spy rememberable, 'forget'
      Em.run -> auth.rememberableTokenKey = 'key'

    it 'resets fromRecall marker', ->
      Em.run -> rememberable.remember()
      expect(rememberable.fromRecall).toBeFalsy()

    describe 'remember token found from response', ->
      beforeEach -> Em.run -> auth._response.response = { key: 'foo' }

      describe 'same as existing token', ->
        beforeEach ->
          sinon.collection.stub rememberable, 'retrieveToken', -> 'foo'

        it 'does nothing', ->
          Em.run -> rememberable.remember()
          expect(storeTokenSpy).not.toHaveBeenCalled()
          expect(forgetSpy).not.toHaveBeenCalled()

      describe 'different from existing token', ->
        beforeEach ->
          sinon.collection.stub rememberable, 'retrieveToken', -> 'bar'

        it 'delegates to #storeToken', ->
          Em.run -> rememberable.remember()
          expect(storeTokenSpy).toHaveBeenCalledWithExactly('foo')

        it 'does not forget', ->
          Em.run -> rememberable.remember()
          expect(forgetSpy).not.toHaveBeenCalled()

    describe 'remember token unavailable', ->
      beforeEach -> Em.run -> auth._response.response = {}

      describe 'sign in originating from recall', ->
        beforeEach -> Em.run -> rememberable.fromRecall = true

        it 'does nothing', ->
          Em.run -> rememberable.remember()
          expect(storeTokenSpy).not.toHaveBeenCalled()
          expect(forgetSpy).not.toHaveBeenCalled()

      describe 'sign in not originating from recall', ->
        beforeEach -> Em.run -> rememberable.fromRecall = false

        it 'delegates to #forget', ->
          Em.run -> rememberable.remember()
          expect(forgetSpy).toHaveBeenCalled()

        it 'does not store token', ->
          Em.run -> rememberable.remember()
          expect(storeTokenSpy).not.toHaveBeenCalled()

  it 'delegates #forget to #removeToken', ->
    follow 'delegation', rememberable, 'forget', [], \
    rememberable, 'removeToken', []

  it 'delegates #retrieveToken to session#retrieve', ->
    follow 'delegation', rememberable, 'retrieveToken', [], \
    auth._session, 'retrieve', ['ember-auth-rememberable']

  it 'delegates #storeToken to session#store', ->
    Em.run -> auth.rememberablePeriod = 1
    follow 'delegation', rememberable, 'storeToken', ['foo'], \
    auth._session, 'store', ['ember-auth-rememberable', 'foo', { expires: 1 }]

  it 'delegates #removeToken to session#remove', ->
    follow 'delegation', rememberable, 'removeToken', [], \
    auth._session, 'remove', ['ember-auth-rememberable']

  describe 'auto recall', ->
    beforeEach ->
      em.create (app) ->
        app.Router.map -> @route 'foo'
        app.FooRoute = Em.Route.extend()
        app.Auth = Em.Auth.create
          requestAdapter:  'dummy'
          responseAdapter: 'dummy'
          strategyAdapter: 'dummy'
          sessionAdapter:  'dummy'
          modules: ['rememberable']
        spy = sinon.collection.spy app.Auth.module.rememberable, 'recall'
    afterEach ->
      em.destroy()

    describe 'rememberableAutoRecall = false', ->
      beforeEach -> em.run (app) -> app.Auth.rememberableAutoRecall = false

      it 'does not recall session', ->
        em.ready()
        em.toRoute 'foo'
        expect(spy).not.toHaveBeenCalled()

    describe 'signed in', ->
      beforeEach -> em.run (app) -> app.Auth._session.start()

      it 'does not recall session', ->
        em.ready()
        em.toRoute 'foo'
        expect(spy).not.toHaveBeenCalled()

    describe 'rememberableAutoRecall = true', ->
      beforeEach -> em.run (app) -> app.Auth.rememberableAutoRecall = true

      describe 'not signed in', ->
        beforeEach -> em.run (app) -> app.Auth._session.clear()

        it 'recalls session', ->
          em.ready()
          em.toRoute 'foo'
          expect(spy).toHaveBeenCalledWithExactly { async: false }