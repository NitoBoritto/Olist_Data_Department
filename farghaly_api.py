"""
farghaly_api.py — 3m Farghaly 🤖 Backend Blueprint
====================================================
FastAPI skeleton for the Olist AI assistant.

Stack:
  - FastAPI  (HTTP layer)
  - SQLAlchemy / psycopg2  (Olist PostgreSQL / SQLite)
  - Anthropic Python SDK   (LLM brain)
  - Pydantic v2            (request/response validation)

Run:
  pip install fastapi uvicorn anthropic sqlalchemy psycopg2-binary python-dotenv
  uvicorn farghaly_api:app --reload --port 8000

Env vars (.env):
  ANTHROPIC_API_KEY=sk-ant-...
  DATABASE_URL=postgresql://user:pass@localhost:5432/olist
  ALLOWED_ORIGIN=http://localhost:3000   # your frontend
"""

import os
import re
import json
import logging
from datetime import datetime
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

import anthropic

# ── Optional: SQLAlchemy for direct DB queries ───────────────────────────────
# from sqlalchemy import create_engine, text
# engine = create_engine(os.getenv("DATABASE_URL", "sqlite:///olist.db"))

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(levelname)s  %(message)s")
log = logging.getLogger("farghaly")

# ─── APP INIT ────────────────────────────────────────────────────────────────
app = FastAPI(
    title="3m Farghaly API",
    description="Elite AI assistant for the Olist Data Department platform",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        os.getenv("ALLOWED_ORIGIN", "http://localhost:3000"),
        "http://127.0.0.1:5500",   # VS Code Live Server
        "http://localhost:8080",
    ],
    allow_methods=["POST", "GET", "OPTIONS"],
    allow_headers=["*"],
)

# ─── ANTHROPIC CLIENT ────────────────────────────────────────────────────────
claude = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

# ─── FARGHALY SYSTEM PROMPT ──────────────────────────────────────────────────
SYSTEM_PROMPT = """
You are **3m Farghaly 🤖**, the elite AI data assistant for the Olist E-commerce
Data Department platform. You were built by the Olist Data Team and you're proud of it.

━━━ PERSONALITY ━━━
• Professional, impressive, and sharp — but with genuine wit and warmth.
• You use relevant emojis naturally (not excessively). Think: colleague who's also funny.
• You speak like a senior data analyst who actually enjoys their job.
• You are NEVER sycophantic. No "Great question!" — just get to the answer.
• When you don't know something, say so clearly and suggest what the user should check.

━━━ KNOWLEDGE DOMAINS ━━━

1. OLIST COMPANY KNOWLEDGE
   Olist is a Brazilian e-commerce SaaS platform founded in 2015 by Tiago Dalvi,
   headquartered in Curitiba, Paraná. It connects small and medium businesses (SMBs)
   to major Brazilian marketplaces (Americanas, Shopee, Mercado Livre, etc.) under
   a single, unified storefront. Olist handles logistics via the Correios network
   and charges sellers a monthly subscription plus a commission.

   Key milestones:
   - 2015: Founded; focused on democratising e-commerce for SMBs in Brazil.
   - 2018: ~100k orders/month; released the public dataset used for data science.
   - 2021: Acquired Pax (now Vnda) for D2C capabilities; raised Series D funding.
   - 2022: Expanded into fintech with Olist Pay; headcount ~1,000.
   - Dataset covers Sep 2016 – Sep 2018; ~100k orders; 9 relational tables.

   Dataset tables:
   olist_orders, olist_order_items, olist_order_payments,
   olist_order_reviews, olist_customers, olist_sellers,
   olist_products, olist_product_category_name_translation,
   olist_geolocation

2. DATA ANALYTICS & INSIGHTS
   When answering data questions:
   a. If a query can be answered by SQL → write clean, well-commented SQL.
   b. If the result requires interpretation → explain the business implication.
   c. Always state WHICH table(s) and joins are needed.
   d. Format numbers with commas; use R$ for Brazilian Real.
   e. Mention caveats (e.g. "this excludes cancelled orders").

━━━ SQL STYLE GUIDE ━━━
• Use CTEs (WITH …) for readability.
• Always alias tables: olist_orders o, olist_order_items oi, etc.
• Filter out cancelled/unavailable orders unless asked otherwise:
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
• Default date column: order_purchase_timestamp.
• Format output as Markdown code blocks with ```sql fence.

━━━ RESPONSE FORMAT ━━━
• Keep answers concise but complete. No padding.
• Use **bold** for key terms, `code` for column/table names.
• If returning SQL, also add a 2-sentence plain-English interpretation below it.
• If a question is ambiguous, state your assumption then answer.
• Never fabricate data values. If you can't query live, say the SQL to run instead.
""".strip()


# ─── PYDANTIC MODELS ─────────────────────────────────────────────────────────
class HistoryMessage(BaseModel):
    role: str = Field(..., pattern="^(user|assistant)$")
    content: str = Field(..., min_length=1, max_length=8000)


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=1000)
    history: list[HistoryMessage] = Field(default_factory=list, max_length=20)
    session_id: Optional[str] = None


class ChatResponse(BaseModel):
    reply: str
    session_id: Optional[str] = None
    timestamp: str
    tokens_used: Optional[int] = None


# ─── INTENT CLASSIFIER ───────────────────────────────────────────────────────
# Lightweight regex-based router — upgrade to an LLM classifier when needed.
SQL_KEYWORDS = re.compile(
    r"\b(top|average|avg|count|sum|total|trend|breakdown|revenue|orders?|"
    r"sellers?|customers?|products?|categories|states?|delivery|churn|"
    r"review|rating|monthly|yearly|by region|by state|per|rank)\b",
    re.IGNORECASE,
)
OLIST_INFO_KEYWORDS = re.compile(
    r"\b(what is olist|who founded|history|about olist|when was|"
    r"dataset|schema|tables?|columns?|founded|mission|business model)\b",
    re.IGNORECASE,
)


def classify_intent(message: str) -> str:
    """Returns 'sql', 'olist_info', or 'general'."""
    if OLIST_INFO_KEYWORDS.search(message):
        return "olist_info"
    if SQL_KEYWORDS.search(message):
        return "sql"
    return "general"


# ─── OPTIONAL: LIVE SQL EXECUTOR ─────────────────────────────────────────────
def execute_sql_safe(sql: str) -> dict:
    """
    Execute a read-only SQL query against the Olist database.
    Returns { columns, rows, error }.

    Uncomment and configure DATABASE_URL to enable live query execution.
    The LLM-generated SQL is passed here only after you add a safety layer
    (whitelist SELECT-only, parameterised queries, row limit, etc.)
    """
    # SAFETY: Only allow SELECT statements
    # clean = sql.strip().upper()
    # if not clean.startswith("SELECT") and not clean.startswith("WITH"):
    #     return {"error": "Only SELECT queries are permitted."}

    # try:
    #     with engine.connect() as conn:
    #         result = conn.execute(text(sql + " LIMIT 500"))
    #         cols = list(result.keys())
    #         rows = [list(r) for r in result.fetchall()]
    #         return {"columns": cols, "rows": rows, "error": None}
    # except Exception as e:
    #     log.error("SQL execution error: %s", e)
    #     return {"columns": [], "rows": [], "error": str(e)}

    # Placeholder until DB is wired
    return {"columns": [], "rows": [], "error": "Live DB not connected yet."}


# ─── ROUTE: HEALTH CHECK ─────────────────────────────────────────────────────
@app.get("/health", tags=["System"])
async def health():
    return {"status": "ok", "agent": "3m Farghaly 🤖", "time": datetime.utcnow().isoformat()}


# ─── ROUTE: CHAT ─────────────────────────────────────────────────────────────
@app.post("/api/farghaly/chat", response_model=ChatResponse, tags=["Chat"])
async def chat(req: ChatRequest):
    """
    Main chat endpoint consumed by farghaly.js.

    Flow:
      1. Classify intent (sql / olist_info / general)
      2. Optionally augment prompt with live DB schema or query results
      3. Send to Claude claude-sonnet-4-20250514 with full conversation history
      4. (Optional) Extract + execute any SQL blocks, append result table
      5. Return { reply, session_id, timestamp, tokens_used }
    """
    log.info("Session=%s  Intent=%s  Msg=%s",
             req.session_id, classify_intent(req.message), req.message[:80])

    intent = classify_intent(req.message)

    # ── Build messages for the API ────────────────────────────────────────────
    # Truncate history to last N turns (already trimmed on frontend, but be safe)
    history_turns = req.history[-10:] if req.history else []

    messages = [
        {"role": m.role, "content": m.content}
        for m in history_turns
    ]
    messages.append({"role": "user", "content": req.message})

    # ── Optional intent-specific context injection ────────────────────────────
    system = SYSTEM_PROMPT
    if intent == "sql":
        system += "\n\n[CONTEXT] The user is asking a DATA question. Prioritise writing clean SQL."
    elif intent == "olist_info":
        system += "\n\n[CONTEXT] The user wants COMPANY INFO. Answer from your knowledge base concisely."

    # ── Call Claude ───────────────────────────────────────────────────────────
    try:
        response = claude.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            system=system,
            messages=messages,
        )
    except anthropic.AuthenticationError:
        raise HTTPException(status_code=401, detail="Invalid Anthropic API key. Check your .env file.")
    except anthropic.RateLimitError:
        raise HTTPException(status_code=429, detail="Rate limit hit — slow down, Farghaly is only human 😅")
    except anthropic.APIError as e:
        log.exception("Anthropic API error")
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")

    reply_text = response.content[0].text
    tokens_used = response.usage.input_tokens + response.usage.output_tokens

    # ── Optional: extract SQL and auto-execute ────────────────────────────────
    # sql_blocks = re.findall(r"```sql\n([\s\S]*?)```", reply_text, re.IGNORECASE)
    # if sql_blocks and intent == "sql":
    #     result = execute_sql_safe(sql_blocks[0])
    #     if result["rows"]:
    #         table_md = format_result_as_markdown(result)
    #         reply_text += f"\n\n**Live Result:**\n{table_md}"
    #     elif result["error"]:
    #         reply_text += f"\n\n> ⚠️ Live execution skipped: {result['error']}"

    log.info("Reply tokens=%d", tokens_used)

    return ChatResponse(
        reply=reply_text,
        session_id=req.session_id,
        timestamp=datetime.utcnow().isoformat(),
        tokens_used=tokens_used,
    )


# ─── ROUTE: SCHEMA INTROSPECTION (optional helper) ───────────────────────────
@app.get("/api/farghaly/schema", tags=["Data"])
async def get_schema():
    """
    Returns the Olist dataset schema as JSON.
    Useful for feeding into the system prompt dynamically.
    Replace the static dict below with a live DB introspection query.
    """
    schema = {
        "olist_orders": [
            "order_id", "customer_id", "order_status",
            "order_purchase_timestamp", "order_approved_at",
            "order_delivered_carrier_date", "order_delivered_customer_date",
            "order_estimated_delivery_date",
        ],
        "olist_order_items": [
            "order_id", "order_item_id", "product_id", "seller_id",
            "shipping_limit_date", "price", "freight_value",
        ],
        "olist_order_payments": [
            "order_id", "payment_sequential", "payment_type",
            "payment_installments", "payment_value",
        ],
        "olist_order_reviews": [
            "review_id", "order_id", "review_score",
            "review_comment_title", "review_comment_message",
            "review_creation_date", "review_answer_timestamp",
        ],
        "olist_customers": [
            "customer_id", "customer_unique_id",
            "customer_zip_code_prefix", "customer_city", "customer_state",
        ],
        "olist_sellers": [
            "seller_id", "seller_zip_code_prefix",
            "seller_city", "seller_state",
        ],
        "olist_products": [
            "product_id", "product_category_name",
            "product_name_lenght", "product_description_lenght",
            "product_photos_qty", "product_weight_g",
            "product_length_cm", "product_height_cm", "product_width_cm",
        ],
        "olist_product_category_name_translation": [
            "product_category_name", "product_category_name_english",
        ],
        "olist_geolocation": [
            "geolocation_zip_code_prefix", "geolocation_lat",
            "geolocation_lng", "geolocation_city", "geolocation_state",
        ],
    }
    return {"schema": schema, "source": "Olist Public Dataset (2016–2018)"}


# ─── OPTIONAL: MARKDOWN TABLE FORMATTER ──────────────────────────────────────
def format_result_as_markdown(result: dict) -> str:
    """Converts SQL result dict to a Markdown table string."""
    if not result.get("columns") or not result.get("rows"):
        return "_No results._"
    cols = result["columns"]
    rows = result["rows"]
    header = "| " + " | ".join(cols) + " |"
    sep    = "| " + " | ".join(["---"] * len(cols)) + " |"
    body   = "\n".join(
        "| " + " | ".join(str(cell) for cell in row) + " |"
        for row in rows[:20]   # cap at 20 rows in chat
    )
    suffix = f"\n_Showing {min(20, len(rows))} of {len(rows)} rows._" if len(rows) > 20 else ""
    return f"{header}\n{sep}\n{body}{suffix}"


# ─── ENTRY POINT ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("farghaly_api:app", host="0.0.0.0", port=8000, reload=True)