require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3000;

// Database configuration koristeći individualne varijable
const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'webapp_db',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'your_password_here',
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint za ALB - JEDNOSTAVAN
app.get('/api/health', (req, res) => {
    res.status(200).json({ status: 'OK' });
});

// Jednostavan health na root nivou (za nginx)
app.get('/health', (req, res) => {
    res.status(200).send('Backend healthy');
});

// Detaljniji health check sa database testom
app.get('/api/health/detailed', async (req, res) => {
    try {
        // Test database connection
        const result = await pool.query('SELECT NOW() as current_time');
        res.status(200).json({ 
            status: 'OK', 
            timestamp: new Date().toISOString(),
            environment: process.env.NODE_ENV || 'development',
            database: 'connected',
            db_time: result.rows[0].current_time
        });
    } catch (error) {
        res.status(503).json({ 
            status: 'ERROR', 
            timestamp: new Date().toISOString(),
            database: 'disconnected',
            error: error.message
        });
    }
});

// Test database connection
async function testDatabaseConnection() {
    try {
        const result = await pool.query('SELECT NOW() as current_time, version() as postgres_version');
        console.log('✅ Database connected successfully');
        console.log(`📊 Connected to: ${process.env.DB_NAME} on ${process.env.DB_HOST}:${process.env.DB_PORT}`);
        console.log(`🕐 Database time: ${result.rows[0].current_time}`);
        return true;
    } catch (error) {
        console.error('❌ Database connection failed:', error.message);
        return false;
    }
}

// Create tasks table if not exists
async function createTableIfNotExists() {
    try {
        const query = `
            CREATE TABLE IF NOT EXISTS tasks (
                id SERIAL PRIMARY KEY,
                title VARCHAR(255) NOT NULL,
                description TEXT,
                status VARCHAR(50) DEFAULT 'pending',
                priority INTEGER DEFAULT 1,
                due_date DATE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `;
        await pool.query(query);
        console.log('📋 Tasks table ready');
        return true;
    } catch (error) {
        console.error('❌ Failed to create tasks table:', error);
        return false;
    }
}

// API Routes

// GET /tasks
app.get('/api/tasks', async (req, res) => {
    try {
        const { status, priority, limit } = req.query;
        let query = 'SELECT * FROM tasks';
        let params = [];
        let conditions = [];

        if (status) {
            conditions.push('status = $' + (params.length + 1));
            params.push(status);
        }

        if (priority) {
            conditions.push('priority = $' + (params.length + 1));
            params.push(parseInt(priority));
        }

        if (conditions.length > 0) {
            query += ' WHERE ' + conditions.join(' AND ');
        }

        query += ' ORDER BY priority ASC, created_at DESC';

        if (limit) {
            query += ' LIMIT $' + (params.length + 1);
            params.push(parseInt(limit));
        }

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching tasks:', error);
        res.status(500).json({ error: 'Failed to fetch tasks', details: error.message });
    }
});

// GET /tasks/:id
app.get('/api/tasks/:id', async (req, res) => {
    try {
        const taskId = parseInt(req.params.id);
        if (isNaN(taskId)) {
            return res.status(400).json({ error: 'Invalid task ID' });
        }

        const result = await pool.query('SELECT * FROM tasks WHERE id = $1', [taskId]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Task not found' });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching task:', error);
        res.status(500).json({ error: 'Failed to fetch task', details: error.message });
    }
});

// POST /tasks
app.post('/api/tasks', async (req, res) => {
    try {
        const { title, description, status, priority, due_date } = req.body;
        
        if (!title || title.trim() === '') {
            return res.status(400).json({ error: 'Title is required' });
        }

        const validStatuses = ['pending', 'in-progress', 'done'];
        const taskStatus = status && validStatuses.includes(status) ? status : 'pending';

        const taskPriority = priority && Number.isInteger(priority) && priority >= 1 && priority <= 5 ? priority : 1;

        const result = await pool.query(
            `INSERT INTO tasks (title, description, status, priority, due_date) 
             VALUES ($1, $2, $3, $4, $5) RETURNING *`,
            [title.trim(), description || null, taskStatus, taskPriority, due_date || null]
        );
        
        res.status(201).json({
            message: 'Task created successfully',
            task: result.rows[0]
        });
    } catch (error) {
        console.error('Error creating task:', error);
        res.status(500).json({ error: 'Failed to create task', details: error.message });
    }
});

// PUT /tasks/:id
app.put('/api/tasks/:id', async (req, res) => {
    try {
        const taskId = parseInt(req.params.id);
        if (isNaN(taskId)) {
            return res.status(400).json({ error: 'Invalid task ID' });
        }

        const { title, description, status, priority, due_date } = req.body;
        
        if (!title || title.trim() === '') {
            return res.status(400).json({ error: 'Title is required' });
        }

        const validStatuses = ['pending', 'in-progress', 'done'];
        if (status && !validStatuses.includes(status)) {
            return res.status(400).json({ error: 'Invalid status. Must be: pending, in-progress, or done' });
        }

        if (priority && (!Number.isInteger(priority) || priority < 1 || priority > 5)) {
            return res.status(400).json({ error: 'Invalid priority. Must be integer between 1 and 5' });
        }

        const result = await pool.query(
            `UPDATE tasks SET 
                title = $1, 
                description = $2, 
                status = COALESCE($3, status),
                priority = COALESCE($4, priority),
                due_date = $5,
                updated_at = NOW() 
             WHERE id = $6 RETURNING *`,
            [title.trim(), description || null, status, priority, due_date || null, taskId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Task not found' });
        }

        res.json({ 
            message: 'Task updated successfully', 
            task: result.rows[0] 
        });
    } catch (error) {
        console.error('Error updating task:', error);
        res.status(500).json({ error: 'Failed to update task', details: error.message });
    }
});

// DELETE /tasks/:id
app.delete('/api/tasks/:id', async (req, res) => {
    try {
        const taskId = parseInt(req.params.id);
        if (isNaN(taskId)) {
            return res.status(400).json({ error: 'Invalid task ID' });
        }

        const result = await pool.query('DELETE FROM tasks WHERE id = $1 RETURNING *', [taskId]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Task not found' });
        }
        
        res.json({ 
            message: 'Task deleted successfully',
            deleted_task: result.rows[0]
        });
    } catch (error) {
        console.error('Error deleting task:', error);
        res.status(500).json({ error: 'Failed to delete task', details: error.message });
    }
});

// GET /stats
app.get('/api/stats', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM task_stats');
        res.json(result.rows[0] || {});
    } catch (error) {
        console.error('Error fetching stats:', error);
        res.status(500).json({ error: 'Failed to fetch statistics', details: error.message });
    }
});

// Graceful shutdown
process.on('SIGTERM', async () => {
    console.log('🔄 Shutting down gracefully...');
    await pool.end();
    process.exit(0);
});

process.on('SIGINT', async () => {
    console.log('🔄 Shutting down gracefully...');
    await pool.end();
    process.exit(0);
});

// Initialize and start server
async function initializeApp() {
    try {
        console.log('🚀 Starting Task Manager API...');
        
        const dbConnected = await testDatabaseConnection();
        if (!dbConnected) {
            console.error('❌ Cannot start server without database connection');
            process.exit(1);
        }

        const tableCreated = await createTableIfNotExists();
        if (!tableCreated) {
            console.error('❌ Cannot start server without tasks table');
            process.exit(1);
        }
        
        app.listen(port, () => {
            console.log(`🚀 Task Manager API running on port ${port}`);
            console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
            console.log(`📋 Health check: http://localhost:${port}/api/health`);
            console.log(`📋 Simple health: http://localhost:${port}/health`);
        });
    } catch (error) {
        console.error('❌ Failed to initialize application:', error);
        process.exit(1);
    }
}

initializeApp();