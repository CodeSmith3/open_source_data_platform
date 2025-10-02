# 📘 Gemeente Data Platform - Gebruikershandleiding

**Versie:** 2.0 (Development)  
**Laatst bijgewerkt:** September 2025  
**Voor:** Data Engineers, BI Analisten, Database Beheerders

---

## 📋 Inhoudsopgave

1. [Aan de slag](#aan-de-slag)
2. [Toegang tot het platform](#toegang-tot-het-platform)
3. [Voor Data Engineers - Apache Airflow](#voor-data-engineers---apache-airflow)
4. [Voor BI Analisten - Apache Superset](#voor-bi-analisten---apache-superset)
5. [Voor Database Beheerders - pgAdmin](#voor-database-beheerders---pgadmin)
6. [Overige Tools](#overige-tools)
7. [Problemen oplossen](#problemen-oplossen)
8. [Veelgestelde vragen](#veelgestelde-vragen)

---

## 🚀 Aan de slag

### Wat is het Gemeente Data Platform?

Het Gemeente Data Platform is een complete open-source data stack waarmee je:
- **Data pipelines** kunt bouwen en beheren (Airflow)
- **BI dashboards** kunt maken en analyseren (Superset)
- **Databases** kunt beheren en queries uitvoeren (pgAdmin)
- **Data** kunt opslaan en delen (MinIO, PostgreSQL)

### Wat heb je nodig?

- **Netwerktoegang:** Je laptop moet via netwerkkabel verbonden zijn met het netwerk
- **Account:** Een account aangemaakt door de IT beheerder
- **Browser:** Google Chrome, Firefox, of Microsoft Edge (laatste versie)

---

## 🔐 Toegang tot het platform

### Stap 1: Verbinding maken

1. **Sluit je laptop aan** met een netwerkkabel op het netwerk
2. **Test de verbinding:** Open een browser en ga naar `http://192.168.1.25:8888`
3. Je ziet nu het **Platform Dashboard** met alle beschikbare services

### Stap 2: Account aanvragen

⚠️ **Let op:** Je kunt **geen account zelf aanmaken**. Volg deze stappen:

1. **Stuur een email** naar IT beheer met:
   - Je naam en functie
   - Welke rol je nodig hebt (zie hieronder)
   - Voor welke diensten je toegang nodig hebt
   - Je emailadres voor communicatie

2. **Rollen en toegang:**

   | Rol | Wie | Toegang tot |
   |-----|-----|-------------|
   | **Data Engineer** | Data pipeline ontwikkelaars | Airflow, pgAdmin, MinIO, Spark |
   | **Data Analyst** | BI/data analisten | Superset, pgAdmin (read-only), Grafana |
   | **Database Admin** | Database beheerders | pgAdmin (full), PostgreSQL, backups |
   | **Viewer** | Management, rapportage gebruikers | Superset (read-only), Grafana dashboards |

3. **Verwachte doorlooptijd:** Binnen 1 werkdag ontvang je je inloggegevens

### Stap 3: Eerste keer inloggen

Je ontvangt van IT beheer:
- **Username:** Bijvoorbeeld `jan.jansen`
- **Tijdelijk wachtwoord:** Bijvoorbeeld `Welkom2025!`

⚠️ **Belangrijk:** 
- Email is nog niet geconfigureerd, dus je kunt je wachtwoord **niet zelf resetten**
- Bewaar je wachtwoord goed! Bij verlies moet IT beheer het handmatig resetten
- Wijzig je wachtwoord bij eerste login (instructie volgt per service)

### Stap 4: Single Sign-On (SSO)

Sommige services gebruiken **Keycloak SSO** voor centrale login:

**Services met SSO:**
- Apache Airflow
- Grafana
- Services via OAuth2-proxy (Prometheus, Loki)

**Hoe herken je SSO login?**
- Je ziet een knop "Sign in with Keycloak" of "SSO Login"
- Je wordt doorgestuurd naar een Keycloak login pagina
- Na inloggen wordt je teruggestuurd naar de service

**Services zonder SSO:**
- Apache Superset (eigen login)
- pgAdmin (eigen login)
- MinIO (eigen login)
- Neo4j (eigen login)

---

## 👨‍💻 Voor Data Engineers - Apache Airflow

### Wat is Airflow?

Apache Airflow is een tool voor het **bouwen, plannen en monitoren** van data pipelines (workflows). Denk aan:
- Data ophalen uit externe systemen (bijv. TOPdesk)
- Data transformeren en schoonmaken
- Data laden in databases of data warehouses

### Toegang tot Airflow

1. **Open browser** en ga naar: `http://192.168.1.25:8082`
2. Klik op **"Sign in with keycloak"** (blauwe knop)
3. Log in met je Keycloak credentials
4. Je wordt automatisch teruggestuurd naar Airflow

![Airflow SSO Login](airflow-sso-login.png)

### Je eerste pipeline - Voorbeeld

Het platform bevat een voorbeeld-pipeline: **"topdesk_departments_sync"**

Deze pipeline:
1. Haalt afdelingen op uit TOPdesk via de API
2. Laadt de data in PostgreSQL database
3. Kan handmatig of automatisch worden uitgevoerd

**Stappen om de pipeline te gebruiken:**

#### 1. Pipeline vinden
- Klik op **"DAGs"** in het menu (linksboven)
- Zoek naar `topdesk_departments_sync`
- Klik op de pipeline naam

#### 2. Pipeline begrijpen
- **Graph View:** Visuele weergave van de stappen
  - `extract_topdesk` → haalt data op
  - `load_postgres` → laadt data in database
- **Code View:** Bekijk de Python code
- **Details:** Zie schedule, owner, tags

#### 3. Pipeline uitvoeren
- Klik op het **play-icoon** (▶️) rechtsboven
- Kies **"Trigger DAG"**
- Optioneel: Voeg configuratie toe (JSON)
- Klik **"Trigger"**

#### 4. Uitvoering monitoren
- Klik op de **run** (in de lijst met runs)
- Bekijk de **status** van elke taak:
  - 🟢 Groen = geslaagd
  - 🔴 Rood = gefaald
  - 🟡 Geel = bezig
- Klik op een taak voor **logs**

#### 5. Logs bekijken
- Klik op een taak (bijv. `extract_topdesk`)
- Klik op **"Log"** tab
- Zie gedetailleerde output:
  ```
  Fetching from https://...
  Extracted 25 records
  Successfully loaded 25 records
  ```

### Een nieuwe pipeline maken

⚠️ **Belangrijk:** Pipelines worden via code (Python) beheerd, niet via de UI.

**Stappen:**

1. **Vraag toegang** tot de DAGs folder op de server via IT beheer
2. **Maak een Python bestand** aan: `mijn_pipeline.py`
3. **Gebruik het voorbeeld** als template (zie beheerhandleiding)
4. **Test lokaal** met `pytest` indien mogelijk
5. **Upload** naar de DAGs folder (`/opt/airflow/dags`)
6. **Wacht 1-2 minuten** - Airflow detecteert nieuwe DAGs automatisch
7. **Refresh** de browser - je nieuwe DAG verschijnt

**Voorbeeld pipeline structuur:**

```python
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

default_args = {
    'owner': 'jouw_naam',
    'start_date': datetime(2025, 9, 30),
    'retries': 1,
}

dag = DAG(
    'mijn_pipeline',
    default_args=default_args,
    description='Wat doet deze pipeline',
    schedule_interval='@daily',  # Elke dag
    tags=['jouw_tag'],
)

def mijn_functie():
    print("Hello World!")
    
task = PythonOperator(
    task_id='hello',
    python_callable=mijn_functie,
    dag=dag,
)
```

### Database connecties gebruiken

Airflow heeft **vooraf geconfigureerde connecties**:

1. **PostgreSQL:** `postgres_default`
   ```python
   from airflow.providers.postgres.hooks.postgres import PostgresHook
   pg_hook = PostgresHook(postgres_conn_id='postgres_default')
   ```

2. **MinIO (S3):** `minio_default`
   ```python
   # Connectie naar MinIO object storage
   ```

**Nieuwe connectie toevoegen:**
- Ga naar **Admin → Connections**
- Klik **"+"** (Add connection)
- Vul in:
  - Connection ID: `mijn_api`
  - Connection Type: HTTP
  - Host: `api.example.com`
  - Login/Password: indien nodig
- **Save**

### Variables gebruiken

Voor **configuratie** die niet in code hoort (API keys, URLs):

1. Ga naar **Admin → Variables**
2. Klik **"+"** (Add variable)
3. Vul in:
   - Key: `topdesk_api_url`
   - Value: `https://klantportaal.syntrophos.nl/...`
4. **Save**

**Gebruik in code:**
```python
from airflow.models import Variable

api_url = Variable.get("topdesk_api_url")
```

### Best practices

✅ **Wel doen:**
- Gebruik descriptieve namen voor DAGs en tasks
- Voeg `tags` toe voor organisatie
- Test je code voordat je het upload
- Gebruik logging: `print()` of `logging.info()`
- Sla credentials op in Variables/Connections, niet in code
- Documenteer wat je pipeline doet (docstrings)

❌ **Niet doen:**
- Hardcoded wachtwoorden in code
- Te complexe pipelines (splits op in kleinere)
- Geen error handling
- Dependencies tussen DAGs (gebruik XCom)

### Troubleshooting Airflow

**Pipeline verschijnt niet:**
- Check of bestand in `/opt/airflow/dags` staat
- Check syntax errors in je Python code
- Wacht 2 minuten en refresh browser
- Kijk in Airflow logs: Admin → Logs

**Pipeline faalt:**
- Klik op gefaalde task → **Log** tab
- Lees error message onderaan de log
- Veelvoorkomende problemen:
  - `Connection refused` → Service niet bereikbaar
  - `Authentication failed` → Verkeerde credentials
  - `ModuleNotFoundError` → Library niet geïnstalleerd

**Database connectie werkt niet:**
- Test connectie: Admin → Connections → Test
- Check hostname: gebruik `gemeente_postgres` (niet localhost)
- Check credentials in `.env` bestand

---

## 📊 Voor BI Analisten - Apache Superset

### Wat is Superset?

Apache Superset is een **BI platform** voor:
- Data exploreren en visualiseren
- Interactieve dashboards maken
- Charts en grafieken ontwerpen
- Rapporten delen met collega's

### Toegang tot Superset

1. **Open browser** en ga naar: `http://192.168.1.25:8088`
2. **Let op:** Superset gebruikt **GEEN SSO** (voorlopig)
3. Log in met je **Superset credentials** (apart van Keycloak):
   - Username: `admin` (of je eigen username)
   - Password: `admin123` (of je eigen wachtwoord)

⚠️ **Belangrijk:** 
- Bij login problemen: open **Incognito venster** (Ctrl+Shift+N)
- Clear cookies voor `192.168.1.25` als het niet werkt
- Wachtwoord vergeten? → Contact IT beheer (geen email reset beschikbaar)

### Eerste gebruik - Dashboard bekijken

**Stap 1: Home dashboard**
- Na login zie je de **home pagina**
- Recente dashboards staan linksboven
- Voorbeelddashboards (indien aanwezig) rechtsboven

**Stap 2: Dashboard openen**
- Klik op **Dashboards** in top menu
- Browse beschikbare dashboards
- Klik op een dashboard om te openen

**Stap 3: Dashboard gebruiken**
- **Filters toepassen:** Klik op filter widgets bovenaan
- **Inzoomen:** Klik en sleep op een chart
- **Data vernieuwen:** Klik op refresh icoon (↻)
- **Volledig scherm:** Klik op expand icoon

### Database connectie toevoegen

Om data te kunnen visualiseren, moet je eerst een **database koppelen**.

**Stap 1: Database registreren**
1. Klik op **Data** → **Databases** in top menu
2. Klik op **"+ Database"** rechtsboven
3. Kies **PostgreSQL** uit de lijst
4. Vul in:
   ```
   Display Name: Gemeente PostgreSQL
   SQLAlchemy URI: postgresql://gemeente:gemeente123@gemeente_postgres:5432/gemeente
   ```
5. Klik **"Test Connection"** - moet groen worden ✅
6. Klik **"Connect"**

**Stap 2: Dataset toevoegen**
1. Klik op **Data** → **Datasets**
2. Klik op **"+ Dataset"**
3. Selecteer:
   - Database: `Gemeente PostgreSQL`
   - Schema: `public`
   - Table: Kies een tabel (bijv. `topdesk_departments`)
4. Klik **"Add"**

### Je eerste chart maken

**Scenario:** Maak een bar chart van afdelingen uit TOPdesk

**Stap 1: Chart aanmaken**
1. Klik op **Charts** → **"+ Chart"**
2. Selecteer:
   - Dataset: `topdesk_departments`
   - Chart Type: **Bar Chart**
3. Klik **"Create New Chart"**

**Stap 2: Chart configureren**
Aan de linkerkant zie je de **Chart Builder**:

1. **Dimensions (X-as):**
   - Klik op `name` (afdelingsnaam)

2. **Metrics (Y-as):**
   - Klik op **"+ Add metric"**
   - Kies `COUNT(*)`
   - Label: "Aantal medewerkers" (optioneel)

3. **Filters (optioneel):**
   - Klik **"+ Add filter"**
   - Kolom: `archived`
   - Operator: `= (equal to)`
   - Value: `false`
   - → Toont alleen actieve afdelingen

4. **Klik "Update Chart"** onderaan om preview te zien

**Stap 3: Opmaak aanpassen**
Klik op **"Customize"** tab:
- **Chart Title:** "Actieve Afdelingen"
- **Color Scheme:** Kies een kleurenschema
- **Show Labels:** Zet aan voor waardes op bars
- **X-Axis Label:** "Afdeling"
- **Y-Axis Label:** "Aantal"

**Stap 4: Chart opslaan**
1. Klik **"Save"** rechtsboven
2. Vul in:
   - Chart name: `Afdelingen Bar Chart`
   - Add to dashboard: Kies bestaand of maak nieuw
3. Klik **"Save"**

### Dashboard maken

**Stap 1: Nieuw dashboard**
1. Klik op **Dashboards** → **"+ Dashboard"**
2. Vul in:
   - Title: `TOPdesk Overzicht`
   - Owners: Kies jezelf
3. Klik **"Save"**

**Stap 2: Charts toevoegen**
1. Je bent nu in **Edit mode**
2. Klik op **"+ Add chart or filter"** (blauwe knop)
3. Selecteer je eerder gemaakte chart
4. **Sleep** de chart naar de gewenste positie
5. **Resize** door te slepen aan de hoeken

**Stap 3: Filters toevoegen**
1. Klik op **"+ Add chart or filter"** → **"Add filter"**
2. Configureer:
   - Filter name: `Afdeling selecteren`
   - Dataset: `topdesk_departments`
   - Column: `name`
   - Filter Type: `Select Filter`
3. Sleep de filter naar bovenkant dashboard
4. Klik **"Save"**

**Stap 4: Dashboard publiceren**
1. Klik **"Save"** rechtsboven
2. Dashboard is nu beschikbaar voor anderen met toegang
3. Klik **"Exit Edit Mode"** om eindresultaat te zien

### SQL Lab - Custom queries

Voor **ad-hoc analyses** zonder chart:

**Stap 1: SQL Lab openen**
1. Klik op **SQL Lab** → **SQL Editor** in top menu

**Stap 2: Query schrijven**
```sql
-- Voorbeeld: Tel aantal records per afdeling
SELECT 
    name AS afdeling,
    COUNT(*) AS aantal_records,
    COUNT(CASE WHEN archived = true THEN 1 END) AS gearchiveerd
FROM topdesk_departments
GROUP BY name
ORDER BY aantal_records DESC
LIMIT 10;
```

**Stap 3: Query uitvoeren**
1. Selecteer **Database** en **Schema** bovenaan
2. Klik **"Run"** (▶️ icoon)
3. Resultaten verschijnen onderaan
4. Klik **"Explore"** om direct een chart te maken van resultaat

**Stap 4: Query opslaan**
1. Klik **"Save"** → **"Save Query"**
2. Geef naam: `Top 10 Afdelingen`
3. Query is nu beschikbaar onder **"Saved Queries"** tab

### Best practices Superset

✅ **Wel doen:**
- Geef duidelijke namen aan charts/dashboards
- Gebruik filters voor interactiviteit
- Test queries eerst in SQL Lab
- Maak dashboards niet te druk (max 6-8 charts)
- Gebruik caching voor betere performance

❌ **Niet doen:**
- Te complexe queries (vertraagt dashboard)
- Te veel data tegelijk laden (gebruik LIMIT)
- Wachtwoorden in queries hardcoden
- Dashboards delen zonder context/uitleg

### Troubleshooting Superset

**Kan niet inloggen:**
- Probeer **Incognito mode** (Ctrl+Shift+N)
- Clear browser cache en cookies
- Check username/password (geen spaties, exact)
- Contact IT beheer voor wachtwoord reset

**Database connectie werkt niet:**
- Test de connectie: Data → Databases → Test
- Check SQLAlchemy URI syntax
- Gebruik `gemeente_postgres` als hostname (niet IP)
- Check firewall/netwerk toegang

**Chart laadt niet:**
- Check of dataset nog bestaat
- Bekijk error message (klik op "Error" detail)
- Test query in SQL Lab
- Check database permissions

**Dashboard is traag:**
- Voeg caching toe: Edit Dashboard → Advanced → Cache
- Reduceer aantal charts
- Optimaliseer queries (gebruik indexes)
- Gebruik aggregaties i.p.v. raw data

---

## 🗄️ Voor Database Beheerders - pgAdmin

### Wat is pgAdmin?

pgAdmin is een **grafische tool** voor PostgreSQL beheer:
- Databases, schemas, tabellen maken en beheren
- Queries uitvoeren en data bekijken
- Backups maken en herstellen
- Performance monitoren
- Users en rechten beheren

### Toegang tot pgAdmin

1. **Open browser** en ga naar: `http://192.168.1.25:8081`
2. Log in met:
   - Email: `admin@gemeente.nl`
   - Password: `admin123`

⚠️ **Let op:** pgAdmin gebruikt **eigen login** (geen SSO)

### Server verbinding - Eerste keer

Bij eerste gebruik moet je de **PostgreSQL server toevoegen**:

**Stap 1: Nieuwe server registreren**
1. Rechtsklik op **Servers** in linker menu
2. Kies **Register → Server**

**Stap 2: General tab**
- Name: `Gemeente PostgreSQL`
- Server Group: `Servers`
- Comments: `Main PostgreSQL database`

**Stap 3: Connection tab**
- Host: `gemeente_postgres`
- Port: `5432`
- Maintenance database: `postgres`
- Username: `gemeente`
- Password: `gemeente123`
- ✅ Save password: Aanvinken

**Stap 4: SSL tab**
- SSL Mode: `Prefer`

**Stap 5: Advanced tab**
- DB restriction: Laat leeg (toegang tot alle databases)

**Stap 6: Opslaan**
- Klik **Save**
- Server verschijnt nu in linker menu

### Database exploreren

**Stap 1: Database openen**
1. Vouw **Gemeente PostgreSQL** uit in linker menu
2. Vouw **Databases** uit
3. Zie beschikbare databases:
   - `postgres` - Systeem database
   - `gemeente` - Main database
   - `airflow` - Airflow metadata
   - `superset` - Superset metadata
   - `keycloak` - Keycloak data

**Stap 2: Schemas bekijken**
1. Klik op een database (bijv. `gemeente`)
2. Vouw **Schemas** uit → **public** → **Tables**
3. Zie alle tabellen

**Stap 3: Tabel data bekijken**
1. Rechtsklik op een tabel (bijv. `topdesk_departments`)
2. Kies **View/Edit Data** → **All Rows**
3. Data wordt getoond in grid view
4. **Sorteer:** Klik op kolom header
5. **Filter:** Klik op filter icoon in toolbar

### Queries uitvoeren

**Stap 1: Query Tool openen**
1. Rechtsklik op database
2. Kies **Query Tool**
3. Of klik op **Tools** → **Query Tool** in top menu

**Stap 2: Query schrijven**
```sql
-- Voorbeeld: Alle actieve afdelingen
SELECT 
    dept_id,
    name,
    description,
    external_number
FROM topdesk_departments
WHERE archived = false
ORDER BY name;
```

**Stap 3: Query uitvoeren**
- Klik **▶️ (Execute)** of druk `F5`
- Resultaten verschijnen in **Data Output** tab onderaan
- **Messages** tab toont query info (rows affected, execution time)

**Stap 4: Query opslaan**
- Klik **File** → **Save**
- Bewaar als: `actieve_afdelingen.sql`
- Query is nu beschikbaar via **File → Open**

### Database maken

**Stap 1: Nieuwe database aanmaken**
1. Rechtsklik op **Databases**
2. Kies **Create → Database**

**Stap 2: Configuratie**
- Database: `mijn_database`
- Owner: `gemeente`
- Template: `template0`
- Encoding: `UTF8`
- Collation: `nl_NL.UTF-8`
- Character Type: `nl_NL.UTF-8`

**Stap 3: Opslaan**
- Klik **Save**
- Database verschijnt in lijst

### Tabel maken

**Methode 1: Via UI**
1. Navigeer naar database → Schemas → public → Tables
2. Rechtsklik **Tables** → **Create → Table**
3. **General tab:**
   - Name: `medewerkers`
   - Owner: `gemeente`
4. **Columns tab:** Klik **"+"** om kolommen toe te voegen
   - Column 1: `id`, Type: `integer`, NOT NULL, Primary Key
   - Column 2: `naam`, Type: `varchar(100)`, NOT NULL
   - Column 3: `email`, Type: `varchar(255)`
   - Column 4: `afdeling_id`, Type: `integer`
5. **Constraints tab:** Voeg foreign keys toe indien nodig
6. Klik **Save**

**Methode 2: Via SQL (aanbevolen)**
```sql
CREATE TABLE medewerkers (
    id SERIAL PRIMARY KEY,
    naam VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    afdeling_id INTEGER,
    aangenomen_op DATE DEFAULT CURRENT_DATE,
    actief BOOLEAN DEFAULT true,
    FOREIGN KEY (afdeling_id) REFERENCES topdesk_departments(id)
);

-- Index toevoegen voor snellere queries
CREATE INDEX idx_medewerkers_afdeling ON medewerkers(afdeling_id);

-- Commentaar toevoegen
COMMENT ON TABLE medewerkers IS 'Medewerkers van de gemeente';
```

### Backup maken

**Stap 1: Backup tool openen**
1. Rechtsklik op database (bijv. `gemeente`)
2. Kies **Backup...**

**Stap 2: Backup configureren**
- **General tab:**
  - Filename: `/tmp/gemeente_backup_2025-09-30.sql`
  - Format: `Custom` (aanbevolen) of `Plain` (SQL text)
  - Compression ratio: `6`
  - Encoding: `UTF8`

- **Data/Objects tab:**
  - ✅ Blobs: Aanvinken
  - ✅ Pre-data: Aanvinken (schema)
  - ✅ Data: Aanvinken
  - ✅ Post-data: Aanvinken (indexes, constraints)

- **Options tab:**
  - ✅ Use INSERT commands: Voor compatibiliteit
  - ✅ Include DROP DATABASE statement: Als je wilt

**Stap 3: Backup uitvoeren**
- Klik **Backup**
- Wacht tot status "Successfully completed" toont
- Backup bestand is nu opgeslagen

**⚠️ Belangrijk:** 
- Backup bestand staat **in de container** (`/tmp/`)
- Download backup naar je laptop:
  ```bash
  docker cp gemeente_postgres:/tmp/gemeente_backup_2025-09-30.sql ./backups/
  ```
- Of vraag IT beheer om automatische backups in te stellen

### Backup herstellen

**Stap 1: Database aanmaken (indien nodig)**
```sql
CREATE DATABASE gemeente_restored;
```

**Stap 2: Restore tool openen**
1. Rechtsklik op nieuwe database
2. Kies **Restore...**

**Stap 3: Restore configureren**
- **General tab:**
  - Filename: Selecteer backup bestand
  - Format: Moet matchen met backup format
  - Number of jobs: `4` (parallel restore = sneller)

- **Data/Objects tab:**
  - Selecteer wat je wilt herstellen

**Stap 4: Restore uitvoeren**
- Klik **Restore**
- Wacht tot process compleet is
- Refresh database om resultaat te zien

### Users en permissions beheren

**Stap 1: Nieuwe user aanmaken**
```sql
-- User aanmaken
CREATE USER data_analyst WITH PASSWORD 'veilig_wachtwoord';

-- Read-only rechten geven op database
GRANT CONNECT ON DATABASE gemeente TO data_analyst;
GRANT USAGE ON SCHEMA public TO data_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO data_analyst;

-- Automatisch rechten op nieuwe tabellen
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT SELECT ON TABLES TO data_analyst;
```

**Stap 2: User rechten controleren**
```sql
-- Zie alle users
SELECT usename, usesuper, usecreatedb FROM pg_user;

-- Zie rechten van user op database
SELECT 
    grantee, 
    table_schema, 
    table_name, 
    privilege_type
FROM information_schema.table_privileges
WHERE grantee = 'data_analyst';
```

**Stap 3: Rechten intrekken**
```sql
-- Read rechten intrekken
REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM data_analyst;

-- User verwijderen
DROP USER data_analyst;
```

### Performance monitoring

**Actieve queries bekijken:**
```sql
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;
```

**Lange queries identificeren:**
```sql
SELECT 
    pid,
    now() - query_start AS duration,
    query,
    state
FROM pg_stat_activity
WHERE (now() - query_start) > interval '5 minutes'
  AND state != 'idle';
```

**Query killen (indien nodig):**
```sql
-- Graceful stop
SELECT pg_cancel_backend(12345);  -- vervang met PID

-- Force kill
SELECT pg_terminate_backend(12345);
```

**Tabel statistieken:**
```sql
SELECT 
    schemaname,
    tablename,
    n_live_tup AS rows,
    n_dead_tup AS dead_rows,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;
```

**Database grootte:**
```sql
SELECT 
    pg_database.datname,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;
```

### Best practices PostgreSQL

✅ **Wel doen:**
- Maak **reguliere backups** (dagelijks aanbevolen)
- Gebruik **transactions** voor meerdere INSERTs/UPDATEs
- Maak **indexes** op veel-gebruikte kolommen
- Gebruik **EXPLAIN ANALYZE** om queries te optimaliseren
- Documenteer schema wijzigingen
- Test queries eerst op **development data**

❌ **Niet doen:**
- `SELECT *` op grote tabellen (specificeer kolommen)
- Wijzigingen zonder backup
- Wachtwoorden in plain text opslaan
- `DELETE FROM table` zonder WHERE clause
- Production queries op peak hours zonder test

### Troubleshooting pgAdmin

**Kan niet verbinden met server:**
- Check of PostgreSQL container draait: `docker ps | grep postgres`
- Gebruik hostname `gemeente_postgres` (niet IP)
- Check credentials: `gemeente` / `gemeente123`
- Test connectie vanuit container: `docker exec gemeente_postgres psql -U gemeente -c "SELECT 1;"`

**Query hangt:**
- Check actieve queries (zie Performance monitoring)
- Kill query indien nodig met `pg_cancel_backend()`
- Check table locks: `SELECT * FROM pg_locks;`

**Backup mislukt:**
- Check disk space: `df -h`
- Check permissions op backup directory
- Gebruik `Custom` format i.p.v. `Plain` voor grote databases
- Check logs: pgAdmin → Files → Log

**Out of memory errors:**
- Reduceer `work_mem` setting
- Gebruik LIMIT in queries
- Splits grote operations op in chunks
- Check RAM usage: `free -h`

---

## 🛠️ Overige Tools

### Grafana - Monitoring Dashboards

**Toegang:** `http://192.168.1.25:13000`

**Login:** 
- Klik **"Sign in with Keycloak"** (SSO)
- Of gebruik: `admin` / `admin123`

**Gebruik:**
- Bekijk system metrics (CPU, memory, disk)
- Bekijk applicatie metrics
- Stel alerts in voor afwijkingen
- Maak custom dashboards

**Voorbeeld dashboard bekijken:**
1. Klik **Dashboards** (☰ menu links)
2. Browse beschikbare dashboards
3. Klik om dashboard te openen

### MinIO - Object Storage

**Toegang:** `http://192.168.1.25:9001`

**Login:** `minioadmin` / `minioadmin123`

**Gebruik:**
- Upload grote bestanden (CSV, Excel, PDFs)
- Maak buckets voor data organisatie
- Deel bestanden met collega's (pre-signed URLs)
- Integreer met Airflow voor data pipelines

**Bucket maken:**
1. Klik **Buckets** in menu
2. Klik **"Create Bucket"**
3. Naam: `mijn-data-bucket`
4. Klik **Create**

**Bestand uploaden:**
1. Open bucket
2. Klik **"Upload"** → **"Upload File"**
3. Selecteer bestand van je laptop
4. Bestand verschijnt in bucket

### Neo4j - Graph Database

**Toegang:** `http://192.168.1.25:7474`

**Login:** `neo4j` / `datahub123`

**Gebruik:**
- Bouw en query graph databases
- Visualiseer relaties tussen data
- Gebruik Cypher query language

**Voorbeeld query:**
```cypher
// Maak nodes en relaties
CREATE (afdeling:Department {name: 'IT'})
CREATE (medewerker:Person {name: 'Jan Jansen'})
CREATE (medewerker)-[:WORKS_IN]->(afdeling)

// Query
MATCH (p:Person)-[:WORKS_IN]->(d:Department)
RETURN p.name, d.name
```

### Spark - Big Data Processing

**Toegang:** `http://192.168.1.25:28080`

**Gebruik:**
- Bekijk actieve Spark jobs
- Monitor cluster resources
- Bekijk job history en logs

⚠️ **Let op:** Spark is voor **advanced users**. Contact IT beheer voor setup.

---

## 🔧 Problemen oplossen

### Algemene troubleshooting

**Kan geen verbinding maken met service:**
1. Check of je laptop op het netwerk is aangesloten
2. Ping de server: Open CMD → `ping 192.168.1.25`
3. Check of service draait (vraag IT beheer)
4. Probeer andere browser
5. Clear browser cache en cookies

**Login werkt niet:**
1. **Check credentials:** Let op hoofdletters, spaties
2. **Probeer Incognito mode:** Ctrl+Shift+N (Chrome/Edge)
3. **SSO services:** Check of Keycloak bereikbaar is: `http://192.168.1.25:8085`
4. **Wachtwoord vergeten:** Contact IT beheer (geen email reset beschikbaar)

**Service is traag of reageert niet:**
1. Check je internet/netwerk snelheid
2. Probeer op ander tijdstip (mogelijk hoge load)
3. Rapporteer aan IT beheer met:
   - Welke service (URL)
   - Wat je probeerde te doen
   - Exacte foutmelding (screenshot)
   - Tijdstip

**Data is niet up-to-date:**
1. **Airflow:** Check of pipeline succesvol is uitgevoerd
2. **Superset:** Klik refresh icoon (↻) op dashboard
3. **pgAdmin:** Rechtsklik tabel → **Refresh**
4. Check met IT beheer of pipeline schedule correct is

### Browser compatibiliteit

**Aanbevolen browsers:**
- ✅ Google Chrome (laatste versie)
- ✅ Microsoft Edge (laatste versie)
- ✅ Mozilla Firefox (laatste versie)

**Niet ondersteund:**
- ❌ Internet Explorer
- ❌ Oude browser versies (>1 jaar oud)

**Browser cache legen:**
- Chrome/Edge: Ctrl+Shift+Delete → Selecteer "Cached images and files" → Clear
- Firefox: Ctrl+Shift+Delete → Selecteer "Cache" → Clear

### Veelvoorkomende foutmeldingen

**"Connection refused"**
- Service is niet bereikbaar
- Check of service draait (IT beheer)
- Check netwerk verbinding

**"Authentication failed"**
- Verkeerde username/password
- Check credentials (exact overnemen, geen spaties)
- Wachtwoord verlopen? Contact IT beheer

**"403 Forbidden"**
- Je hebt geen toegang tot deze resource
- Vraag IT beheer om juiste rechten

**"500 Internal Server Error"**
- Server error (niet jouw fout)
- Rapporteer aan IT beheer met tijdstip en URL

**"Session expired"**
- Je sessie is verlopen (inactiviteit)
- Log opnieuw in

### Wie contact opnemen

**Voor technische problemen:**
- Email: [IT beheer email adres]
- Telefoon: [IT beheer telefoon]
- Teams: [IT beheer Teams channel]

**Vermeld altijd:**
1. Je naam en afdeling
2. Welke service (URL)
3. Wat ging er mis (exacte foutmelding)
4. Screenshot indien mogelijk
5. Tijdstip van probleem
6. Wat je probeerde te doen

---

## ❓ Veelgestelde vragen

### Account & Toegang

**Q: Kan ik zelf een account aanmaken?**  
A: Nee, accounts worden door IT beheer aangemaakt. Stuur een email met je gegevens en gewenste rol.

**Q: Hoe krijg ik toegang tot een extra service?**  
A: Stuur een email naar IT beheer met welke service je nodig hebt en waarom.

**Q: Kan ik mijn wachtwoord zelf resetten?**  
A: Nee, email is nog niet geconfigureerd. Contact IT beheer voor wachtwoord reset.

**Q: Hoelang is mijn sessie geldig?**  
A: SSO sessies: 30 minuten inactiviteit, max 10 uur. Daarna moet je opnieuw inloggen.

### Data & Pipelines

**Q: Waar worden mijn data opgeslagen?**  
A: In PostgreSQL database of MinIO object storage, afhankelijk van data type.

**Q: Hoe vaak worden pipelines uitgevoerd?**  
A: Afhankelijk van schedule. Check DAG configuratie in Airflow.

**Q: Kan ik data direct wijzigen in de database?**  
A: Alleen als je Database Admin rechten hebt. Anders via IT beheer.

**Q: Hoe lang worden data bewaard?**  
A: Afhankelijk van data retention policy. Check met IT beheer.

### Dashboards & Rapporten

**Q: Kan ik dashboards delen met collega's?**  
A: Ja, in Superset: Dashboard → Share → Copy link. Collega moet wel toegang hebben.

**Q: Kan ik dashboards exporteren naar PDF?**  
A: Beperkt mogelijk. Gebruik browser Print → Save as PDF functie.

**Q: Waarom zie ik niet alle data?**  
A: Je rol bepaalt welke data je ziet. Contact IT beheer voor meer toegang.

**Q: Kan ik dashboard automatisch emailen?**  
A: Nog niet geconfigureerd. Feature komt later.

### Performance

**Q: Waarom is mijn query traag?**  
A: Mogelijk te veel data, geen indexes, of hoge server load. Optimaliseer query of vraag IT beheer.

**Q: Kan ik meer resources krijgen?**  
A: Contact IT beheer. Ze kunnen resource limits aanpassen indien nodig.

**Q: Wat is de upload limiet voor bestanden?**  
A: MinIO: Tot 5TB per bestand (theoretisch). Praktisch: check met IT beheer.

### Beveiliging

**Q: Wie kan mijn dashboards/queries zien?**  
A: Alleen gebruikers met toegang tot dezelfde database/datasets.

**Q: Worden mijn activiteiten gelogd?**  
A: Ja, alle queries en actions worden gelogd voor audit doeleinden.

**Q: Kan ik data downloaden naar mijn laptop?**  
A: Ja, via query resultaten export. Let op data classificatie regels.

**Q: Is het platform GDPR compliant?**  
A: Check met IT beheer voor specifieke compliance vereisten.

---

## 📞 Support & Contact

**IT Beheer:**
- Email: [email]
- Telefoon: [telefoon]
- Teams: [teams channel]

**Openingstijden:**
- Ma-Vr: 08:00 - 17:00
- Weekend: Alleen voor kritieke issues

**Documentatie:**
- Deze handleiding: `GEBRUIKERSHANDLEIDING.md`
- Beheerdersdocumentatie: `BEHEERHANDLEIDING.md`
- Platform dashboard: `http://192.168.1.25:8888`

**Platform versie:** 2.0 (Development)

---

*Laatste update: September 2025*  
*Voor vragen of suggesties voor deze handleiding: contact IT beheer*#   o p e n _ s o u r c e _ d a t a _ p l a t f o r m  
 