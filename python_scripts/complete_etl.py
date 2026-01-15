import pandas as pd
import mysql.connector
from mysql.connector import Error
import ast
import re
from datetime import datetime
import numpy as np

# Configuration
DB_CONFIG = {
    'host': 'localhost',
    'database': 'myanimelist_db_v2',
    'user': 'root',
    'password': '', # Update it
    'raise_on_warnings': False
}

CSV_PATHS = {
    'anime': 'raw_data/anime_entries.csv',
    'manga': 'raw_data/manga_entries.csv'
}

# --- Parsing Helpers ---

def parse_date_range(date_str):
    if pd.isna(date_str) or date_str in ['Unknown', '?']:
        return None, None
    parts = date_str.split(' to ')
    start_str = parts[0].strip()
    end_str = parts[1].strip() if len(parts) > 1 else None
    
    def parse_single(d_str):
        if not d_str or d_str == '?': return None
        try: return datetime.strptime(d_str, '%b %d, %Y').strftime('%Y-%m-%d')
        except:
            try: return datetime.strptime(d_str, '%b %Y').strftime('%Y-%m-01')
            except:
                try: return datetime.strptime(d_str, '%Y').strftime('%Y-01-01')
                except: return None
    return parse_single(start_str), parse_single(end_str)

def parse_duration(dur_str):
    if pd.isna(dur_str) or dur_str == 'Unknown': return None
    hr_match = re.search(r'(\d+)\s*hr\.', dur_str)
    min_match = re.search(r'(\d+)\s*min\.', dur_str)
    hours = int(hr_match.group(1)) if hr_match else 0
    minutes = int(min_match.group(1)) if min_match else 0
    total = (hours * 60) + minutes
    return total if total > 0 else None

def parse_list(col_val):
    if pd.isna(col_val): return []
    val_str = str(col_val).strip()
    if not val_str: return []
    if val_str.startswith('[') and val_str.endswith(']'):
        try: return ast.literal_eval(val_str)
        except: return []
    return [val_str] # Plain string case

def parse_premier(prem_str):
    # Input: "Fall 2023"
    if pd.isna(prem_str) or prem_str in ['Unknown', '?']: return None, None
    parts = prem_str.split(' ')
    if len(parts) == 2:
        return parts[0], parts[1] # season, year
    return None, None

def parse_broadcast(broad_str):
    # Input: "Fridays at 23:00 (JST)"
    if pd.isna(broad_str) or broad_str == 'Unknown': return None, None, None
    # Regex for "Day at Time (Timezone)"
    m = re.match(r'^(\w+) at (\d{2}:\d{2}) \((.+)\)$', broad_str.strip())
    if m:
        return m.group(1), m.group(2), m.group(3)
    return None, None, None

# --- Database Logic ---

def connect_db():
    return mysql.connector.connect(**DB_CONFIG)

def get_lookup_map(cursor, table, col_name, values, medium_type=None, id_col=None):
    unique_vals = sorted(list(set(v for sublist in values for v in sublist if v)))
    if not unique_vals: return {}

    if not id_col:
        id_col = f"{table.lower()}_id"

    print(f"Upserting {len(unique_vals)} into {table}...")
    
    if medium_type:
        # Pre-insert Medium and get ID
        cursor.execute("INSERT IGNORE INTO Medium (name) VALUES (%s)", (medium_type,))
        cursor.execute("SELECT medium_id FROM Medium WHERE name=%s", (medium_type,))
        m_id = cursor.fetchone()[0]
        
        cursor.executemany(f"INSERT IGNORE INTO {table} (medium_id, {col_name}) VALUES (%s, %s)", 
                           [(m_id, v) for v in unique_vals])
        cursor.execute(f"SELECT {col_name}, {id_col} FROM {table} WHERE medium_id=%s", (m_id,))
    else:
        cursor.executemany(f"INSERT IGNORE INTO {table} ({col_name}) VALUES (%s)", 
                           [(v,) for v in unique_vals])
        cursor.execute(f"SELECT {col_name}, {id_col} FROM {table}")
        
    return {row[0]: row[1] for row in cursor.fetchall()}

def process_medium(medium_type, file_path, conn):
    print(f"\nProcessing {medium_type} from {file_path}...")
    df = pd.read_csv(file_path).replace({np.nan: None})
    if 'id' in df.columns:
        df = df.sort_values('id')
    cursor = conn.cursor()

    # 1. Prepare Data & Generic Lookups
    genres = df['genres'].dropna().apply(parse_list).tolist()
    themes = df['themes'].dropna().apply(parse_list).tolist()
    demographics = df['demographic'].dropna().apply(parse_list).tolist()
    
    genre_map = get_lookup_map(cursor, 'Genre', 'name', genres)
    theme_map = get_lookup_map(cursor, 'Theme', 'name', themes)
    demo_map = get_lookup_map(cursor, 'Demographic', 'name', demographics)
    
    status_list = df['status'].dropna().unique()
    status_map = get_lookup_map(cursor, 'StatusType', 'status_name', [status_list], medium_type=None, id_col='status_id')
    
    itype_list = df['item_type'].dropna().unique()
    type_map = get_lookup_map(cursor, 'ItemType', 'type_name', [itype_list], medium_type=medium_type, id_col='item_type_id')
    
    # 2. Medium-Specific Lookups
    source_map = {}
    rating_map = {}
    producer_map = {}
    studio_map = {}
    licensor_map = {}
    author_map = {}
    serialization_map = {}
    
    if medium_type == 'anime':
        producers = df['producers'].dropna().apply(parse_list).tolist()
        studios = df['studios'].dropna().apply(parse_list).tolist()
        licensors = df['licensors'].dropna().apply(parse_list).tolist()
        
        producer_map = get_lookup_map(cursor, 'Producer', 'name', producers)
        studio_map = get_lookup_map(cursor, 'Studio', 'name', studios)
        licensor_map = get_lookup_map(cursor, 'Licensor', 'name', licensors)
        
        sources = df['source'].dropna().unique()
        source_map = get_lookup_map(cursor, 'Source', 'source_name', [sources])
        
        ratings = df['age_rating'].dropna().unique()
        for r in ratings:
             code = r.split(' - ')[0].strip()[:10]
             cursor.execute("""
                INSERT IGNORE INTO AgeRating (code, description) VALUES (%s, %s)
                ON DUPLICATE KEY UPDATE description=VALUES(description)
             """, (code, r))
        conn.commit()
        cursor.execute("SELECT description, age_rating_id FROM AgeRating") 
        rating_map = {row[0]: row[1] for row in cursor.fetchall()}
        
    else: # Manga
        # Authors
        authors = df['authors'].dropna().apply(parse_list).tolist()
        valid_authors = set(a for sublist in authors for a in sublist if a)
        print(f"Upserting {len(valid_authors)} Authors...")
        auth_tuples = []
        raw_to_parsed = {}
        for auth in valid_authors:
             parts = auth.split(',')
             if len(parts) == 2: lname, fname = parts[0].strip(), parts[1].strip()
             else: lname, fname = auth.strip(), None
             auth_tuples.append((fname, lname))
             raw_to_parsed[auth] = (fname, lname)

        cursor.executemany("INSERT IGNORE INTO Author (first_name, last_name) VALUES (%s, %s)", auth_tuples)
        conn.commit()
        
        cursor.execute("SELECT first_name, last_name, author_id FROM Author")
        # Build composite key map
        comp_map = {(row[0], row[1]): row[2] for row in cursor.fetchall()}
        
        author_map = {}
        for raw, parsed in raw_to_parsed.items():
            if parsed in comp_map:
                 author_map[raw] = comp_map[parsed]
        
        # Serializations
        serials = df['serialization'].dropna().apply(parse_list).tolist()
        serialization_map = get_lookup_map(cursor, 'Serialization', 'name', serials)

    # 3. Language Prep
    # Ensure standard languages exist
    langs = ['Japanese', 'English', 'German', 'French', 'Spanish']
    cursor.executemany("INSERT IGNORE INTO Language (language_name) VALUES (%s)", [(l,) for l in langs])
    conn.commit()
    cursor.execute("SELECT language_name, language_id FROM Language")
    lang_map = {row[0]: row[1] for row in cursor.fetchall()}

    # 4. Process Entries
    print(f"Inserting {medium_type} entries...")
    
    junctions = {
        'Genre': [], 'Theme': [], 'Demographic': [], 'Synonym': [],
        'Producer': [], 'Studio': [], 'Licensor': [], 'Author': [], 'Serialization': []
    }
    language_entries = [] # (entry_id, lang_id, text)
    synonyms_to_insert = set()

    for idx, row in df.iterrows():
        try:
            mal_id = row['id']
            # Entry Info
            t_id = type_map.get(row.get('item_type'))
            
            cursor.execute("""
                INSERT INTO Entry (
                    mal_id, link, title_name, score, description, background, item_type_id,
                    scored_by, ranked, popularity, members, favorited
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE 
                    title_name=VALUES(title_name), item_type_id=VALUES(item_type_id),
                    score=VALUES(score), scored_by=VALUES(scored_by), ranked=VALUES(ranked),
                    popularity=VALUES(popularity), members=VALUES(members), favorited=VALUES(favorited)
            """, (mal_id, row['link'], row['title_name'], row.get('score'), 
                  row.get('description', ''), row.get('background', ''), t_id,
                  row.get('scored_by'), row.get('ranked'), row.get('popularity'), row.get('members'), row.get('favorited')))
            
            cursor.execute("SELECT entry_id FROM Entry WHERE mal_id=%s AND item_type_id=%s", (mal_id, t_id))
            res = cursor.fetchone()
            if not res: continue
            entry_id = res[0]
            
            # Subtype Details
            stat_id = status_map.get(row.get('status'))
            
            if medium_type == 'anime':
                dur_raw = row.get('duration', '')
                dur_min = parse_duration(dur_raw)
                s_date, e_date = parse_date_range(row.get('airing_date', ''))
                
                # New Parsing
                p_season, p_year = parse_premier(row.get('premier_date'))
                b_day, b_time, b_tz = parse_broadcast(row.get('broadcast_date'))
                
                src_id = source_map.get(row.get('source'))
                rat_id = rating_map.get(row.get('age_rating'))
                
                cursor.execute("""
                    INSERT INTO AnimeDetails (
                        entry_id, duration_minutes, from_airing_date, to_airing_date, episodes, status_id, source_id, age_rating_id,
                        premier_date_season, premier_date_year, broadcast_date_day, broadcast_date_time, broadcast_date_timezone
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON DUPLICATE KEY UPDATE 
                        status_id=VALUES(status_id),
                        premier_date_season=VALUES(premier_date_season), premier_date_year=VALUES(premier_date_year),
                        broadcast_date_day=VALUES(broadcast_date_day), broadcast_date_time=VALUES(broadcast_date_time), broadcast_date_timezone=VALUES(broadcast_date_timezone),
                        duration_minutes=VALUES(duration_minutes)
                """, (entry_id, dur_min, s_date, e_date, 
                      row.get('episodes') if str(row.get('episodes')).isdigit() else None,
                      stat_id, src_id, rat_id,
                      p_season, p_year, b_day, b_time, b_tz))
                      
                # Entry_Duration block removed
                      
            else: # Manga
                s_date, e_date = parse_date_range(row.get('publishing_date', ''))
                cursor.execute("""
                    INSERT INTO MangaDetails (entry_id, from_publishing_date, to_publishing_date, volumes, chapters, status_id)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    ON DUPLICATE KEY UPDATE from_publishing_date=VALUES(from_publishing_date), status_id=VALUES(status_id)
                """, (entry_id, s_date, e_date,
                      row.get('volumes') if str(row.get('volumes')).isdigit() else None,
                      row.get('chapters') if str(row.get('chapters')).isdigit() else None,
                      stat_id))
            
            # Junctions Helper
            def add_junc(col, map_obj, target_list):
                vals = parse_list(row.get(col))
                for v in vals:
                    if v in map_obj: target_list.append((entry_id, map_obj[v]))

            add_junc('genres', genre_map, junctions['Genre'])
            add_junc('themes', theme_map, junctions['Theme'])
            add_junc('demographic', demo_map, junctions['Demographic'])
            
            if medium_type == 'anime':
                add_junc('producers', producer_map, junctions['Producer'])
                add_junc('studios', studio_map, junctions['Studio'])
                add_junc('licensors', licensor_map, junctions['Licensor'])
            else:
                add_junc('authors', author_map, junctions['Author'])
                add_junc('serialization', serialization_map, junctions['Serialization'])

            # Synonyms
            syns_raw = str(row.get('synonymns', ''))
            if syns_raw and syns_raw.lower() not in ['nan', 'none', '']:
                syn_list = [s.strip() for s in syns_raw.split(',') if s.strip()]
                for s in syn_list:
                    synonyms_to_insert.add(s)
                    junctions['Synonym'].append((entry_id, s))

            # Languages (Japanese/English/German/French/Spanish columns)
            lang_cols = {
                'japanese_name': 'Japanese',
                'english_name': 'English',
                'german_name': 'German',
                'french_name': 'French',
                'spanish_name': 'Spanish'
            }
            
            for col, l_name in lang_cols.items():
                if col in row and row[col] and str(row[col]).lower() not in ['nan', 'none', '']:
                    language_entries.append((entry_id, lang_map[l_name], str(row[col])))

        except Error as e:
            print(f"Error on row {idx}: {e}")

    conn.commit()
    
    # 5. Batch Insert Junctions
    print("Inserting Junctions...")
    
    def batch_ins(tbl, col_fk1, col_fk2, data):
        if not data: return
        data = list(set(data))
        cursor.executemany(f"INSERT IGNORE INTO {tbl} ({col_fk1}, {col_fk2}) VALUES (%s, %s)", data)
        conn.commit()

    batch_ins('EntryGenre', 'entry_id', 'genre_id', junctions['Genre'])
    batch_ins('EntryTheme', 'entry_id', 'theme_id', junctions['Theme'])
    batch_ins('EntryDemographic', 'entry_id', 'demographic_id', junctions['Demographic'])
    if medium_type == 'anime':
        batch_ins('EntryProducer', 'entry_id', 'producer_id', junctions['Producer'])
        batch_ins('EntryStudio', 'entry_id', 'studio_id', junctions['Studio'])
        batch_ins('EntryLicensor', 'entry_id', 'licensor_id', junctions['Licensor'])
    else:
        batch_ins('EntryAuthor', 'entry_id', 'author_id', junctions['Author'])
        batch_ins('EntrySerialization', 'entry_id', 'serialization_id', junctions['Serialization'])
        
    # Synonyms
    if synonyms_to_insert:
        print(f"Processing {len(synonyms_to_insert)} unique synonyms...")
        cursor.executemany("INSERT IGNORE INTO Synonym (synonym_text) VALUES (%s)", [(s,) for s in synonyms_to_insert])
        conn.commit()
        cursor.execute("SELECT synonym_text, synonym_id FROM Synonym")
        syn_db_map = {row[0]: row[1] for row in cursor.fetchall()}
        final_syn_junc = []
        for eid, txt in junctions['Synonym']:
            if txt in syn_db_map: final_syn_junc.append((eid, syn_db_map[txt]))
        batch_ins('EntrySynonym', 'entry_id', 'synonym_id', final_syn_junc)

    # Language Entries
    if language_entries:
        print(f"Processing {len(language_entries)} language titles...")
        # Remove duplicates if any (same entry, same language)
        language_entries = list(set(language_entries))
        # Insert or update
        cursor.executemany("""
            INSERT INTO LanguageEntry (entry_id, language_id, title_text) 
            VALUES (%s, %s, %s)
            ON DUPLICATE KEY UPDATE title_text=VALUES(title_text)
        """, language_entries)
        conn.commit()

    print(f"Finished {medium_type}.")

if __name__ == "__main__":
    conn = connect_db()
    if conn:
        process_medium('anime', CSV_PATHS['anime'], conn)
        process_medium('manga', CSV_PATHS['manga'], conn)
        conn.close()
        print("Done.")
