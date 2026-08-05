from config.settings import PORT, ALLOWED_ORIGINS, RAZORPAY_KEY_ID, ENV

def test_settings_defaults():
    assert isinstance(PORT, int)
    assert isinstance(ALLOWED_ORIGINS, list)
    assert len(ALLOWED_ORIGINS) > 0
    assert isinstance(RAZORPAY_KEY_ID, str)
    assert isinstance(ENV, str)
