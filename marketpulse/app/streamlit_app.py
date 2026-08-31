import streamlit as st
import pandas as pd
import snowflake.connector
import google.generativeai as genai
from dotenv import load_dotenv
import os

load_dotenv("../.env")

# --- connections ---
genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))
gemini_model = genai.GenerativeModel("gemini-3.6-flash")

conn = snowflake.connector.connect(
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
    database=os.getenv("SNOWFLAKE_DATABASE"),
    schema="MARTS_CORE"  # only a fallback; SCHEMA_CONTEXT fully-qualifies every table
)

# --- schema context, hardcoded so Gemini knows what tables/columns exist ---
SCHEMA_CONTEXT = """
You have access to these Snowflake tables. Always use these exact fully-qualified names:

MARTS_CORE.fct_daily_prices (asset_id, asset_symbol, asset_class, price_date, price_usd, price_change_pct, volume_usd)
MARTS_CORE.fct_asset_volatility (asset_id, price_date, volatility_7d, volatility_30d, volatility_90d)
MARTS_CORE.dim_assets (asset_id, asset_symbol, asset_class, market_cap_tier)
MARTS_FINANCE.fct_macro_correlation (asset_id, price_date, asset_class, fed_funds_rate, cpi, unemployment_rate, treasury_10y_yield, usd_eur_rate)
"""


def generate_sql(question):
    prompt = f"""{SCHEMA_CONTEXT}

Convert this question into a single Snowflake SQL SELECT query.
Always reference tables by the fully-qualified SCHEMA.TABLE names shown above — never bare table names.
Only return the raw SQL, nothing else — no explanation, no markdown formatting, no code fences.
Never generate INSERT, UPDATE, DELETE, or DROP statements — SELECT only.

Question: {question}
"""
    response = gemini_model.generate_content(prompt)
    sql = response.text.strip()

    # Gemini sometimes wraps output in ```sql fences even when told not to — strip if present
    if sql.startswith("```"):
        sql = sql.strip("`")
        if sql.lower().startswith("sql"):
            sql = sql[3:].strip()

    return sql


def run_query(sql):
    sql_lower = sql.strip().lower()
    if not (sql_lower.startswith("select") or sql_lower.startswith("with")):
        raise ValueError("Only SELECT queries are allowed.")
    return pd.read_sql(sql, conn)


def summarize_results(question, df):
    prompt = f"""The user asked: "{question}"

Here are the query results:
{df.to_string()}

Write a 1-2 sentence plain-English answer based on this data. Be direct and specific.
"""
    response = gemini_model.generate_content(prompt)
    return response.text.strip()


# --- Streamlit UI ---
st.title("MarketPulse: Ask Your Data")

question = st.text_input("Ask a question about crypto/equity prices, volatility, or macro trends:")

if st.button("Ask") and question:
    with st.spinner("Generating SQL..."):
        sql = generate_sql(question)

    try:
        with st.spinner("Running query..."):
            results = run_query(sql)

        with st.spinner("Summarizing..."):
            answer = summarize_results(question, results)

        st.write(f"**Answer:** {answer}")
        st.dataframe(results)

    except Exception as e:
        st.error(f"Query failed: {e}")

    # shown in both paths — the SQL is how you check the answer actually matches the question
    with st.expander("Show SQL"):
        st.code(sql, language="sql")
