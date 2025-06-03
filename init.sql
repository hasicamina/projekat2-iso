-- Inicijalizacija baze za Task Manager aplikaciju
-- Kreiranje glavne tabele zadataka
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

-- Indeksi za optimizaciju upita
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at);

-- Trigger funkcija za automatsko ažuriranje updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Kreiranje trigger-a
DROP TRIGGER IF EXISTS trg_update_task ON tasks;
CREATE TRIGGER trg_update_task
    BEFORE UPDATE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Demo podaci
INSERT INTO tasks (title, description, status, priority, due_date) VALUES
    ('Postaviti server', 'Instalirati sve servise na EC2 instanci', 'done', 1, CURRENT_DATE - INTERVAL '1 day'),
    ('Napraviti backend', 'Node.js + Express API za task management', 'in-progress', 1, CURRENT_DATE + INTERVAL '1 day'),
    ('Dizajnirati frontend', 'HTML/CSS/JS aplikacija za prikaz zadataka', 'pending', 2, CURRENT_DATE + INTERVAL '3 days'),
    ('Testirati aplikaciju', 'Unit i integration testovi', 'pending', 2, CURRENT_DATE + INTERVAL '5 days'),
    ('Deploy na production', 'Pokretanje aplikacije na serveru', 'pending', 3, CURRENT_DATE + INTERVAL '7 days')
ON CONFLICT DO NOTHING;

-- View za statistike
CREATE OR REPLACE VIEW task_stats AS
SELECT 
    COUNT(*) AS total_tasks,
    COUNT(*) FILTER (WHERE status = 'done') AS completed_tasks,
    COUNT(*) FILTER (WHERE status = 'in-progress') AS in_progress_tasks,
    COUNT(*) FILTER (WHERE status = 'pending') AS pending_tasks,
    COUNT(*) FILTER (WHERE due_date < CURRENT_DATE AND status != 'done') AS overdue_tasks,
    ROUND(
        (COUNT(*) FILTER (WHERE status = 'done') * 100.0 / NULLIF(COUNT(*), 0)), 2
    ) AS completion_percentage
FROM tasks;

-- Stored procedure za čišćenje starih zadataka
CREATE OR REPLACE FUNCTION cleanup_completed_tasks(older_than_days INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM tasks
    WHERE status = 'done'
      AND updated_at < CURRENT_DATE - INTERVAL '1 day' * older_than_days;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Funkcija za dobijanje zadataka po statusu
CREATE OR REPLACE FUNCTION get_tasks_by_status(task_status VARCHAR)
RETURNS TABLE(
    id INTEGER,
    title VARCHAR,
    description TEXT,
    status VARCHAR,
    priority INTEGER,
    due_date DATE,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.title, t.description, t.status, t.priority, t.due_date, t.created_at, t.updated_at
    FROM tasks t
    WHERE t.status = task_status
    ORDER BY t.priority ASC, t.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Dokumentacija
COMMENT ON TABLE tasks IS 'Glavna tabela za čuvanje zadataka u Task Manager aplikaciji';
COMMENT ON COLUMN tasks.id IS 'Jedinstveni identifikator zadatka';
COMMENT ON COLUMN tasks.title IS 'Naslov/naziv zadatka (obavezno)';
COMMENT ON COLUMN tasks.description IS 'Detaljan opis zadatka (opciono)';
COMMENT ON COLUMN tasks.status IS 'Status zadatka: pending, in-progress, done';
COMMENT ON COLUMN tasks.priority IS 'Prioritet zadatka (1=najveći prioritet, 5=najmanji)';
COMMENT ON COLUMN tasks.due_date IS 'Datum do kada treba završiti zadatak';
COMMENT ON COLUMN tasks.created_at IS 'Vreme kreiranja zadatka';
COMMENT ON COLUMN tasks.updated_at IS 'Vreme poslednje izmene zadatka';

-- Finalna poruka
SELECT '✅ Task Manager baza je uspešno inicijalizovana i spremna za rad!' AS status;