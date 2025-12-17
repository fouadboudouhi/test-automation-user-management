def test_healthcheck(base_url, requests):
    response = requests.get(f"{base_url}/health")
    assert response.status_code == 200
