import mysql.connector

app = Flask(__name__)

# Replace with your RDS values
db_config = {
    "host": "onfinance-mysql-db.cdaw0w26oeok.ap-south-1.rds.amazonaws.com",
    "user": "admin",
    "password": "OnFinance123!",
    "database": "onfinancedb",
}


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/submit", methods=["POST"])
def submit():
    name = request.form["name"]
    amount = request.form["amount"]

    conn = mysql.connector.connect(**db_config)
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO transactions (name, amount) VALUES (%s, %s)", (name, amount)
    )
    conn.commit()
    cursor.close()
    conn.close()

    return "Transaction recorded!"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
