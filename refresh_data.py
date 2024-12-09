import os
import requests
import openai
import psycopg2
import psycopg2.extras
from neo4j import GraphDatabase
from bs4 import BeautifulSoup
from flask import Flask, render_template, request

app = Flask(__name__)

GOOGLE_API_KEY = os.environ.get("GOOGLE_API_KEY")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
openai.api_key = OPENAI_API_KEY

NEO4J_URI = "bolt://localhost:7687"
NEO4J_USER = "neo4j"
NEO4J_PASSWORD = "your_neo4j_password"
driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))

def get_db_connection():
    conn = psycopg2.connect(
        host="localhost",
        database="cinemas",
        user="your_username",
        password="your_password"
    )
    return conn

def fetch_cinemas_from_cineman(city):
    """
    Fetch cinemas and their showtimes for the given city from Cineman.ch.
    Example cities: "geneve", "lausanne"
    """
    url = f"https://www.cineman.ch/fr/seances/city/{city}"
    response = requests.get(url)
    if response.status_code != 200:
        return []

    soup = BeautifulSoup(response.text, 'html.parser')

    # The structure of Cineman.ch may differ. This is hypothetical parsing logic.
    # Adjust selectors according to actual HTML structure.
    cinema_cards = soup.select('.cinema-block')  # Example selector
    cinemas = []
    for card in cinema_cards:
        cinema_name = card.select_one('.cinema-name').get_text(strip=True)
        cinema_address = card.select_one('.cinema-address').get_text(strip=True)
        
        # Parse schedules (movies and times)
        # This will depend on the actual HTML. Hypothetical example:
        schedule_data = []
        movie_blocks = card.select('.movie-block')
        for mb in movie_blocks:
            movie_title = mb.select_one('.movie-title').get_text(strip=True)
            showtimes = [st.get_text(strip=True) for st in mb.select('.showtime')]
            schedule_data.append({
                "title": movie_title,
                "showtimes": showtimes
            })

        # We have name, address, schedule. Coordinates not provided, so we’ll geocode.
        cinemas.append({
            "name": cinema_name,
            "address": cinema_address,
            "city": city.capitalize(),
            "schedule": schedule_data
        })

    return cinemas

def geocode_address(address):
    """
    Use the Google Geocoding API to get coordinates for an address.
    """
    if not GOOGLE_API_KEY:
        # Return dummy coordinates if no API key
        return (46.2044, 6.1432)  # Geneva coordinates as fallback
    geo_url = "https://maps.googleapis.com/maps/api/geocode/json"
    params = {
        "address": address,
        "key": GOOGLE_API_KEY
    }
    r = requests.get(geo_url, params=params)
    data = r.json()
    if data['status'] == 'OK':
        loc = data['results'][0]['geometry']['location']
        return (loc['lat'], loc['lng'])
    return (46.2044, 6.1432)  # fallback

def get_travel_time_from_nyon(lat, lng):
    """
    Use the Google Distance Matrix API to get travel time from Nyon to cinema.
    """
    if not GOOGLE_API_KEY:
        return 25  # Simulated fallback
    matrix_url = "https://maps.googleapis.com/maps/api/distancematrix/json"
    params = {
        "origins": "Nyon, Switzerland",
        "destinations": f"{lat},{lng}",
        "key": GOOGLE_API_KEY
    }
    r = requests.get(matrix_url, params=params)
    data = r.json()
    if data['status'] == 'OK':
        elem = data['rows'][0]['elements'][0]
        if elem['status'] == 'OK':
            # travel time in minutes
            return elem['duration']['value'] // 60
    return 25  # fallback

def generate_embedding(text):
    """
    Use OpenAI Embeddings API to generate an embedding for the given text.
    """
    if not OPENAI_API_KEY:
        # Return a dummy embedding
        return [0.1]*768
    response = openai.Embedding.create(
        model="text-embedding-ada-002",
        input=text
    )
    return response['data'][0]['embedding']

def upsert_cinema_postgres(conn, cinema):
    """
    Insert or update cinema in PostgreSQL.
    Use JSONB for storing schedule and possibly reviews.
    """
    name = cinema['name']
    address = cinema['address']
    city = cinema['city']
    schedule = cinema['schedule']
    lat, lng = cinema['coords']
    travel_time = cinema['travel_time']
    # Create a descriptive text for embedding
    description_text = f"{name}, located in {city}, address: {address}. Offers movies: {', '.join([m['title'] for m in schedule])}"
    embedding = generate_embedding(description_text)

    cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
    # Upsert using ON CONFLICT if you have a unique constraint on name+city or just name
    sql = """
    INSERT INTO cinemas (name, address, city, geom, travel_info, google_data, embedding)
    VALUES (%s, %s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326), %s, %s, %s)
    ON CONFLICT (name, city) DO UPDATE SET
        address = EXCLUDED.address,
        geom = EXCLUDED.geom,
        travel_info = EXCLUDED.travel_info,
        google_data = EXCLUDED.google_data,
        embedding = EXCLUDED.embedding;
    """
    travel_info = {"travel_time": travel_time, "distance": 0}
    google_data = {
        "schedule": schedule
        # Could also store reviews if we scrape or have a source for them
    }

    cur.execute(sql, (name, address, city, float(lng), float(lat), psycopg2.extras.Json(travel_info), psycopg2.extras.Json(google_data), embedding))
    conn.commit()

def upsert_cinema_neo4j(cinema):
    """
    Insert or update cinema and its movies in Neo4j.
    """
    name = cinema['name']
    city = cinema['city']
    schedule = cinema['schedule']
    with driver.session() as session:
        # Create Cinema node
        session.run("""
        MERGE (c:Cinema {name: $name, city: $city})
        RETURN c
        """, name=name, city=city)

        for movie_info in schedule:
            movie_title = movie_info['title']
            session.run("""
            MERGE (m:Movie {title: $title})
            MERGE (c:Cinema {name: $name, city: $city})
            MERGE (c)-[:SHOWS]->(m)
            """, title=movie_title, name=name, city=city)

@app.route('/refresh_data', methods=['POST'])
def refresh_data():
    conn = get_db_connection()

    # Fetch cinemas from Cineman for Geneva and Lausanne
    cities = ["geneve", "lausanne"]
    all_cinemas = []
    for c in cities:
        all_cinemas.extend(fetch_cinemas_from_cineman(c))

    # For each cinema, geocode address, get travel time, upsert in Postgres and Neo4j
    for cinema in all_cinemas:
        full_address = f"{cinema['address']}, {cinema['city']}, Switzerland"
        lat, lng = geocode_address(full_address)
        cinema['coords'] = (lat, lng)
        cinema['travel_time'] = get_travel_time_from_nyon(lat, lng)
        upsert_cinema_postgres(conn, cinema)
        upsert_cinema_neo4j(cinema)

    conn.close()
    return "Data refreshed successfully!"
