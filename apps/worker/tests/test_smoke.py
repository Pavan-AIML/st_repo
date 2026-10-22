"""Smoke test — proves the worker module imports and its helpers
are defined. Doesn't connect to Redis or Postgres."""


def test_module_imports():
    import main

    assert hasattr(main, "main")
    assert hasattr(main, "handle_job")
    assert hasattr(main, "ensure_table")


def test_queue_key_is_set():
    import main

    assert main.QUEUE_KEY == "shoplite:jobs"
