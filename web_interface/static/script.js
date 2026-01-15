// Basic Fetch Logic

async function doSearch() {
    // Gather all filter values
    const filters = {
        title: document.getElementById('s_title')?.value,
        medium: document.getElementById('s_medium')?.value,
        score_min: document.getElementById('s_score')?.value,
        item_type_id: document.getElementById('s_item_type')?.value,
        status_id: document.getElementById('s_status')?.value,
        source_id: document.getElementById('s_source')?.value,
        age_rating_id: document.getElementById('s_rating')?.value,
        genre_id: document.getElementById('s_genre')?.value,
        genre_id: document.getElementById('s_genre')?.value,
        theme_id: document.getElementById('s_theme')?.value,
        season: document.getElementById('s_season')?.value,
        year: document.getElementById('s_year')?.value,
        limit: document.getElementById('s_limit')?.value || 50
    };

    const params = new URLSearchParams();
    for (const [key, val] of Object.entries(filters)) {
        if (val && val !== 'all') params.append(key, val);
    }

    try {
        const response = await fetch(`/api/search?${params.toString()}`);
        const data = await response.json();
        renderResults(data);
    } catch (e) {
        console.error("Search failed", e);
    }
}

function renderResults(data) {
    const container = document.getElementById('results');
    container.innerHTML = '';

    if (data.length === 0) {
        container.innerHTML = '<div style="grid-column: 1/-1; text-align: center;">No results found.</div>';
        return;
    }

    data.forEach(item => {
        const div = document.createElement('div');
        div.className = 'card';
        // Check both episode and volume/chapter fields
        let details = '';
        if (item.episodes) details += `${item.episodes} eps `;
        if (item.premier_date_year) details += `(${item.premier_date_year}) `;
        if (item.premier_date_season) details += `${item.premier_date_season} `;
        if (item.volumes) details += `${item.volumes} vols `;

        div.innerHTML = `
            <span class="score">${item.score || 'N/A'}</span>
            <h3>${item.title_name}</h3>
            <div class="meta">${item.type_name || item.medium_type}</div>
            <div class="meta">${item.status_name || '-'}</div>
            <div class="meta">${details}</div>
            <div class="meta" style="font-size:0.8rem">${item.age_rating || ''}</div>
            <div class="actions" style="margin-top: 10px; border-top: 1px solid #333; padding-top: 5px;">
                <button onclick="window.location.href='/update/${item.entry_id}'" style="background:#3498db; color:#fff; border:none; padding:5px 10px; cursor:pointer; margin-right:5px;">Edit</button>
                <button onclick="deleteEntry(${item.entry_id})" style="background:#c0392b; color:#fff; border:none; padding:5px 10px; cursor:pointer;">Delete</button>
            </div>
        `;
        container.appendChild(div);
    });
}

async function deleteEntry(id) {
    if (!confirm('Are you sure you want to DELETE this entry? This action cannot be undone.')) return;
    try {
        const res = await fetch(`/api/delete/${id}`, { method: 'DELETE' });
        const json = await res.json();
        if (res.ok) {
            alert(json.message);
            doSearch(); // Refresh
        } else {
            alert(json.error);
        }
    } catch (e) {
        alert("Delete failed: " + e);
    }
}

async function updateScore(id) {
    const newScore = prompt("Enter new score (0.00 - 10.00):");
    if (newScore === null) return;
    if (isNaN(newScore) || newScore < 0 || newScore > 10) {
        alert("Invalid score");
        return;
    }
    try {
        const res = await fetch(`/api/update_score/${id}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ score: newScore })
        });
        const json = await res.json();
        if (res.ok) {
            alert(json.message);
            doSearch();
        } else {
            alert(json.error);
        }
    } catch (e) {
        alert("Update failed: " + e);
    }
}

// Global store for metadata
let metaDataStore = {};

// Filter Logic shared between Search and Insert
function filterDropdowns(mediumContext) {
    // 1. Update status
    if (document.getElementById('s_status')) {
        updateDropdown('s_status', metaDataStore.StatusType, 'status_id', 'status_name');
    }

    // 2. Update Item Type
    if (document.getElementById('s_item_type')) {
        updateDropdown('s_item_type', metaDataStore.ItemType, 'item_type_id', 'type_name',
            item => mediumContext === 'all' || item.medium_type === mediumContext);
    }
}

function updateDropdown(id, list, valKey, textKey, filterFn) {
    const sel = document.getElementById(id);
    if (!sel) return;

    // Save current selection if possible
    const currentVal = sel.value;

    sel.innerHTML = '<option value="">Any/Select...</option>';

    let filtered = list;
    if (filterFn) filtered = list.filter(filterFn);

    filtered.forEach(item => {
        const opt = document.createElement('option');
        opt.value = item[valKey];
        opt.textContent = item[textKey];
        sel.appendChild(opt);
    });

    // Restore selection if it still exists in the filtered list
    if (filtered.some(i => String(i[valKey]) === currentVal)) {
        sel.value = currentVal;
    }
}

// Load metadata
async function loadMetadata() {
    try {
        const res = await fetch('/api/metadata');
        metaDataStore = await res.json();

        // 1. Populate Insert Pages (Static)
        // Anime Insert
        if (document.getElementById('insertAnimeForm')) {
            updateDropdown('in_item_type', metaDataStore.ItemType, 'item_type_id', 'type_name', i => i.medium_type === 'anime');
            updateDropdown('in_status', metaDataStore.StatusType, 'status_id', 'status_name');
            updateDropdown('in_source', metaDataStore.Source, 'source_id', 'source_name');
            updateDropdown('in_rating', metaDataStore.AgeRating, 'age_rating_id', 'code');

            // M2M - Anime
            updateDropdown('in_genre', metaDataStore.Genre, 'genre_id', 'name');
            updateDropdown('in_theme', metaDataStore.Theme, 'theme_id', 'name');
            updateDropdown('in_demographic', metaDataStore.Demographic, 'demographic_id', 'name');
            updateDropdown('in_studio', metaDataStore.Studio, 'studio_id', 'name');
            updateDropdown('in_producer', metaDataStore.Producer, 'producer_id', 'name');
            updateDropdown('in_licensor', metaDataStore.Licensor, 'licensor_id', 'name');
        }

        // Manga Insert
        if (document.getElementById('insertMangaForm')) {
            updateDropdown('in_item_type', metaDataStore.ItemType, 'item_type_id', 'type_name', i => i.medium_type === 'manga');
            updateDropdown('in_status', metaDataStore.StatusType, 'status_id', 'status_name');

            // M2M - Manga
            updateDropdown('in_genre', metaDataStore.Genre, 'genre_id', 'name');
            updateDropdown('in_theme', metaDataStore.Theme, 'theme_id', 'name');
            updateDropdown('in_demographic', metaDataStore.Demographic, 'demographic_id', 'name');
            updateDropdown('in_author', metaDataStore.Author, 'author_id', 'display_name');
            updateDropdown('in_serialization', metaDataStore.Serialization, 'serialization_id', 'name');
        }

        // 2. Populate Search Page (Dynamic)
        if (document.getElementById('s_medium')) {
            // Initial Load (All)
            filterDropdowns('all');
            updateDropdown('s_source', metaDataStore.Source, 'source_id', 'source_name');
            updateDropdown('s_rating', metaDataStore.AgeRating, 'age_rating_id', 'code');
            updateDropdown('s_genre', metaDataStore.Genre, 'genre_id', 'name');
            updateDropdown('s_theme', metaDataStore.Theme, 'theme_id', 'name');
        }

    } catch (e) {
        console.error("Metadata load failed", e);
    }
}

async function handleFormSubmit(event, type) {
    event.preventDefault();
    const form = event.target;

    // Custom Data Gathering to handle Multi-Selects
    const data = {};
    const formData = new FormData(form);

    // Get all keys
    const keys = Array.from(formData.keys());
    const uniqueKeys = [...new Set(keys)];

    uniqueKeys.forEach(key => {
        const values = formData.getAll(key);
        if (values.length > 1) {
            data[key] = values; // Array of strings
        } else {
            data[key] = values[0] === "" ? null : values[0];
        }
    });

    try {
        const res = await fetch(`/api/insert/${type}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();
        const msgDiv = document.getElementById('message');

        if (res.ok) {
            msgDiv.innerHTML = `<span style="color: #2ecc71">Success! ID: ${result.entry_id}</span>`;
            form.reset();
        } else {
            msgDiv.innerHTML = `<span style="color: #e74c3c">Error: ${result.error}</span>`;
        }
    } catch (err) {
        console.error(err);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    if (document.getElementById('s_title')) {
        doSearch();
    }

    // Add Event Listener for Dynamic Filtering
    const medSelect = document.getElementById('s_medium');
    if (medSelect) {
        medSelect.addEventListener('change', (e) => {
            filterDropdowns(e.target.value);
        });
    }

    loadMetadata();

    const animeForm = document.getElementById('insertAnimeForm');
    if (animeForm) animeForm.addEventListener('submit', (e) => handleFormSubmit(e, 'anime'));

    const mangaForm = document.getElementById('insertMangaForm');
    if (mangaForm) mangaForm.addEventListener('submit', (e) => handleFormSubmit(e, 'manga'));
});
