import json

import requests


def predict_game_sales(platform, year, genre, publisher, url="http://localhost:8080"):
    """
    Simple function to predict video game sales
    """
    payload = {
        "inputs": [
            {"name": "Platform", "shape": [1], "datatype": "BYTES", "data": [platform]},
            {"name": "Year", "shape": [1], "datatype": "INT64", "data": [year]},
            {"name": "Genre", "shape": [1], "datatype": "BYTES", "data": [genre]},
            {
                "name": "Publisher",
                "shape": [1],
                "datatype": "BYTES",
                "data": [publisher],
            },
        ]
    }

    response = requests.post(
        f"{url}/v2/models/video-game-sales-model/infer",
        json=payload,
        headers={"Content-Type": "application/json"},
    )

    if response.status_code == 200:
        result = response.json()
        prediction = result["outputs"][0]["data"][0]
        return round(prediction, 3)
    else:
        return f"Error: {response.text}"


if __name__ == "__main__":
    # Example usage
    result = predict_game_sales("Nintendo Switch", 2021, "Adventure", "Nintendo")
    print(f"Predicted North American sales: {result} million units")

    result = predict_game_sales("PS4", 2022, "Action", "Sony Computer Entertainment")
    print(f"Predicted North American sales: {result} million units")
