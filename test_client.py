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


def send_valid_and_invalid_requests():
    base_url = "http://localhost:8080"

    # Valid request
    valid_payload = {
        "inputs": [
            {"name": "Platform", "shape": [1], "datatype": "BYTES", "data": ["PS4"]},
            {"name": "Year", "shape": [1], "datatype": "INT64", "data": [2021]},
            {"name": "Genre", "shape": [1], "datatype": "BYTES", "data": ["Action"]},
            {"name": "Publisher", "shape": [1], "datatype": "BYTES", "data": ["Sony"]},
        ]
    }

    # Invalid request (wrong datatype)
    invalid_payload = {
        "inputs": [
            {"name": "Platform", "shape": [1], "datatype": "BYTES", "data": ["PS4"]},
            {
                "name": "Year",
                "shape": [1],
                "datatype": "BYTES",
                "data": ["invalid_year"],
            },  # Wrong type
            {"name": "Genre", "shape": [1], "datatype": "BYTES", "data": ["Action"]},
            {"name": "Publisher", "shape": [1], "datatype": "BYTES", "data": ["Sony"]},
        ]
    }

    # Send some valid requests
    for i in range(5):
        response = requests.post(
            f"{base_url}/v2/models/video-game-sales-model/infer", json=valid_payload
        )
        print(f"Valid request {i+1}: {response.status_code}")

    # Send some invalid requests
    for i in range(3):
        response = requests.post(
            f"{base_url}/v2/models/video-game-sales-model/infer", json=invalid_payload
        )
        print(f"Invalid request {i+1}: {response.status_code}")


if __name__ == "__main__":
    # Example usage
    # result = predict_game_sales("Nintendo Switch", 2021, "Adventure", "Nintendo")
    # print(f"Predicted North American sales: {result} million units")

    # result = predict_game_sales("PS4", 2022, "Action", "Sony Computer Entertainment")
    # print(f"Predicted North American sales: {result} million units")

    # Test endpoint to check metrics
    send_valid_and_invalid_requests()
