# Olist E-Commerce — Business Intelligence & ML Platform

> End-to-end data engineering, machine learning, and analytics platform built on the Brazilian Olist e-commerce dataset. Covers a full medallion data warehouse on Azure SQL, NLP sentiment classification, K-Means customer segmentation, a FastAPI inference service, and an interactive web dashboard — all containerized and deployed to the cloud.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Data Warehouse — Medallion Architecture](#data-warehouse--medallion-architecture)
- [Machine Learning Pipelines](#machine-learning-pipelines)
- [REST API](#rest-api)
- [Web Application](#web-application)
- [CI/CD Pipeline](#cicd-pipeline)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Environment Variables](#environment-variables)
- [Running the ML Pipeline](#running-the-ml-pipeline)
- [Team](#team)

---

## Project Overview

This project transforms the public [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (~100k orders, 9 relational tables, Sep 2016 – Sep 2018) into a production-grade analytics and prediction platform. Every layer — from raw CSV ingestion to a live web dashboard — is built end-to-end by the team.

**Key deliverables:**

| Layer | What was built |
|---|---|
| Data Warehouse | 3-tier medallion warehouse (Bronze / Silver / Gold) on Azure SQL with full ETL stored procedures and an audit log |
| ML — NLP | Portuguese review sentiment classifier (Logistic Regression + TF-IDF, Optuna-tuned, MLflow-tracked) |
| ML — Clustering | K-Means customer segmentation (5 clusters, PCA-reduced, visualized in 3D) |
| API | FastAPI service exposing dashboard KPIs and real-time sentiment inference |
| Web App | Single-page analytics dashboard with Plotly charts, a custom cursor system, and an embedded AI chat assistant |
| Deployment | Docker image on Docker Hub, GitHub Actions CI/CD, Azure cloud hosting |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         DATA SOURCES                            │
│  Kaggle CSVs  ──►  Azure Blob Storage (CRM / ERP1 / ERP2)       │
└────────────────────────────┬────────────────────────────────────┘
                             │ BULK INSERT via External Data Source
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    AZURE SQL  ─  MEDALLION DWH                  │
│                                                                 │
│  Bronze  (raw landing)  ──►  Silver  (cleaned/typed)            │
│           Silver  ──►  Gold  (star schema + KPI views)          │
│                                                                 │
│  Audit.ETL_Log tracks every batch, row count, and duration      │
└────────────────────────────┬────────────────────────────────────┘
                             │ SQLAlchemy
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                       ML PIPELINES                              │
│                                                                 │
│  Sentiment Analysis                                             │
│    Extract ► Preprocess ► Tune (Optuna) ► Train ► Evaluate      │
│    Model: Logistic Regression + TF-IDF   Tracked: MLflow        │
│                                                                 │
│  Customer Segmentation  (notebook / offline)                    │
│    RFM features ► K-Means (k=5) ► PCA ► Cluster labelling       │
└────────────────────────────┬────────────────────────────────────┘
                             │ joblib .pkl
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                        FASTAPI SERVICE                          │
│                                                                 │
│  /health                  /api/predict/sentiment                │
│  /api/dashboard/overview  /api/sales/*                          │
│  /api/marketing/*         /api/customers/*                      │
│                                                                 │
│  Serves static frontend  +  ML inference  +  SQL KPIs           │
└────────────────────────────┬────────────────────────────────────┘
                             │ Docker  /  GitHub Actions
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    WEB DASHBOARD  (SPA)                         │
│                                                                 │
│  Plotly charts  ·  3D cluster scatter  ·  Geospatial map        │
│  Prediction engine form  ·  AI chat assistant (Anthropic)       │
│  Dark / Light theme  ·  Animated Brazil particle canvas         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

**Data Engineering**
- Azure SQL Database — primary warehouse engine
- Azure Blob Storage — raw CSV staging with Shared Access Signature
- T-SQL stored procedures — full Bronze / Silver / Gold ETL with audit logging

**Machine Learning**
- scikit-learn — `Pipeline`, `LogisticRegression`, `TfidfVectorizer`, `KMeans`
- Optuna — Bayesian hyperparameter tuning (TPE sampler)
- MLflow — experiment tracking, metric logging, artifact storage
- imbalanced-learn — class imbalance handling
- pandas / numpy — data manipulation
- joblib — model serialization

**API & Serving**
- FastAPI — async REST API framework
- Pydantic v2 — request / response validation
- SQLAlchemy 2.0 — async-compatible DB engine
- Uvicorn — ASGI server
- python-dotenv — secrets management
- langdetect — Portuguese language validation at inference time

**Frontend**
- Vanilla HTML / CSS / JS (no build step)
- Plotly.js — interactive charts (bar, funnel, scatter3d, scattermapbox, heatmap)
- Custom Canvas API — animated Brazil particle map on hero section
- Custom cursor system — spring-physics aura, SVG trails, click particles

**Infrastructure**
- Docker — single-image containerization
- Docker Hub — image registry (`nitoboritto/olist-ecommerce`)
- GitHub Actions — CI/CD: lint → build → push → smoke-test
- Azure — cloud deployment target

---

## Data Warehouse — Medallion Architecture

### Bronze Layer — Raw Landing Zone

Raw CSVs are bulk-loaded from Azure Blob Storage into typed `NVARCHAR` staging tables. No transformations are applied; every source row lands exactly as-is.

**Tables:** `Crm_closed_deals`, `Crm_customers_dataset`, `Crm_marketing_qualified_leads`, `Crm_order_reviews`, `Erp_order_items`, `Erp_order_payments`, `Erp_products`, `Erp_sellers`, `Erp_geolocation`, `Erp_orders`

The `Bronze.Load_Bronze` stored procedure runs all ten loads in sequence, logs each table to `Audit.ETL_Log`, and raises the error back to the caller on any failure.

### Silver Layer — Cleansed & Typed

Silver performs column-level transformations: type casting, date parsing, mojibake repair on Portuguese review text (multi-step `REPLACE` chain fixing triple-encoded UTF-8 → NVARCHAR), deduplication via `ROW_NUMBER()`, geolocation averaging per zip code, and city name standardization for sellers.

Notable transformations:
- Review text: 5-stage cross-apply pipeline fixing `├â┬ú` → `ã` style encoding artifacts, punctuation removal, whitespace normalization
- Geolocation: zip-level `AVG(lat/lng)` with accent stripping and state-suffix removal from city names
- Order status: `unavailable` mapped to `out of stock` for business readability

### Gold Layer — Star Schema + KPI Views

**Dimensions:** `Dim_Date` (2015–2020, generated CTE), `Dim_Products`, `Dim_Customers` (deduped by `customer_unique_id` + geo-joined), `Dim_Sellers` (enriched with marketing deal data)

**Facts:** `Fact_Orders` (payment aggregation, late-delivery flag, review join), `Fact_Order_Items` (filtered by FK existence), `Fact_Marketing_Funnel` (MQL → seller conversion with `days_to_close`)

**KPI Views deployed via `Gold.Deploy_Dashboard_System`:**

| View | Covers |
|---|---|
| `vw_overview_dashboard_kpis` | GMV, YoY growth, AOV, late delivery rate, NPS proxy, cancellation rate |
| `vw_sales_dashboard_kpis` | Top category, fastest-growing category (YoY), freight burden, lowest satisfaction, top seller state, Pareto concentration |
| `vw_marketing_dashboard_kpis` | MQL conversion rate, best channel, fastest channel, marketing-sourced revenue, avg sales cycle |
| `vw_customer_dashboard_kpis` | Repeat rate, avg customer value, largest market state, worst delivery state, top-quartile contribution |

All views are year-number scoped so the API can filter to the latest available year.

### Audit Log

Every stored procedure writes one row per table to `Audit.ETL_Log`, capturing batch UUID, layer, table name, procedure name, start/end timestamps, duration in seconds, source row count, rows inserted, and status (`SUCCESS` / `FAILED`). Error rows include `ERROR_MESSAGE()`, `ERROR_NUMBER()`, and `ERROR_STATE()`.

---

## Machine Learning Pipelines

### Sentiment Analysis Pipeline

Binary classification of Portuguese e-commerce reviews into **Positive** (score ≥ 4) and **Negative** (score ≤ 3).

**Pipeline stages** (orchestrated by `scripts/run_pipeline.py`):

```
Extract  →  Preprocess  →  Encode Labels  →  Train/Test Split
    →  Optuna Tuning  →  Train  →  Evaluate  →  Save + Log to MLflow
```

**Feature engineering** (`src/features/engineering.py`):
```python
TfidfVectorizer(
    ngram_range=(1, 2),   # unigrams + bigrams
    min_df=7,             # prune rare tokens
    max_df=0.8,           # prune overly common tokens
    max_features=2000,
)
```

**Hyperparameter search space** (Optuna, TPE sampler, 50 trials, 5-fold stratified CV, optimizing macro-F1):

| Parameter | Range |
|---|---|
| `classifier__C` | log-uniform [0.01, 10.0] |
| `classifier__max_iter` | integer [1000, 3000] |
| `classifier__class_weight` | `balanced` or `None` |

**Outputs saved:**
- `src/serving/models/sentiment_model/sentiment_pipeline.pkl` — full sklearn Pipeline
- `src/serving/models/sentiment_model/label_mapping.json` — `{0: "Negative", 1: "Positive"}`
- MLflow run: parameters, metrics, confusion matrix PNG, classification report TXT, logged model artifact

**Inference** (`src/serving/inference.py`): models loaded once at FastAPI startup into module-level globals; predictions offloaded to a `ThreadPoolExecutor` (4 workers) to avoid blocking the async event loop.

### Customer Segmentation (K-Means)

Five customer segments derived from RFM-extended features extracted from the Gold layer:

| Feature | Source |
|---|---|
| Monetary | `SUM(price + freight_value)` from `Fact_Order_Items` |
| Recency | Days since last order relative to dataset max date |
| Frequency | `COUNT(DISTINCT order_id)` |
| Avg Delivery Time | `AVG(delivery_days_actual)` from `Fact_Orders` |
| Category Diversity | `COUNT(DISTINCT category_name_en)` |

PCA reduces to 3 components for visualization. The 3D scatter and characteristics heatmap are rendered client-side via Plotly using pre-computed centroid data served from the FastAPI backend.

**Segment labels:**

| Cluster | Persona | Key Signal |
|---|---|---|
| 0 | Champions | High spend, recent, satisfied |
| 1 | Frustrated Critics | Low spend, late deliveries, negative reviews |
| 2 | Dormant Advocates | Historical happy buyers, now inactive |
| 3 | Silent Disengaged | Average across metrics, rarely reviews |
| 4 | Promising Newcomers | Recent, fast delivery, high satisfaction |

---

## REST API

Built with **FastAPI**, served by **Uvicorn** on port `8000`. The frontend static files are mounted at `/` so a single Docker container serves both the API and the web app.

### Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Liveness check, returns model load status |
| GET | `/api/dashboard/overview` | Overview KPI cards from Gold view |
| GET | `/api/sales/kpis` | Sales KPI cards |
| GET | `/api/sales/revenue-by-category` | Revenue breakdown sorted by category |
| GET | `/api/sales/time-series` | Daily revenue time series |
| GET | `/api/marketing/kpis` | Marketing funnel KPI cards |
| GET | `/api/marketing/funnel` | MQL → Acquired funnel stages |
| GET | `/api/marketing/top-states` | Top 5 states by lead volume |
| GET | `/api/customers/kpis` | Customer KPI cards |
| GET | `/api/customers/distribution-map` | Lat/lng + review score per customer (state-aggregated on client) |
| GET | `/api/customers/review-distribution` | On-time vs late delivery review counts |
| POST | `/api/predict/sentiment` | Sentiment inference for a Portuguese review |

### Sentiment Prediction

**Request:**
```json
POST /api/predict/sentiment
{
  "text": "Produto excelente com entrega rápida"
}
```
Validated by Pydantic: minimum 10 characters, `langdetect` language gate (must be `pt`).

**Response:**
```json
{
  "sentiment": "Positive",
  "confidence": 0.9341,
  "delivery_context": "Sentiment analysis from review text",
  "category": "General"
}
```

All database endpoints include a **fallback sample payload** so the frontend renders meaningful data even when the Azure SQL connection is unavailable (e.g., in local dev without credentials).

---

## Web Application

A zero-framework single-page application served as static files from the FastAPI container.

### Sections

| Section | What it does |
|---|---|
| **Hero** | Animated Canvas — Brazilian silhouette assembled from particle physics launched from the "Olist" title; tropical leaf parallax; orbit dot rings |
| **Team** | Mouse-tracking team member highlight with roster cards |
| **Analytics** | Four tabbed dashboards (Overview, Sales, Marketing, Customers) with live Plotly charts and KPI cards pulled from the API |
| **Segmentation** | Interactive 3D K-Means scatter plot + cluster characteristics heatmap |
| **Features** | Platform capability cards |
| **Pipeline** | Visual data science workflow tracker |
| **AI Engine** | Review text input → live `/api/predict/sentiment` call → confidence score and result display |

### Notable Frontend Engineering

**Custom cursor system** (`cursor.js`): spring-physics aura ring (critically-damped, stiffness=0.12, damping=0.82), SVG ellipse trail with velocity-stretch, click-burst particle system (10 particles per click), hover detection on interactive elements scaling the aura to 2.4×. All driven by a single `requestAnimationFrame` loop.

**Hero canvas** (`hero-canvas.js`): Brazil SVG path sampled into ~60 outline targets and ~140 fill targets via offscreen canvas pixel scan. Particles burst from the title element and spring-settle into map position. Mouse proximity within 15% viewport radius scatters nearby particles.

**Theme system**: CSS variable swap between light/dark via `data-theme` attribute on `<html>`. `MutationObserver` detects changes and calls `Plotly.relayout` on all active charts to sync font colors. Theme persisted to `localStorage`.

**AI Chat** (`farghaly.js`): Self-contained chat widget (no npm, no build step). Maintains conversation history, calls the Anthropic Messages API directly from the browser, renders markdown with code fences, supports quick-prompt chips, clear, and TXT export.

---

## CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/ci.yml`) triggers on push to `main`/`develop`, version tags (`v*.*.*`), and pull requests to `main`.

```
┌─────────┐    ┌──────────────────┐    ┌──────────────┐
│  test   │───►│ build-and-push   │───►│ smoke-test   │
│         │    │                  │    │              │
│ Python  │    │ QEMU multi-arch  │    │ docker pull  │
│ 3.11    │    │ Docker Buildx    │    │ docker run   │
│ pip     │    │ Login Docker Hub │    │ curl /health │
│ install │    │ Extract metadata │    │              │
│ black   │    │ Build linux/amd64│    │ Assert 200   │
│ pytest  │    │ Push image       │    │              │
└─────────┘    │ Registry cache   │    └──────────────┘
               └──────────────────┘
```

**Image tags generated per run:**
- `sha-<short-sha>` — always pushed, used by smoke-test
- `develop` / `main` — branch name tags
- `latest` — only on push to `main`
- `v1.2.3` — semver tags on release

**Registry cache:** `type=registry,ref=nitoboritto/olist-ecommerce:buildcache,mode=max` — layer cache stored on Docker Hub, dramatically reducing build times on subsequent pushes.

**Concurrency:** `cancel-in-progress: true` per `workflow-ref` group, preventing queue pile-ups on rapid pushes.

---

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── ci.yml                   # GitHub Actions CI/CD
│
├── scripts/
│   ├── run_pipeline.py              # ML pipeline orchestrator (CLI)
│   ├── create_dashboard_views.sql   # Simple KPI view deployment
│   └── create_marketing_kpi_view.sql
│
├── src/
│   ├── app/                         # Web application (static SPA)
│   │   ├── index.html
│   │   ├── css/
│   │   │   ├── variables.css        # Design tokens (light/dark)
│   │   │   ├── base.css
│   │   │   ├── components.css       # Buttons, cards, bento grid
│   │   │   ├── layout.css           # Navbar, footer, tables
│   │   │   ├── sections.css         # Section-specific layouts
│   │   │   ├── animations.css       # Keyframes + cursor CSS
│   │   │   ├── canvas.enhancements.css
│   │   │   └── farghaly.css         # AI chat widget styles
│   │   └── js/
│   │       ├── charts.js            # Plotly chart renderers + API fetch
│   │       ├── cursor.js            # Spring-physics cursor system
│   │       ├── hero-canvas.js       # Brazil particle canvas
│   │       ├── segmentation.js      # 3D cluster + heatmap
│   │       ├── prediction-engine.js # Sentiment form handler
│   │       ├── farghaly.js          # AI chat widget
│   │       ├── team.js              # Team section hover logic
│   │       ├── scroll.js            # Scroll reveal + side dots
│   │       ├── theme.js             # Dark/light toggle
│   │       └── counter.js           # Animated KPI counters
│   │
│   ├── main.py                      # FastAPI application entry point
│   ├── schema.py                    # Pydantic request/response models
│   │
│   ├── data/
│   │   ├── extract.py               # Azure SQL / CSV extraction
│   │   └── preprocess.py            # Text cleaning, label encoding
│   │
│   ├── features/
│   │   └── engineering.py           # TF-IDF vectorizer builder
│   │
│   ├── models/
│   │   ├── tune.py                  # Optuna hyperparameter search
│   │   ├── train.py                 # sklearn Pipeline training
│   │   └── evaluate.py             # Metrics, confusion matrix, MLflow logging
│   │
│   ├── serving/
│   │   ├── inference.py             # Model loading + async prediction
│   │   └── models/
│   │       └── sentiment_model/
│   │           ├── sentiment_pipeline.pkl
│   │           └── label_mapping.json
│   │
│   └── warehouse/
│       ├── engine.py                # SQLAlchemy engine with retry logic
│       └── sql/
│           ├── Bronze/              # DDL + bulk load procedures
│           ├── Silver/              # DDL + transformation procedures
│           ├── Gold/                # DDL + star schema load procedure
│           └── KPI/                 # Dashboard view deployment procedure
│
├── tools/
│   └── inspect_model.py             # Quick model introspection utility
│
├── requirements.txt
└── README.md
```

---

## Getting Started

### Prerequisites

- Python 3.11
- Docker (for containerized run)
- Azure SQL database with the warehouse already deployed (or use the fallback sample data)

### Local Development

```bash
# 1. Clone the repository
git clone https://github.com/NitoBoritto/olist-ecommerce.git
cd olist-ecommerce

# 2. Create and activate virtual environment
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Copy environment file and fill in your Azure SQL connection string
cp .env.example .env

# 5. Run the API server
uvicorn src.app.main:app --reload --host 0.0.0.0 --port 8000

# 6. Open the dashboard
# Navigate to http://localhost:8000
```

### Docker

```bash
# Pull the pre-built image
docker pull nitoboritto/olist-ecommerce:latest

# Run with your Azure SQL connection string
docker run -d \
  -p 8000:8000 \
  -e AZURE_SQL_STRING="your_connection_string_here" \
  --name olist \
  nitoboritto/olist-ecommerce:latest

# Health check
curl http://localhost:8000/health
```

### Deploy the Data Warehouse

Run the SQL scripts in this order against your Azure SQL database:

```
1. src/warehouse/sql/Bronze/DataBase Creation Azure.sql    # Schemas + audit log
2. src/warehouse/sql/Bronze/Azure Blob setup.sql            # External data source
3. src/warehouse/sql/Bronze/Bronze DDL.sql                  # Bronze tables
4. src/warehouse/sql/Silver/Silver DDL.sql                  # Silver tables
5. src/warehouse/sql/Gold/Gold DDL.sql                      # Gold star schema
6. src/warehouse/sql/Bronze/Load Bronze Azure.sql            # Bronze procedure
7. src/warehouse/sql/Silver/Load Siver.sql                  # Silver procedure
8. src/warehouse/sql/Gold/Load Gold.sql                     # Gold procedure
9. src/warehouse/sql/KPI/Deploy_Dashboard_System.sql        # KPI views

-- Execute ETL
EXEC Bronze.Load_Bronze;
EXEC Silver.Load_Silver;
EXEC Gold.Load_Gold;
EXEC Gold.Deploy_Dashboard_System;
```

---

## Environment Variables

| Variable | Description | Required |
|---|---|---|
| `AZURE_SQL_STRING` | Full SQLAlchemy connection string for Azure SQL | Yes (API falls back to sample data if missing) |

Connection string format:
```
mssql+pyodbc://username:password@server.database.windows.net/database?driver=ODBC+Driver+18+for+SQL+Server
```

---

## Running the ML Pipeline

```bash
# Run sentiment pipeline against Azure SQL (default: 50 Optuna trials)
python scripts/run_pipeline.py --pipeline sentiment

# Run against a local CSV instead of Azure SQL (dev/offline mode)
python scripts/run_pipeline.py --pipeline sentiment --input data/reviews_sample.csv

# Override Optuna trial count and MLflow experiment name
python scripts/run_pipeline.py \
  --pipeline sentiment \
  --n_trials 100 \
  --experiment "Olist-Sentiment-v2"
```

After the pipeline completes, the trained model is saved to `src/serving/models/sentiment_model/` and the FastAPI server will load it automatically on next startup.

MLflow UI (if tracking server configured):
```bash
mlflow ui --port 5000
```

---

## Team

| # | Name | Role |
|---|---|---|
| 01 | **Yasser Ahmed Mohamed** | Team Leader · Data Scientist · UIX Engineer · Dashboard Design |
| 02 | **Abdallah Ali Abdelgawad** | Data Engineer · Data Warehouse Engineer · ETL Developer |
| 03 | **Mohanad Ibrahim Elsayed** | Data Analyst · BI Developer · Network Analyst |
| 04 | **Ahmed Walid Ibrahim** | ML Engineer · NLP Engineer · AI Developer · Cloud |
| 05 | **Mariam Tarek Salama** | Data Analyst · EDA Specialist · Storytelling |
| 06 | **Marwa Tarek Gaber** | Data Analyst · EDA Specialist · Storytelling |
| 07 | **Mohamed Hassan** | Full Stack Developer · API Configuration · Website Design |

---

[Try it out for yourself](https://olist-epeea5ehhpg5fybm.uaenorth-01.azurewebsites.net)
