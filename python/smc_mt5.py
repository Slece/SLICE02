from datetime import datetime, time

import MetaTrader5 as mt5

SYMBOL = "Volatility 75 Index"
RISK_PERCENT = 5.0
REWARD_RISK = 2.5
MAX_TRADES = 10
MAX_DAILY_LOSS_PERCENT = 25.0
MAX_DAILY_PROFIT_PERCENT = 100.0
MAGIC = 751525


def initialize():
    if not mt5.initialize():
        raise RuntimeError(f"MT5 initialize failed: {mt5.last_error()}")

    account = mt5.account_info()
    if account is None:
        raise RuntimeError("Compte MT5 inaccessible")

    if account.trade_mode != mt5.ACCOUNT_TRADE_MODE_DEMO:
        raise RuntimeError("Le script refuse le compte réel")

    if not mt5.symbol_select(SYMBOL, True):
        raise RuntimeError(f"Symbole introuvable: {SYMBOL}")


def is_london_or_new_york(now):
    return (time(8, 0) <= now.time() <= time(12, 0) or
            time(13, 0) <= now.time() <= time(17, 0))


def has_open_position():
    positions = mt5.positions_get(symbol=SYMBOL)
    return bool(positions)


def calculate_volume(sl_distance):
    symbol_info = mt5.symbol_info(SYMBOL)
    account = mt5.account_info()

    risk_money = account.balance * RISK_PERCENT / 100.0
    tick_size = symbol_info.trade_tick_size
    tick_value = symbol_info.trade_tick_value

    if sl_distance <= 0 or tick_size <= 0 or tick_value <= 0:
        return None

    volume = risk_money * tick_size / (sl_distance * tick_value)
    volume = round(volume / symbol_info.volume_step) * symbol_info.volume_step
    volume = min(max(volume, symbol_info.volume_min), symbol_info.volume_max)
    return float(volume)


def place_market(direction):
    tick = mt5.symbol_info_tick(SYMBOL)
    info = mt5.symbol_info(SYMBOL)

    if direction == "BUY":
        price = tick.ask
        sl = price - 100 * info.point
        tp = price + (price - sl) * REWARD_RISK
        order_type = mt5.ORDER_TYPE_BUY
    else:
        price = tick.bid
        sl = price + 100 * info.point
        tp = price - (sl - price) * REWARD_RISK
        order_type = mt5.ORDER_TYPE_SELL

    volume = calculate_volume(abs(price - sl))
    if volume is None:
        return

    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": SYMBOL,
        "volume": volume,
        "type": order_type,
        "price": price,
        "sl": sl,
        "tp": tp,
        "deviation": 50,
        "magic": MAGIC,
        "comment": "SMC synthetic H1/M15",
        "type_filling": mt5.ORDER_FILLING_FOK,
        "type_time": mt5.ORDER_TIME_GTC,
    }

    print(mt5.order_send(request))


def main():
    now = datetime.now()

    if not is_london_or_new_york(now):
        print("Session fermée")
        return

    if has_open_position():
        return

    # Point d'intégration : implémenter ici la détection précise H1
    # CHoCH -> BOS -> retracement OB/FVG -> confirmation M15.
    print("En attente du moteur SMC H1/M15")


if __name__ == "__main__":
    try:
        initialize()
        main()
    finally:
        mt5.shutdown()
