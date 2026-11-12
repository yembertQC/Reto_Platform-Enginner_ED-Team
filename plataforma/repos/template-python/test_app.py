from app import app


def client():
    return app.test_client()


def test_hello():
    r = client().get("/")
    assert r.status_code == 200
    assert r.get_json() == {"message": "Hola ED Team"}


def test_health():
    r = client().get("/health")
    assert r.status_code == 200
    assert r.get_json() == {"status": "healthy"}


def test_not_found():
    assert client().get("/otra").status_code == 404
