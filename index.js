const express = require('express');
const bodyParser = require('body-parser');
const mysql = require('mysql2');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(bodyParser.json());
app.use(express.static('public')); // for index.html

// MySQL connection
const db = mysql.createConnection({
    host: process.env.DB_HOST || 'mysql', // configurable for tests/CI
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'password',
    database: process.env.DB_NAME || 'contacts_db'
});

// Replace top-level db.connect(...) with initDb so tests can import without triggering a real connection.
function initDb(cb) {
    if (db && typeof db.connect === 'function') {
        db.connect(err => {
            if (err) {
                if (cb) return cb(err);
                throw err;
            }
            console.log('Connected to MySQL');
            db.query(`CREATE TABLE IF NOT EXISTS contacts (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(255),
                phone VARCHAR(50),
                email VARCHAR(255)
            )`, (err) => {
                if (err) {
                    if (cb) return cb(err);
                    throw err;
                }
                if (cb) cb(null);
            });
        });
    } else {
        // DB driver mocked or not providing connect (e.g. unit tests) — no-op but keep callback.
        if (cb) process.nextTick(() => cb(null));
    }
}

// Ensure DB initialization runs on import (safe because initDb no-ops when DB is mocked)
initDb(err => {
    if (err) {
        // don't throw during import — log and allow tests to handle failures
        console.error('initDb error:', err && err.message ? err.message : err);
    }
});

// Routes
app.get('/contacts', (req, res) => {
    db.query('SELECT * FROM contacts', (err, results) => {
        if (err) {
            return res.status(500).json({ error: err.message || 'Database error' });
        }
        res.json(results);
    });
});

app.post('/contacts', (req, res) => {
    const { name, phone, email } = req.body;
    db.query('INSERT INTO contacts (name, phone, email) VALUES (?, ?, ?)', [name, phone, email], (err, result) => {
        if (err) {
            return res.status(500).json({ error: err.message || 'Database error' });
        }
        res.json({ id: result.insertId, name, phone, email });
    });
});

app.put('/contacts/:id', (req, res) => {
    const { id } = req.params;
    const { name, phone, email } = req.body;
    db.query('UPDATE contacts SET name=?, phone=?, email=? WHERE id=?', [name, phone, email, id], (err) => {
        if (err) {
            return res.status(500).json({ error: err.message || 'Database error' });
        }
        res.json({ id, name, phone, email });
    });
});

app.delete('/contacts/:id', (req, res) => {
    const { id } = req.params;
    db.query('DELETE FROM contacts WHERE id=?', [id], (err) => {
        if (err) {
            return res.status(500).json({ error: err.message || 'Database error' });
        }
        res.json({ message: 'Deleted successfully' });
    });
});

// Search endpoint for testing & functionality
app.get('/contacts/search/:query', (req, res) => {
    const searchQuery = `%${req.params.query}%`;
    db.query(
        'SELECT * FROM contacts WHERE name LIKE ? OR phone LIKE ? OR email LIKE ?',
        [searchQuery, searchQuery, searchQuery],
        (err, results) => {
            if (err) {
                return res.status(500).json({ error: err.message || 'Database error' });
            }
            res.json(results);
        }
    );
});

// Health check endpoint for DevOps monitoring
app.get('/health', (req, res) => {
    db.query('SELECT 1', (err) => {
        if (err) {
            return res.status(503).json({ status: 'unhealthy', message: 'Database connection failed' });
        }
        res.status(200).json({ status: 'healthy', message: 'Contact Manager is running' });
    });
});

// Status endpoint for CI/CD pipeline testing
app.get('/status', (req, res) => {
    res.json({
        service: 'Contact Manager',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString()
    });
});

const PORT = process.env.PORT || 3000;

// Start server only when run directly. Ensure DB is initialized first.
if (require.main === module) {
    initDb(err => {
        if (err) throw err;
        app.listen(PORT, () => console.log(`Contact Manager running on port ${PORT}`));
    });
}

module.exports = { app, db, initDb };
