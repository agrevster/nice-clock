# Nice Clock - Scripts

## `pull_team_logo.py`
> Used to pull a team's logo from ESPN.com for use as a clock image.

*Note: Some logos don't work well as they are being downsized and may require manual intervention.*

### Usage:
1. Install decencies: `pip install pillow requests`
2. Find team ID and type from website. `https://www.espn.com/`**`nfl`**`/team/_/name/`**`buf`**`/buffalo-bills`
3. Run the script and enter this info.
4. Congrats! You now have a `PPM` logo for your desired team.

## `stock-api.py`
> Used to serve a simple api that is used for pulling stock information for the stocks module.

*Serves on `127.0.0.1:9820`*

### Usage:
1. Install decencies: `pip install waitress flask yfinance`
2. Run the server in the background or with a rc-service like `local`.
3. Enjoy!

