"""Smoke test — proves the api module imports and the FastAPI app
is constructed. Doesn't hit the DB."""


def test_app_imports():
    import main

    assert main.app is not None
    assert main.app.title == "ShopLite API"


def test_healthz_route_registered():
    import main

    routes = {r.path for r in main.app.routes}
    assert "/healthz" in routes
    assert "/readyz" in routes
    assert "/metrics" in routes
    assert "/products" in routes
