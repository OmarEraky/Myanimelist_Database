from flask import Flask, render_template, request, jsonify
import mysql.connector
from mysql.connector import Error
import json

app = Flask(__name__)

# --- Database Config ---
DB_CONFIG = {
    'host': 'localhost',
    'database': 'myanimelist_db_v2',
    'user': 'root',
    'password': '', # Configure your local password here
    'raise_on_warnings': False
}

def get_db_connection():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except Error as e:
        print(f"Error connecting: {e}")
        return None

# --- Routes ---

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/insert/anime')
def insert_anime_page():
    return render_template('insert_anime.html')

@app.route('/insert/manga')
def insert_manga_page():
    return render_template('insert_manga.html')

@app.route('/api/metadata')
def get_metadata():
    """Fetch options for dropdowns (Genres, Studios, etc.)"""
    conn = get_db_connection()
    if not conn: return jsonify({'error': 'DB Connection Failed'}), 500
    cursor = conn.cursor(dictionary=True)
    
    data = {}
    
    # Comprehensive Lookups
    tables = {
        'Genre': 'name', 
        'Theme': 'name', 
        'Demographic': 'name', 
        'Source': 'source_name', 
        'Medium': 'name', 
        'Studio': 'name', 
        'Licensor': 'name',
        'Producer': 'name',
        'StatusType': 'status_name',
        'AgeRating': 'code',
        'Serialization': 'name'
    }
    
    for tbl, col in tables.items():
        cursor.execute(f"SELECT * FROM {tbl} ORDER BY {col}")
        data[tbl] = cursor.fetchall()

    # ItemType with Medium Join for Frontend Compatibility
    cursor.execute("""
        SELECT it.item_type_id, it.type_name, m.name as medium_type 
        FROM ItemType it 
        JOIN Medium m ON it.medium_id = m.medium_id 
        ORDER BY it.type_name
    """)
    data['ItemType'] = cursor.fetchall()
    
    # Author (special case for display_name)
    cursor.execute("SELECT author_id, CONCAT_WS(', ', last_name, first_name) as display_name FROM Author ORDER BY last_name")
    data['Author'] = cursor.fetchall()

    conn.close()
    return jsonify(data)

@app.route('/api/search')
def search():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    # Expanded Select for "All Attributes"
    query = """
        SELECT DISTINCT e.entry_id, e.title_name, e.score, m.name as medium_type, it.type_name, 
               ad.episodes, md.volumes, e.ranked, e.popularity,
               st.status_name, ar.code as age_rating,
               ad.premier_date_season, ad.premier_date_year
        FROM Entry e
        LEFT JOIN ItemType it ON e.item_type_id = it.item_type_id
        LEFT JOIN Medium m ON it.medium_id = m.medium_id
        LEFT JOIN AnimeDetails ad ON e.entry_id = ad.entry_id
        LEFT JOIN MangaDetails md ON e.entry_id = md.entry_id
        LEFT JOIN StatusType st ON (ad.status_id = st.status_id OR md.status_id = st.status_id)
        LEFT JOIN AgeRating ar ON ad.age_rating_id = ar.age_rating_id
        WHERE 1=1
    """
    params = []
    
    # 1. Standard Filters
    if request.args.get('title'):
        query += " AND e.title_name LIKE %s"
        params.append(f"%{request.args.get('title')}%")
        
    if request.args.get('score_min'):
        query += " AND e.score >= %s"
        params.append(request.args.get('score_min'))
        
    medium = request.args.get('medium')
    if medium and medium != 'all':
        query += " AND m.name = %s"
        params.append(medium)

    if request.args.get('item_type_id'):
        query += " AND e.item_type_id = %s"
        params.append(request.args.get('item_type_id'))

    if request.args.get('year'):
        query += " AND ad.premier_date_year = %s"
        params.append(request.args.get('year'))

    if request.args.get('season'):
        query += " AND ad.premier_date_season = %s"
        params.append(request.args.get('season'))

    if request.args.get('status_id'):
        query += " AND (ad.status_id = %s OR md.status_id = %s)"
        params.append(request.args.get('status_id'))
        params.append(request.args.get('status_id'))

    if request.args.get('source_id'):
        query += " AND ad.source_id = %s"
        params.append(request.args.get('source_id'))

    if request.args.get('age_rating_id'):
        query += " AND ad.age_rating_id = %s"
        params.append(request.args.get('age_rating_id'))

    # 2. M2M Filters using Subqueries (Cleaner than JOINs for filtering)
    def add_m2m_filter(param_name, table, col_id):
        val = request.args.get(param_name)
        if val:
            return f" AND e.entry_id IN (SELECT entry_id FROM {table} WHERE {col_id} = %s)", val
        return None, None

    m2m_filters = [
        ('genre_id', 'EntryGenre', 'genre_id'),
        ('theme_id', 'EntryTheme', 'theme_id'),
        ('demographic_id', 'EntryDemographic', 'demographic_id'),
        ('studio_id', 'EntryStudio', 'studio_id'),
        ('producer_id', 'EntryProducer', 'producer_id'),
        ('licensor_id', 'EntryLicensor', 'licensor_id'),
        ('author_id', 'EntryAuthor', 'author_id'),
        ('serialization_id', 'EntrySerialization', 'serialization_id')
    ]

    for param, table, col in m2m_filters:
        sql, val = add_m2m_filter(param, table, col)
        if sql:
            query += sql
            params.append(val)

    # Limit Logic
    try:
        limit = int(request.args.get('limit', 50))
    except (ValueError, TypeError):
        limit = 50
        
    query += " ORDER BY e.popularity ASC LIMIT %s"
    params.append(limit)
    
    cursor.execute(query, params)
    results = cursor.fetchall()
    conn.close()
    return jsonify(results)

def insert_m2m(cursor, entry_id, table, col_id, id_list):
    if not id_list: return
    # Ensure id_list is a list
    if not isinstance(id_list, list): id_list = [id_list]
    for x_id in id_list:
        cursor.execute(f"INSERT INTO {table} (entry_id, {col_id}) VALUES (%s, %s)", (entry_id, x_id))

@app.route('/api/insert/anime', methods=['POST'])
def insert_anime():
    data = request.json
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # 1. Entry Table
        cursor.execute("""
            INSERT INTO Entry (mal_id, title_name, score, item_type_id)
            VALUES (%s, %s, %s, %s)
        """, (data['mal_id'], data['title_name'], data.get('score'), data.get('item_type_id')))
        entry_id = cursor.lastrowid
        
        # 2. AnimeDetails
        cursor.execute("""
            INSERT INTO AnimeDetails (
                entry_id, episodes, status_id, source_id, age_rating_id,
                premier_date_season, premier_date_year, broadcast_date_day,
                duration_minutes
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            entry_id, 
            data.get('episodes'), data.get('status_id'), data.get('source_id'), data.get('age_rating_id'),
            data.get('season'), data.get('year'), data.get('broadcast_day'),
            data.get('duration_minutes')
        ))
        
        # (Entry_Duration logic removed - duration now in AnimeDetails)

        # 3. M2M Relationships
        insert_m2m(cursor, entry_id, 'EntryGenre', 'genre_id', data.get('genres'))
        insert_m2m(cursor, entry_id, 'EntryTheme', 'theme_id', data.get('themes'))
        insert_m2m(cursor, entry_id, 'EntryDemographic', 'demographic_id', data.get('demographics'))
        insert_m2m(cursor, entry_id, 'EntryStudio', 'studio_id', data.get('studios'))
        insert_m2m(cursor, entry_id, 'EntryProducer', 'producer_id', data.get('producers'))
        insert_m2m(cursor, entry_id, 'EntryLicensor', 'licensor_id', data.get('licensors'))

        conn.commit()
        return jsonify({'message': 'Anime Added', 'entry_id': entry_id})
    except Error as e:
        print("SQL Error:", e)
        return jsonify({'error': str(e)}), 400
    finally:
        conn.close()

@app.route('/api/insert/manga', methods=['POST'])
def insert_manga():
    data = request.json
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # 1. Entry Table
        cursor.execute("""
            INSERT INTO Entry (mal_id, title_name, score, item_type_id)
            VALUES (%s, %s, %s, %s)
        """, (data['mal_id'], data['title_name'], data.get('score'), data.get('item_type_id')))
        entry_id = cursor.lastrowid
        
        # 2. MangaDetails
        cursor.execute("""
            INSERT INTO MangaDetails (entry_id, volumes, chapters, status_id)
            VALUES (%s, %s, %s, %s)
        """, (entry_id, data.get('volumes'), data.get('chapters'), data.get('status_id')))

        # 3. M2M Relationships
        insert_m2m(cursor, entry_id, 'EntryGenre', 'genre_id', data.get('genres'))
        insert_m2m(cursor, entry_id, 'EntryTheme', 'theme_id', data.get('themes'))
        insert_m2m(cursor, entry_id, 'EntryDemographic', 'demographic_id', data.get('demographics'))
        insert_m2m(cursor, entry_id, 'EntryAuthor', 'author_id', data.get('authors'))
        insert_m2m(cursor, entry_id, 'EntrySerialization', 'serialization_id', data.get('serializations'))

        conn.commit()
        return jsonify({'message': 'Manga Added', 'entry_id': entry_id})
    except Error as e:
        print("SQL Error:", e)
        return jsonify({'error': str(e)}), 400
    finally:
        conn.close()

@app.route('/api/delete/<int:entry_id>', methods=['DELETE'])
def delete_entry(entry_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM Entry WHERE entry_id = %s", (entry_id,))
        if cursor.rowcount == 0:
            return jsonify({'error': 'Entry not found'}), 404
        conn.commit()
        return jsonify({'message': 'Deleted successfully'})
    except Error as e:
        return jsonify({'error': str(e)}), 400
    finally:
        conn.close()

@app.route('/api/update_score/<int:entry_id>', methods=['POST'])
def update_score(entry_id):
    data = request.json
    new_score = data.get('score')
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE Entry SET score = %s WHERE entry_id = %s", (new_score, entry_id))
        conn.commit()
        return jsonify({'message': 'Score updated'})
    except Error as e:
        return jsonify({'error': str(e)}), 400
    finally:
        conn.close()
@app.route('/update/<int:entry_id>')
def update_page(entry_id):
    # Just render the template; the JS will fetch details
    return render_template('update_entry.html', entry_id=entry_id)

@app.route('/api/entry/<int:entry_id>', methods=['GET'])
def get_entry_details(entry_id):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        # 1. Main Entry Info + Medium from ItemType -> Medium
        cursor.execute("""
            SELECT e.*, m.name as medium_type
            FROM Entry e 
            JOIN ItemType it ON e.item_type_id = it.item_type_id
            JOIN Medium m ON it.medium_id = m.medium_id
            WHERE e.entry_id = %s
        """, (entry_id,))
        entry = cursor.fetchone()
        if not entry: return jsonify({'error': 'Not Found'}), 404

        # 2. Subtype Details
        if entry['medium_type'] == 'anime':
            cursor.execute("SELECT * FROM AnimeDetails WHERE entry_id=%s", (entry_id,))
            details = cursor.fetchone()
        else:
            cursor.execute("SELECT * FROM MangaDetails WHERE entry_id=%s", (entry_id,))
            details = cursor.fetchone()
        
        # Merge details into entry
        if details:
            entry.update(details)

        # 3. Junctions (Get Lists of IDs)
        def get_ids(tbl, col):
            cursor.execute(f"SELECT {col} FROM {tbl} WHERE entry_id=%s", (entry_id,))
            return [x[col] for x in cursor.fetchall()]

        entry['genres'] = get_ids('EntryGenre', 'genre_id')
        entry['themes'] = get_ids('EntryTheme', 'theme_id')
        entry['demographics'] = get_ids('EntryDemographic', 'demographic_id')
        
        if entry['medium_type'] == 'anime':
            entry['studios'] = get_ids('EntryStudio', 'studio_id')
            entry['producers'] = get_ids('EntryProducer', 'producer_id')
            entry['licensors'] = get_ids('EntryLicensor', 'licensor_id')
        else:
            entry['authors'] = get_ids('EntryAuthor', 'author_id')
            entry['serializations'] = get_ids('EntrySerialization', 'serialization_id')

        # Fix JSON serialization for Decimal/Date
        return jsonify(json.loads(json.dumps(entry, default=str)))
    finally:
        conn.close()

@app.route('/api/update/<int:entry_id>', methods=['POST'])
def update_full_entry(entry_id):
    data = request.json
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # 1. Update Entry
        cursor.execute("""
            UPDATE Entry 
            SET title_name=%s, score=%s, description=%s, item_type_id=%s 
            WHERE entry_id=%s
        """, (data['title_name'], data.get('score'), data.get('description'), data.get('item_type_id'), entry_id))
        
        medium = data.get('medium_type') # Passed from frontend to know which subtype table
        
        # 2. Update Subtype
        if medium == 'anime':
            cursor.execute("""
                UPDATE AnimeDetails 
                SET episodes=%s, status_id=%s, source_id=%s, age_rating_id=%s, 
                    premier_date_year=%s, premier_date_season=%s, duration_minutes=%s
                WHERE entry_id=%s
            """, (data.get('episodes'), data.get('status_id'), data.get('source_id'), data.get('age_rating_id'),
                  data.get('premier_date_year'), data.get('premier_date_season'), data.get('duration_minutes'), entry_id))
            
            # Entry_Duration block removed
        else:
            cursor.execute("""
                UPDATE MangaDetails 
                SET volumes=%s, chapters=%s, status_id=%s
                WHERE entry_id=%s
            """, (data.get('volumes'), data.get('chapters'), data.get('status_id'), entry_id))
            
        # 3. M2M Sync (Delete All -> Insert New)
        def sync_m2m(tbl, col, val_list):
            cursor.execute(f"DELETE FROM {tbl} WHERE entry_id=%s", (entry_id,))
            if val_list:
                insert_m2m(cursor, entry_id, tbl, col, val_list)

        sync_m2m('EntryGenre', 'genre_id', data.get('genres'))
        sync_m2m('EntryTheme', 'theme_id', data.get('themes'))
        sync_m2m('EntryDemographic', 'demographic_id', data.get('demographics'))
        
        if medium == 'anime':
            sync_m2m('EntryStudio', 'studio_id', data.get('studios'))
            sync_m2m('EntryProducer', 'producer_id', data.get('producers'))
            sync_m2m('EntryLicensor', 'licensor_id', data.get('licensors'))
        else:
            sync_m2m('EntryAuthor', 'author_id', data.get('authors'))
            sync_m2m('EntrySerialization', 'serialization_id', data.get('serializations'))

        conn.commit()
        return jsonify({'message': 'Update Successful'})
    except Error as e:
        print(e)
        return jsonify({'error': str(e)}), 400
    finally:
        conn.close()

if __name__ == '__main__':
    app.run(debug=True, port=5000)
