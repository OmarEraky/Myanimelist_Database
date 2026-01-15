import pandas as pd
import ast
import re
from datetime import datetime
import csv
import os
import numpy as np

OUTPUT_DIR = 'csv_exports'
CSV_PATHS = {
    'anime': 'raw_data/anime_entries.csv',
    'manga': 'raw_data/manga_entries.csv'
}

# --- Data Stores ---
maps = {
    'Genre': {}, 'Theme': {}, 'Demographic': {}, 
    'Producer': {}, 'Studio': {}, 'Licensor': {},
    'Source': {}, 'AgeRating': {}, 'Author': {}, 
    'Serialization': {}, 'Synonym': {}, 'Language': {},
    'StatusType': {}, 'ItemType': {}
}

# Pre-populate Language (English/Japanese)
counters = {k: 0 for k in maps}
counters['Entry'] = 0

lookup_rows = {k: [] for k in maps}

# --- Parsing Helpers ---
def parse_date_range(date_str):
    if pd.isna(date_str) or date_str in ['Unknown', '?']: return None, None
    parts = date_str.split(' to ')
    s, e = parts[0].strip(), parts[1].strip() if len(parts)>1 else None
    def p(d):
        if not d or d=='?': return None
        try: return datetime.strptime(d, '%b %d, %Y').strftime('%Y-%m-%d')
        except: 
            try: return datetime.strptime(d, '%b %Y').strftime('%Y-%m-01')
            except: 
                try: return datetime.strptime(d, '%Y').strftime('%Y-01-01')
                except: return None
    return p(s), p(e)

def parse_duration(dur_str):
    if pd.isna(dur_str) or dur_str == 'Unknown': return None
    hr = re.search(r'(\d+)\s*hr\.', dur_str)
    mn = re.search(r'(\d+)\s*min\.', dur_str)
    total = (int(hr.group(1)) * 60 if hr else 0) + (int(mn.group(1)) if mn else 0)
    return total if total > 0 else None

def parse_list(col_val):
    if pd.isna(col_val): return []
    v = str(col_val).strip()
    if not v: return []
    if v.startswith('[') and v.endswith(']'):
        try: return ast.literal_eval(v)
        except: return []
    return [v] # Plain string case

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

# --- ID Management ---
def register_lookup(table, key, row_data_func):
    if key in maps[table]: return maps[table][key]
    counters[table] += 1
    new_id = counters[table]
    maps[table][key] = new_id
    lookup_rows[table].append(row_data_func(new_id))
    return new_id

# --- Main Processing ---
def run():
    print("Initializing CSV Export...")
    
    # Pre-register Languages
    register_lookup('Language', 'Japanese', lambda i: [i, 'Japanese'])
    register_lookup('Language', 'English', lambda i: [i, 'English'])
    register_lookup('Language', 'German', lambda i: [i, 'German'])
    register_lookup('Language', 'French', lambda i: [i, 'French'])
    register_lookup('Language', 'Spanish', lambda i: [i, 'Spanish'])
    
    # File pointers
    f_entry = open(f'{OUTPUT_DIR}/Entry.csv', 'w', newline='', encoding='utf-8')
    w_entry = csv.writer(f_entry)
    w_entry.writerow(['entry_id','mal_id','medium_type','link','title_name','score','description','background','item_type_id','scored_by','ranked','popularity','members','favorited'])
    
    f_anime = open(f'{OUTPUT_DIR}/AnimeDetails.csv', 'w', newline='', encoding='utf-8')
    w_anime = csv.writer(f_anime)
    w_anime.writerow(['entry_id','duration','duration_minutes','from_airing_date','to_airing_date','episodes','status_id','source_id','age_rating_id','premier_date_season','premier_date_year','broadcast_date_day','broadcast_date_time','broadcast_date_timezone'])
    
    f_manga = open(f'{OUTPUT_DIR}/MangaDetails.csv', 'w', newline='', encoding='utf-8')
    w_manga = csv.writer(f_manga)
    w_manga.writerow(['entry_id','from_publishing_date','to_publishing_date','volumes','chapters','status_id'])

    f_lang = open(f'{OUTPUT_DIR}/LanguageEntry.csv', 'w', newline='', encoding='utf-8')
    w_lang = csv.writer(f_lang)
    w_lang.writerow(['entry_id','language_id','title_text'])

    # Junction Buffers
    junctions = {k: [] for k in ['EntryGenre','EntryTheme','EntryDemographic','EntryProducer','EntryStudio','EntryLicensor','EntryAuthor','EntrySerialization','EntrySynonym']}

    def process_medium(medium, path):
        print(f"Processing {medium}...")
        df = pd.read_csv(path).replace({np.nan: None})
        if 'id' in df.columns:
            df = df.sort_values('id')
        
        for _, row in df.iterrows():
            counters['Entry'] += 1
            e_id = counters['Entry']
            
            # Lookups
            itype_name = row.get('item_type') or 'Unknown'
            it_id = register_lookup('ItemType', (medium, itype_name), lambda i: [i, medium, itype_name])
            
            stat_name = row.get('status') or 'Unknown'
            stat_id = register_lookup('StatusType', (medium, stat_name), lambda i: [i, medium, stat_name])
            
            # Entry
            w_entry.writerow([
                e_id, row['id'], medium, row['link'], row['title_name'], 
                row.get('score'), row.get('description',''), row.get('background',''), it_id,
                row.get('scored_by'), row.get('ranked'), row.get('popularity'), row.get('members'), row.get('favorited')
            ])
            
            # Details
            if medium == 'anime':
                dur = row.get('duration')
                s_date, e_date = parse_date_range(row.get('airing_date'))
                
                # Parsing
                p_season, p_year = parse_premier(row.get('premier_date'))
                b_day, b_time, b_tz = parse_broadcast(row.get('broadcast_date'))

                src = row.get('source') or 'Unknown'
                src_id = register_lookup('Source', src, lambda i: [i, src])
                rat = row.get('age_rating') or 'None'
                code = rat.split(' - ')[0].strip()[:10]
                rat_id = register_lookup('AgeRating', code, lambda i: [i, code, rat])
                
                w_anime.writerow([
                    e_id, dur, parse_duration(dur), s_date, e_date, row.get('episodes'), stat_id, src_id, rat_id,
                    p_season, p_year, b_day, b_time, b_tz
                ])
                
                for p in parse_list(row.get('producers')):
                    junctions['EntryProducer'].append([e_id, register_lookup('Producer', p, lambda i: [i, p])])
                for s in parse_list(row.get('studios')):
                    junctions['EntryStudio'].append([e_id, register_lookup('Studio', s, lambda i: [i, s])])
                for l in parse_list(row.get('licensors')):
                    junctions['EntryLicensor'].append([e_id, register_lookup('Licensor', l, lambda i: [i, l])])

            else: # Manga
                s_date, e_date = parse_date_range(row.get('publishing_date'))
                w_manga.writerow([e_id, s_date, e_date, row.get('volumes'), row.get('chapters'), stat_id])
                
                for auth in parse_list(row.get('authors')):
                    parts = auth.split(',')
                    if len(parts) == 2: lname, fname = parts[0].strip(), parts[1].strip()
                    else: lname, fname = auth.strip(), None
                    junctions['EntryAuthor'].append([e_id, register_lookup('Author', auth, lambda i: [i, fname, lname, auth])])
                    
                for ser in parse_list(row.get('serialization')):
                    junctions['EntrySerialization'].append([e_id, register_lookup('Serialization', ser, lambda i: [i, ser])])

            # Common
            for g in parse_list(row.get('genres')):
                junctions['EntryGenre'].append([e_id, register_lookup('Genre', g, lambda i: [i, g])])
            for t in parse_list(row.get('themes')):
                junctions['EntryTheme'].append([e_id, register_lookup('Theme', t, lambda i: [i, t])])
            for d in parse_list(row.get('demographic')):
                junctions['EntryDemographic'].append([e_id, register_lookup('Demographic', d, lambda i: [i, d])])
                
            syns = str(row.get('synonymns',''))
            if syns and syns.lower() not in ['nan','none','']:
                for s in [x.strip() for x in syns.split(',') if x.strip()]:
                    junctions['EntrySynonym'].append([e_id, register_lookup('Synonym', s, lambda i: [i, s])])
                    
            # Language Entries
            lang_cols = {
                'japanese_name': 'Japanese',
                'english_name': 'English',
                'german_name': 'German',
                'french_name': 'French',
                'spanish_name': 'Spanish'
            }
            for col, l_name in lang_cols.items():
                if row.get(col):
                    w_lang.writerow([e_id, maps['Language'][l_name], row[col]])

    process_medium('anime', CSV_PATHS['anime'])
    process_medium('manga', CSV_PATHS['manga'])
    
    f_entry.close(); f_anime.close(); f_manga.close(); f_lang.close()
    
    # Write Lookups
    print("Writing Lookups & Junctions...")
    def write_csv(name, headers, rows):
        with open(f'{OUTPUT_DIR}/{name}.csv', 'w', newline='', encoding='utf-8') as f:
            w = csv.writer(f); w.writerow(headers); w.writerows(rows)

    write_csv('Genre', ['genre_id','name'], lookup_rows['Genre'])
    write_csv('Theme', ['theme_id','name'], lookup_rows['Theme'])
    write_csv('Demographic', ['demographic_id','name'], lookup_rows['Demographic'])
    write_csv('Producer', ['producer_id','name'], lookup_rows['Producer'])
    write_csv('Studio', ['studio_id','name'], lookup_rows['Studio'])
    write_csv('Licensor', ['licensor_id','name'], lookup_rows['Licensor'])
    write_csv('Serialization', ['serialization_id','name'], lookup_rows['Serialization'])
    write_csv('Source', ['source_id','source_name'], lookup_rows['Source'])
    write_csv('AgeRating', ['age_rating_id','code','description'], lookup_rows['AgeRating'])
    write_csv('Author', ['author_id','first_name','last_name','display_name'], lookup_rows['Author'])
    write_csv('Synonym', ['synonym_id','synonym_text'], lookup_rows['Synonym'])
    write_csv('Language', ['language_id','language_name'], lookup_rows['Language'])
    write_csv('StatusType', ['status_id','medium_type','status_name'], lookup_rows['StatusType'])
    write_csv('ItemType', ['item_type_id','medium_type','type_name'], lookup_rows['ItemType'])
    
    write_csv('EntryGenre', ['entry_id','genre_id'], junctions['EntryGenre'])
    write_csv('EntryTheme', ['entry_id','theme_id'], junctions['EntryTheme'])
    write_csv('EntryDemographic', ['entry_id','demographic_id'], junctions['EntryDemographic'])
    write_csv('EntryProducer', ['entry_id','producer_id'], junctions['EntryProducer'])
    write_csv('EntryStudio', ['entry_id','studio_id'], junctions['EntryStudio'])
    write_csv('EntryLicensor', ['entry_id','licensor_id'], junctions['EntryLicensor'])
    write_csv('EntryAuthor', ['entry_id','author_id'], junctions['EntryAuthor'])
    write_csv('EntrySerialization', ['entry_id','serialization_id'], junctions['EntrySerialization'])
    write_csv('EntrySynonym', ['entry_id','synonym_id'], junctions['EntrySynonym'])
    
    print(f"Export Complete. Files saved in {OUTPUT_DIR}/")

if __name__ == '__main__':
    run()
