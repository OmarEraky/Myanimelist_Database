# MyAnimeList Database v2 - Installation Guide

This guide describes two methods to install and run the MyAnimeList Database v2 on a new computer.

---

## Prerequisites
1.  **MySQL Server (v8.0+)**: Ensure MySQL is installed and running.
    *   Ideally, use `root` or a user with `ALL PRIVILEGES`.
2.  **Dataset**: Ensure you have the project folder containing `Schema.sql`, `raw_data/`, and `python_scripts/`.


## 1 : Re-Build from Source

### Step 1: Environment Setup
1.  Install Python 3.9+.
2.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
    *(Ensure `pandas`, `mysql-connector-python`, `numpy`, and `flask` are installed)*

### Step 2: Database Initialization
1.  Log in to MySQL and run the schema file to create the tables:
    ```bash
    mysql -u root -p < Schema.sql
    ```

### Step 3: Run the ETL Loader
1.  Open `python_scripts/complete_etl.py`.
2.  **Update the Database Config** (Lines 10-16):
    *   Set your MySQL `user` and `password`.
3.  **Run the ETL Loader**: 
    *   Run the Python script. It will read the CSVs from raw_data/, process 100% of the columns (formatting dates, cleaning numbers, sorting IDs), and insert them into the database.
    ```bash
    python python_scripts/complete_etl.py
    ```
✅ **Done.** The script will parse the raw CSVs and populate the database from scratch (takes ~2-5 mins).

---

## 2. Running the Web Interface

After the database is set up, you can run the web-based search & insert interface.

### Step 1: Configure Database Connection
1.  Open `web_interface/app.py`.
2.  **Update the `DB_CONFIG` dictionary** at the top of the file with your local MySQL credentials:
    ```python
    DB_CONFIG = {
        'host': 'localhost',
        'database': 'myanimelist_db_v2',
        'user': 'root',       # Your MySQL Username
        'password': 'password' # Your MySQL Password
    }
    ```

### Step 2: Run the Application
From the root of the project directory (where `requirements.txt` is located), run:

```bash
python web_interface/app.py
```

### Step 3: Access in Browser
Open your web browser and navigate to:

[http://127.0.0.1:5000](http://127.0.0.1:5000)

*   **Search Page**: Use filters (Genre, Medium, Status) to query the database.
*   **Insert Pages**: Navigate to "Insert Anime" or "Insert Manga" to add new records.
    *   *Note: Hold `Ctrl` (Windows/Linux) or `Cmd` (Mac) to select multiple items in lists (Genres, Studios, etc.).*