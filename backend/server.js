require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3000;

<<<<<<< HEAD
const pool = new Pool({
    connectionString: process.env.DATABASE_URL || 'postgresql://postgres:password@localhost:5432/taskdb',
=======
// Database configuration koristeći individualne varijable
const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'webapp_db',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'your_password_here',
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
>>>>>>> 3fb89c6 (izmjena)
});

app.use(cors());
app.use(express.json());

<<<<<<< HEAD
// Helper: Create tasks table if not exists (možeš pozvati pri startu)
async function createTableIfNotExists() {
    const query = `
      CREATE TABLE IF NOT EXISTS tasks (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `;
    await pool.query(query);
}

=======
// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV
    });
});

// Test database connection
async function testDatabaseConnection() {
    try {
        await pool.query('SELECT NOW()');
        console.log('✅ Database connected successfully');
        console.log(`📊 Connected to: ${process.env.DB_NAME} on ${process.env.DB_HOST}:${process.env.DB_PORT}`);
    } catch (error) {
        console.error('❌ Database connection failed:', error.message);
        process.exit(1);
    }
}

// Helper: Create tasks table if not exists
async function createTableIfNotExists() {
    const query = `
      CREATE TABLE IF NOT EXISTS tasks (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `;
    await pool.query(query);
    console.log('📋 Tasks table ready');
}

>>>>>>> 3fb89c6 (izmjena)
app.get('/tasks', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM tasks ORDER BY created_at DESC');
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching tasks:', error);
        res.status(500).json({ error: 'Failed to fetch tasks' });
    }
});

app.get('/tasks/:id', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM tasks WHERE id = $1', [req.params.id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Task not found' });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching task:', error);
        res.status(500).json({ error: 'Failed to fetch task' });
    }
});

app.post('/tasks', async (req, res) => {
    try {
        const { title, description } = req.body;
        if (!title) {
            return res.status(400).json({ error: 'Title is required' });
        }

        const result = await pool.query(
            'INSERT INTO tasks (title, description) VALUES ($1, $2) RETURNING *',
            [title, description || null]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating task:', error);
        res.status(500).json({ error: 'Failed to create task' });
    }
});

app.put('/tasks/:id', async (req, res) => {
    try {
        const { title, description } = req.body;
        if (!title) {
            return res.status(400).json({ error: 'Title is required' });
        }

        const result = await pool.query(
            `UPDATE tasks SET title=$1, description=$2, updated_at=NOW() WHERE id=$3 RETURNING *`,
            [title, description || null, req.params.id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Task not found' });
        }

        res.json({ message: 'Task updated successfully', task: result.rows[0] });
    } catch (error) {
        console.error('Error updating task:', error);
        res.status(500).json({ error: 'Failed to update task' });
    }
});

app.delete('/tasks/:id', async (req, res) => {
    try {
        const result = await pool.query('DELETE FROM tasks WHERE id = $1 RETURNING *', [req.params.id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Task not found' });
        }
        res.json({ message: 'Task deleted successfully' });
    } catch (error) {
        console.error('Error deleting task:', error);
        res.status(500).json({ error: 'Failed to delete task' });
    }
});

<<<<<<< HEAD
createTableIfNotExists().then(() => {
    app.listen(port, () => {
        console.log(`Server running on port ${port}`);
    });
}).catch(err => {
    console.error('Failed to create tasks table:', err);
    process.exit(1);
});
=======
// Initialize database and start server
async function initializeApp() {
    try {
        await testDatabaseConnection();
        await createTableIfNotExists();
        
        app.listen(port, () => {
            console.log(`🚀 Server running on port ${port} in ${process.env.NODE_ENV} mode`);
        });
    } catch (error) {
        console.error('Failed to initialize application:', error);
        process.exit(1);
    }
}

initializeApp();
>>>>>>> 3fb89c6 (izmjena)
