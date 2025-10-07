from flask import Flask, jsonify
import yfinance as yf
import datetime
from waitress import serve

app = Flask(__name__)


@app.get("/api/stocks/<string:stock>")
def stock_api(stock: str):
    ticker = yf.Ticker(stock)
    info = ticker.get_info()

    if "regularMarketPrice" not in info:
        return jsonify({"error": "Invalid ticker!"}), 400

    previous_close = info["previousClose"]
    current_price = info["regularMarketPrice"]
    percent_change = round(((current_price - previous_close) / previous_close) * 100, 2)

    historical_percents = calulcate_stock_changes(ticker)

    return jsonify(
        {
            "stock": stock,
            "price": round(info["regularMarketPrice"], 2),
            "percent": percent_change,
            "percent_1mo": historical_percents["1mo"],
            "percent_6mo": historical_percents["6mo"],
            "percent_1y": historical_percents["1y"],
        }
    )


def calulcate_stock_changes(ticker: yf.Ticker):
    data = {}

    for date in ["1mo", "6mo", "1y"]:
        hist = ticker.history(date)
        start_price = hist["Close"].iloc[0]
        end_price = hist["Close"].iloc[-1]
        pct_change = ((end_price - start_price) / start_price) * 100
        data[date] = round(pct_change, 2)

    return data


if __name__ == "__main__":
    print("Starting server...\t[http://127.0.0.1:9820]")
    serve(app, host="127.0.0.1", port="9820")
