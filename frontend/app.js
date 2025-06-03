document.addEventListener('DOMContentLoaded', () => {
    // API URL - menja se ovisno o environment-u
    const API_URL = window.location.hostname === 'localhost' 
        ? 'http://localhost:3000/tasks' 
        : '/api/tasks';
    
    // DOM elementi
    const taskForm = document.getElementById('task-form');
    const tasksList = document.getElementById('tasks-list');
    const titleInput = document.getElementById('title');
    const descriptionInput = document.getElementById('description');
    const taskIdInput = document.getElementById('task-id');
    const submitBtn = document.getElementById('submit-btn');
    const cancelBtn = document.getElementById('cancel-btn');

    // Učitavanje zadataka sa servera
    function fetchTasks() {
        tasksList.innerHTML = '<div class="loading">Loading tasks...</div>';
        
        fetch(API_URL)
            .then(response => {
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return response.json();
            })
            .then(tasks => {
                displayTasks(tasks);
            })
            .catch(error => {
                console.error('Error fetching tasks:', error);
                tasksList.innerHTML = '<div class="loading error">Error loading tasks. Please check your connection and try again.</div>';
            });
    }

    // Prikaz zadataka u UI
    function displayTasks(tasks) {
        if (tasks.length === 0) {
            tasksList.innerHTML = '<div class="loading">No tasks yet. Add one above!</div>';
            return;
        }
        
        tasksList.innerHTML = '';
        
        tasks.forEach(task => {
            const taskElement = document.createElement('div');
            taskElement.classList.add('task-item');
            
            // Dodajemo CSS klasu na osnovu statusa
            if (task.status) {
                taskElement.classList.add(`status-${task.status}`);
            }
            
            // Formatiranje datuma
            const createdDate = new Date(task.created_at).toLocaleDateString();
            const dueDate = task.due_date ? new Date(task.due_date).toLocaleDateString() : 'No due date';
            
            taskElement.innerHTML = `
                <div class="task-header">
                    <div class="task-title">${escapeHtml(task.title)}</div>
                    <div class="task-meta">
                        <span class="task-status status-${task.status}">${task.status || 'pending'}</span>
                        <span class="task-priority priority-${task.priority}">Priority: ${task.priority || 1}</span>
                    </div>
                </div>
                <div class="task-description">${escapeHtml(task.description || '')}</div>
                <div class="task-dates">
                    <small>Created: ${createdDate} | Due: ${dueDate}</small>
                </div>
                <div class="task-actions">
                    <button class="edit" data-id="${task.id}">Edit</button>
                    <button class="delete" data-id="${task.id}">Delete</button>
                </div>
            `;
            
            tasksList.appendChild(taskElement);
        });
        
        // Dodavanje event listener-a za dugmad
        document.querySelectorAll('button.edit').forEach(button => {
            button.addEventListener('click', handleEdit);
        });
        
        document.querySelectorAll('button.delete').forEach(button => {
            button.addEventListener('click', handleDelete);
        });
    }

    // Helper funkcija za escape HTML
    function escapeHtml(unsafe) {
        if (!unsafe) return '';
        return unsafe
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }

    // Submit handler za form
    function handleSubmit(event) {
        event.preventDefault();
        
        const task = {
            title: titleInput.value.trim(),
            description: descriptionInput.value.trim() || null
        };
        
        if (!task.title) {
            alert('Title is required!');
            return;
        }
        
        const isEditing = taskIdInput.value !== '';
        const url = isEditing ? `${API_URL}/${taskIdInput.value}` : API_URL;
        const method = isEditing ? 'PUT' : 'POST';
        
        // Disable submit button tokom request-a
        submitBtn.disabled = true;
        submitBtn.textContent = isEditing ? 'Updating...' : 'Adding...';
        
        fetch(url, {
            method: method,
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(task)
        })
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            return response.json();
        })
        .then(data => {
            console.log('Task saved:', data);
            resetForm();
            fetchTasks();
        })
        .catch(error => {
            console.error('Error saving task:', error);
            alert('Failed to save task. Please try again.');
        })
        .finally(() => {
            // Re-enable submit button
            submitBtn.disabled = false;
            submitBtn.textContent = isEditing ? 'Update Task' : 'Add Task';
        });
    }

    // Edit handler
    function handleEdit(event) {
        const taskId = event.target.dataset.id;
        
        fetch(`${API_URL}/${taskId}`)
            .then(response => {
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return response.json();
            })
            .then(task => {
                titleInput.value = task.title;
                descriptionInput.value = task.description || '';
                taskIdInput.value = task.id;
                submitBtn.textContent = 'Update Task';
                cancelBtn.style.display = 'inline-block';
                
                // Scroll to form
                taskForm.scrollIntoView({ behavior: 'smooth' });
                titleInput.focus();
            })
            .catch(error => {
                console.error('Error fetching task details:', error);
                alert('Failed to load task details. Please try again.');
            });
    }

    // Delete handler
    function handleDelete(event) {
        if (!confirm('Are you sure you want to delete this task?')) {
            return;
        }
        
        const taskId = event.target.dataset.id;
        const deleteBtn = event.target;
        
        // Disable delete button
        deleteBtn.disabled = true;
        deleteBtn.textContent = 'Deleting...';
        
        fetch(`${API_URL}/${taskId}`, {
            method: 'DELETE'
        })
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            return response.json();
        })
        .then(data => {
            console.log('Task deleted:', data);
            fetchTasks();
        })
        .catch(error => {
            console.error('Error deleting task:', error);
            alert('Failed to delete task. Please try again.');
        })
        .finally(() => {
            deleteBtn.disabled = false;
            deleteBtn.textContent = 'Delete';
        });
    }

    // Reset form
    function resetForm() {
        taskForm.reset();
        taskIdInput.value = '';
        submitBtn.textContent = 'Add Task';
        cancelBtn.style.display = 'none';
    }

    // Event listeners
    taskForm.addEventListener('submit', handleSubmit);
    cancelBtn.addEventListener('click', resetForm);
    
    // Initial load
    fetchTasks();
    
    // Auto-refresh every 30 seconds
    setInterval(fetchTasks, 30000);
    
    console.log('Task Manager initialized successfully!');
});