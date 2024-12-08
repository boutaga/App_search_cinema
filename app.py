from flask import Flask, render_template, request
import psycopg2
import psycopg2.extras
import os

app = Flask(__name__)

# Database connection
def get_db_connection():
    conn = psycopg2.connect(
        host="localhost",
        database="cinemas",
        user="your_username",
        password="your_password"
    )
    return conn

# Home route
@app.route('/')
def home():
    return render_template('home.html')

# Stage 1: Simple Search with WHERE and ILIKE
@app.route('/stage1', methods=['GET', 'POST'])
def stage1():
    query = request.form.get('query', '')
    results = []
    sql = ""
    if query:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        sql = "SELECT * FROM cinemas WHERE name ILIKE %s OR city ILIKE %s;"
        params = (f"%{query}%", f"%{query}%")
        cur.execute(sql, params)
        results = cur.fetchall()
        conn.close()
    return render_template('stage1.html', query=query, results=results, sql=sql)

# Stage 2: Full-Text Search
@app.route('/stage2', methods=['GET', 'POST'])
def stage2():
    query = request.form.get('query', '')
    results = []
    sql = ""
    if query:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        sql = """
        SELECT *, ts_rank(search_vector, to_tsquery('english', %s)) AS rank
        FROM cinemas
        WHERE search_vector @@ to_tsquery('english', %s)
        ORDER BY rank DESC;
        """
        params = (query, query)
        cur.execute(sql, params)
        results = cur.fetchall()
        conn.close()
    return render_template('stage2.html', query=query, results=results, sql=sql)

# Stage 3: Geolocation with PostGIS
@app.route('/stage3', methods=['GET', 'POST'])
def stage3():
    latitude = request.form.get('latitude', '')
    longitude = request.form.get('longitude', '')
    distance = request.form.get('distance', '5000')  # Default distance in meters
    results = []
    sql = ""
    if latitude and longitude:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        sql = """
        SELECT *, ST_Distance(geom::geography, ST_MakePoint(%s, %s)::geography) AS distance
        FROM cinemas
        WHERE ST_DWithin(geom::geography, ST_MakePoint(%s, %s)::geography, %s)
        ORDER BY distance;
        """
        params = (float(longitude), float(latitude), float(longitude), float(latitude), float(distance))
        cur.execute(sql, params)
        results = cur.fetchall()
        conn.close()
    return render_template('stage3.html', latitude=latitude, longitude=longitude, distance=distance, results=results, sql=sql)

# Stage 4: Travel Time with Google Maps API and JSONB
@app.route('/stage4', methods=['GET', 'POST'])
def stage4():
    # For simplicity, we will simulate travel time data
    # In a real application, you would integrate Google Maps API here
    user_location = request.form.get('user_location', '')
    max_travel_time = request.form.get('max_travel_time', '30')  # in minutes
    results = []
    sql = ""
    if user_location:
        # Simulate fetching cinemas within max_travel_time
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        sql = """
        SELECT *, travel_info->>'travel_time' AS travel_time
        FROM cinemas
        WHERE (travel_info->>'travel_time')::int <= %s
        ORDER BY travel_time;
        """
        params = (int(max_travel_time),)
        cur.execute(sql, params)
        results = cur.fetchall()
        conn.close()
    return render_template('stage4.html', user_location=user_location, max_travel_time=max_travel_time, results=results, sql=sql)

# Stage 5: Semantic Search with pgvector
@app.route('/stage5', methods=['GET', 'POST'])
def stage5():
    query = request.form.get('query', '')
    results = []
    sql = ""
    if query:
        # Generate embedding for the query using a pre-trained model
        # For demonstration, we'll use a placeholder embedding
        query_embedding = [0.1] * 768  # Replace with actual embedding
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        sql = """
        SELECT *, embedding <#> %s AS distance
        FROM cinemas
        ORDER BY distance LIMIT 10;
        """
        params = (query_embedding,)
        cur.execute(sql, params)
        results = cur.fetchall()
        conn.close()
    return render_template('stage5.html', query=query, results=results, sql=sql)

# Stage 6: RAG Search with LLM (Simulated)
@app.route('/stage6', methods=['GET', 'POST'])
def stage6():
    query = request.form.get('query', '')
    response = ''
    sql = ''
    if query:
        # Simulate RAG search
        # Retrieve relevant cinemas using embeddings
        # Generate response using a language model (placeholder)
        response = f"Based on your query '{query}', here are some recommendations..."
        sql = "RAG search involves complex queries combining vector similarity and LLMs."
    return render_template('stage6.html', query=query, response=response, sql=sql)

# Stage 7: Use a graph database to model relationships
@app.route('/stage7', methods=['GET', 'POST'])
def stage7():
    query = request.form.get('query', '')
    results = []
    sql = ""
    if query:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        # Example query to find cinemas showing movies in a specific genre
        sql = """
        SELECT * FROM cypher('cinema_graph', $$
          MATCH (c:Cinema)-[:SHOWS]->(m:Movie)
          WHERE m.genre ILIKE %s
          RETURN c.name AS cinema_name, m.title AS movie_title
        $$) AS (cinema_name agtype, movie_title agtype);
        """
        params = (f"%{query}%",)
        cur.execute(sql, params)
        results = cur.fetchall()
        conn.close()
    return render_template('stage7.html', query=query, results=results, sql=sql)


if __name__ == '__main__':
    app.run(debug=True)