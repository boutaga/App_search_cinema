# Cinema Search App

## Directory Structure

Your application directory might look like:

```
cinema_search_app/
├── app.py
├── templates/
│   ├── base.html
│   ├── home.html
│   ...
├── static/
│   └── style.css
├── requirements.txt
```


This web application demonstrates the evolution of database technologies in AI/ML workflows using a practical use case: finding cinemas in Geneva and Lausanne. The app progresses through different stages, each showcasing a specific technology:

1. **Stage 1**: Simple search using `WHERE` and `ILIKE`.
2. **Stage 2**: Full-Text Search.
3. **Stage 3**: Geolocation with PostGIS.
4. **Stage 4**: Travel Time with JSONB and simulated Google Maps API data.
5. **Stage 5**: Semantic Search with `pgvector`.
6. **Stage 6**: Retrieval-Augmented Generation (RAG) search using a Language Model (simulated).
7. **Stage 7**: Graph Database for Complex Relationships.

## **Prerequisites**

- Python 3.7 or higher
- PostgreSQL with the following extensions:
  - PostGIS
  - pgvector
- Required Python packages (listed in `requirements.txt`)

## **Setup Instructions**

### **1. Clone the Repository**

```bash
git clone https://github.com/yourusername/cinema_search_app.git
cd cinema_search_app
```

## 1. System Preparation

### Update and Upgrade the System

Before installing anything, ensure your system is up to date:

```bash
sudo apt update
sudo apt upgrade -y
```

### Install Essential Tools

Install commonly used development tools and libraries:

```bash
sudo apt install -y build-essential curl gnupg lsb-release ca-certificates
```

---

## 2. Install and Configure PostgreSQL

### Install PostgreSQL

Ubuntu’s default repository should have a recent version of PostgreSQL:

```bash
sudo apt install -y postgresql postgresql-contrib
```

This installs the PostgreSQL server and some useful contrib modules. After installation, the PostgreSQL service should start automatically.

Check service status:

```bash
systemctl status postgresql
```

If it’s not running, start it:

```bash
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### Create a Database User and Database

By default, PostgreSQL uses a `postgres` superuser. Switch to that user:

```bash
sudo -u postgres psql
```

In the PostgreSQL prompt:

```sql
-- Create a role (user) with a password
CREATE ROLE cinema_user WITH LOGIN PASSWORD 'cinema_pass';

-- Create the database
CREATE DATABASE cinemas OWNER cinema_user;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE cinemas TO cinema_user;
\q
```

You now have:

- A database named `cinemas`
- A user `cinema_user` with password `cinema_pass`

---

## 3. Install Extensions: PostGIS, pgvector, and Apache AGE (Optional)

### PostGIS

PostGIS is often included with PostgreSQL on Ubuntu:

```bash
sudo apt install -y postgis
```

Enable PostGIS in the `cinemas` database:

```bash
sudo -u postgres psql -d cinemas -c "CREATE EXTENSION postgis;"
```

### pgvector

Ubuntu may have a `pgvector` package. Check and install:

```bash
sudo apt install -y postgresql-15-pgvector
```

(Adjust `15` if a newer version of PostgreSQL is installed. To check your PostgreSQL version: `psql -V`.)

Enable pgvector:

```bash
sudo -u postgres psql -d cinemas -c "CREATE EXTENSION vector;"
```

If `pgvector` is not available via packages, you must build it from source:

1. Install development headers:
    
    ```bash
    sudo apt install -y postgresql-server-dev-15 git
    ```
    
2. Clone and build pgvector:
    
    ```bash
    git clone https://github.com/pgvector/pgvector.git
    cd pgvector
    make
    sudo make install
    ```
    
3. Enable in the database:
    
    ```bash
    sudo -u postgres psql -d cinemas -c "CREATE EXTENSION vector;"
    ```
    

### Apache AGE (Optional, if Graph Support is Desired)

Apache AGE allows you to run graph queries in PostgreSQL.

#### Install Dependencies

```bash
sudo apt install -y git postgresql-server-dev-15 libreadline-dev zlib1g-dev flex bison
```

#### Build and Install AGE

```bash
git clone https://github.com/apache/age.git
cd age
make install
```

This compiles and installs the AGE extension.

#### Enable AGE Extension

```bash
sudo -u postgres psql -d cinemas -c "CREATE EXTENSION age;"
sudo -u postgres psql -d cinemas -c "SET search_path = ag_catalog, '$user', public;"
```

AGE is now available in the `cinemas` database for graph queries.

---

## 4. Set Up the Database Schema and Initial Data

Assuming you have a `cinemas` table and other tables as described previously. For example:

```bash
sudo -u postgres psql -d cinemas
```

```sql
CREATE TABLE cinemas (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    address VARCHAR(255),
    city VARCHAR(100),
    geom GEOMETRY(Point, 4326),
    search_vector TSVECTOR,
    travel_info JSONB,
    embedding vector(768)
);

-- Create required indexes
CREATE INDEX idx_cinemas_geom ON cinemas USING GIST (geom);
CREATE INDEX idx_search_vector ON cinemas USING GIN (search_vector);

-- Insert sample data (Replace with actual coordinates and data)
INSERT INTO cinemas (name, address, city, geom) VALUES
('Cinema Geneva Center', '123 Main St', 'Geneva', ST_SetSRID(ST_MakePoint(6.1432, 46.2044), 4326)),
('Cinema Lausanne Plaza', '456 Avenue Rd', 'Lausanne', ST_SetSRID(ST_MakePoint(6.6323, 46.5197), 4326));

-- Update search_vector column
UPDATE cinemas SET search_vector = to_tsvector('english', name || ' ' || city || ' ' || address);

-- Simulate travel_info
UPDATE cinemas SET travel_info = '{"travel_time": 25, "distance": 15000}' WHERE city='Geneva';
UPDATE cinemas SET travel_info = '{"travel_time": 20, "distance": 10000}' WHERE city='Lausanne';

-- Simulate embeddings (random)
-- For demonstration, you can store a dummy embedding like this:
UPDATE cinemas SET embedding = ARRAY[0.1,0.1,0.1, ... ,0.1]::vector(768);
```

(Replace `0.1,0.1,...` with 768 floats.)

---

## 5. Install and Configure Python Environment

Ubuntu 24.04 should have Python 3.11 by default. Install Python and pip:

```bash
sudo apt install -y python3.11 python3.11-venv python3-pip
```

### Create a Virtual Environment for the App

```bash
python3.11 -m venv env
source env/bin/activate
```

### Install Python Dependencies

In the project directory (where `app.py` and `requirements.txt` reside):

```bash
pip install -r requirements.txt
```

If you don’t have a `requirements.txt`, create one:

```text
Flask==2.2.2
psycopg2-binary==2.9.3
requests==2.31.0
```

Add others if needed.

---

## 6. Configure the Application

### Update `app.py`

Ensure `app.py` uses the correct credentials and connection details:

```python
import psycopg2

def get_db_connection():
    conn = psycopg2.connect(
        host="localhost",
        database="cinemas",
        user="cinema_user",
        password="cinema_pass"
    )
    return conn
```

---

## 7. Run the Application

Activate the virtual environment if not already active:

```bash
cd cinema_search_app
source env/bin/activate
```

Run the Flask app:

```bash
python app.py
```

If `app.py` uses `app.run(debug=True)`, it will start a development server on port 5000 by default.

### Access the App

Open a browser and go to:

```
http://<your_server_ip>:5000/
```

You should see the home page of the Cinema Search App with links to each stage.

---

## 8. (Optional) Systemd Service Setup for the App

If you want the application to start automatically as a service:

1. Create a systemd service file `/etc/systemd/system/cinema_app.service`:
    
  ```ini
    [Unit]
    Description=Cinema Search App
    After=network.target postgresql.service
    
    [Service]
    User=your_username
    WorkingDirectory=/home/your_username/cinema_search_app
    Environment="PATH=/home/your_username/cinema_search_app/env/bin"
    ExecStart=/home/your_username/cinema_search_app/env/bin/python /home/your_username/cinema_search_app/app.py
    Restart=always
    
    [Install]
    WantedBy=multi-user.target
  ```
    
2. Reload systemd and start the service:
    
  ```bash
    sudo systemctl daemon-reload
    sudo systemctl start cinema_app
    sudo systemctl enable cinema_app
  ```
    

The app will now run as a background service.

---

## 9. Troubleshooting Tips

- **PostgreSQL Connection Issues**:  
    Ensure the credentials in `app.py` match the ones you created. Check `pg_hba.conf` if you have authentication errors.
    
- **Missing Extensions**:  
    Make sure you’ve installed and enabled `postgis`, `vector`, and optionally `age` in the `cinemas` database.
    
- **Port Conflicts**:  
    If port 5000 is in use, change `app.run(debug=True)` to `app.run(host='0.0.0.0', port=5001)` or another port.
    
- **Embeddings and RAG**:  
    The instructions show placeholders. For actual semantic search, you need a real embedding model (e.g., `sentence-transformers`) and integrate the code to generate embeddings dynamically.
    
