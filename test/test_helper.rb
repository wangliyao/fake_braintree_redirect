class DummyApp
  def initialize(app)
    @app = app
  end

  def call(env)
    p env
    [200, {}, ["OK"]]
  end
end
