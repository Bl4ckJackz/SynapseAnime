const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const dbPath = path.resolve(__dirname, '../anime_player.db');

console.log(`Opening database at ${dbPath}`);
const db = new sqlite3.Database(dbPath);

db.serialize(() => {
    // Clear Watchlist
    db.run("DELETE FROM watchlist", function (err) {
        if (err) {
            console.error("Error clearing watchlist:", err.message);
        } else {
            console.log(`Deleted ${this.changes} rows from watchlist`);
        }
    });

    // Clear Watch History
    db.run("DELETE FROM watch_history", function (err) {
        if (err) {
            console.error("Error clearing watch_history:", err.message);
        } else {
            console.log(`Deleted ${this.changes} rows from watch_history`);
        }
    });
});

db.close((err) => {
    if (err) {
        console.error(err.message);
    }
    console.log('Database connection closed.');
});
