import pandas as pd
import snowflake.connector
from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error
from dotenv import load_dotenv
import os

load_dotenv("../.env")

conn = snowflake.connector.connect(
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
    database=os.getenv("SNOWFLAKE_DATABASE"),
    schema="MARTS_ML"
)

query = "select * from fct_volatility_features"
df = pd.read_sql(query, conn)
conn.close()

print(df.shape)
print(df.head())
print("Before dropping NaNs:", df.shape)
df = df.dropna()
print("After dropping NaNs:", df.shape)

# encode asset_class as 0/1 
df['asset_class_encoded'] = df['ASSET_CLASS'].map({'crypto': 0, 'equity': 1})

# trend feature (is volatility rising or falling right now?)
df['volatility_trend'] = df['TODAY_VOLATILITY_7D'] - df['TODAY_VOLATILITY_30D']


df = df.sort_values('PRICE_DATE')


def time_based_split(frame, x_cols, y_col, test_frac=0.2):
    dates = frame['PRICE_DATE'].sort_values().unique()
    cutoff = dates[int(len(dates) * (1 - test_frac))]
    train = frame[frame['PRICE_DATE'] < cutoff]
    test = frame[frame['PRICE_DATE'] >= cutoff]
    return train[x_cols], test[x_cols], train[y_col], test[y_col]


# define features (X) and target (y) 
feature_cols = [
    'TODAY_VOLATILITY_7D',
    'TODAY_VOLATILITY_30D',
    'FED_FUNDS_RATE',
    'TODAY_PRICE_CHANGE_PCT',
    'asset_class_encoded'
]
target_col = 'TARGET_NEXT_DAY_VOLATILITY_7D'

X_train, X_test, y_train, y_test = time_based_split(df, feature_cols, target_col)

# train the model 
model = RandomForestRegressor(n_estimators=100, random_state=42)
model.fit(X_train, y_train)
predictions = model.predict(X_test)
mae = mean_absolute_error(y_test, predictions)
print(f"Model MAE: {mae:.4f}")

naive_mae = mean_absolute_error(y_test, X_test['TODAY_VOLATILITY_7D'])
print(f"Naive baseline MAE: {naive_mae:.4f}")

X_train_s, X_test_s, y_train_s, y_test_s = time_based_split(
    df, ['TODAY_VOLATILITY_7D'], target_col
)
model_simple = RandomForestRegressor(n_estimators=100, max_depth=5, random_state=42)
model_simple.fit(X_train_s, y_train_s)
preds_simple = model_simple.predict(X_test_s)
mae_simple = mean_absolute_error(y_test_s, preds_simple)
print(f"Simple model MAE (1 feature): {mae_simple:.4f}")

lin_model_full = LinearRegression()
lin_model_full.fit(X_train, y_train)
lin_preds_full = lin_model_full.predict(X_test)
lin_mae_full = mean_absolute_error(y_test, lin_preds_full)
print(f"Linear regression MAE (5 features): {lin_mae_full:.4f}")

# linear regression WITH trend feature 
feature_cols_trend = feature_cols + ['volatility_trend']

X_train_t, X_test_t, y_train_t, y_test_t = time_based_split(
    df, feature_cols_trend, target_col
)

lin_model_trend = LinearRegression()
lin_model_trend.fit(X_train_t, y_train_t)
lin_preds_trend = lin_model_trend.predict(X_test_t)
lin_mae_trend = mean_absolute_error(y_test_t, lin_preds_trend)
print(f"Linear regression MAE (with trend feature): {lin_mae_trend:.4f}")