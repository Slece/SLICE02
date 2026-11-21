import MetaTrader5 as mt5


def test_mt5_constants_exist():
    required = [
        "ACCOUNT_TRADE_MODE_DEMO",
        "ORDER_TYPE_BUY",
        "ORDER_TYPE_SELL",
        "TRADE_ACTION_DEAL",
        "TIMEFRAME_H1",
        "TIMEFRAME_M15",
    ]
    missing = [name for name in required if not hasattr(mt5, name)]
    assert not missing, missing


def test_session_boundaries():
    from datetime import datetime
    now = datetime.now()
    assert 0 <= now.hour <= 23
