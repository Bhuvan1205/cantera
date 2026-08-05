import firebase_admin
from config.firebase import _initialize_firebase

def test_firebase_singleton_initialization():
    # Calling _initialize_firebase multiple times must not raise or fail
    _initialize_firebase()
    _initialize_firebase()
    assert True
