from PIL import Image
import requests
import os

LOGO_SIZE = 25


def import_logo(team_div: str, team_id: str):
    image = requests.get(
        f"https://a.espncdn.com/i/teamlogos/{team_div}/500-dark/{team_id}.png"
    )
    with open("tmp.png", "wb") as file:
        _ = file.write(image.content)

    with Image.open("tmp.png") as image:
        resize = image.resize((LOGO_SIZE, LOGO_SIZE))
        resize.save(f"{team_id}.ppm")

    os.remove("tmp.png")


if __name__ == "__main__":
    team_div = input("Enter sport (ncaa,nfl,nba,etc...): ")
    team_id = input("Enter teamid from espn.com: ")

    import_logo(team_div, team_id)
