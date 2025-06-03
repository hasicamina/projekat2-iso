document.addEventListener('DOMContentLoaded', () => {
    // Promijenjen API URL na relativni put da radi preko ALB-a
    const API_URL = '/api/tasks';
    const taskForm = document.getElementById('task-form');
    const tasksList = document.getElementById('tasks-list');
    const titleInput = document.getElementById('title');
    const descriptionInput = document.getElementById('description');
    const taskIdInput = document.getElementById('task-id');
    const submitBtn = document.getElementById('submit-btn');
    const cancelBtn = document.getElementById('cancel-btn');

    function fetchTasks() {
        tasksList.innerHTML = '<div class="loading">Loading tasks...</div>';
        
        fetch(API_URL)
            .then(response => response.json())
            .then(tasks => {
                if (tasks.length === 0) {
                    tasksList.innerHTML = '<div class="loading">No tasks yet. Add one above!</div>';
                    return;
                }
                
                tasksList.innerHTML = '';
                tasks.forEach(task => {
                    const taskElement = document.createElement('div');
                    taskElement.classList.add('task-item');
                    taskElement.innerHTML = `
                        <div class="task-title">${task.title}</div>
                        <div class="task-description">${task.description || ''}</div>
                        <div class="task-actions">
<<<<<<< HEAD
                            <button class="edit" data-id="${task._id}">Edit</button>
                            <button class="delete" data-id="${task._id}">Delete</button>
=======
                            <button class="edit" data-id="${task.id}">Edit</button>
                            <button class="delete" data-id="${task.id}">Delete</button>
>>>>>>> 3fb89c6 (izmjena)
                        </div>
                    `;
                    tasksList.appendChild(taskElement);
                });
                
                document.querySelectorAll('button.edit').forEach(button => {
                    button.addEventListener('click', handleEdit);
                });
                
                document.querySelectorAll('button.delete').forEach(button => {
                    button.addEventListener('click', handleDelete);
                });
            })
            .catch(error => {
                console.error('Error fetching tasks:', error);
                tasksList.innerHTML = '<div class="loading">Error loading tasks. Please try again.</div>';
            });
    }

    function handleSubmit(event) {
        event.preventDefault();
        
        const task = {
            title: titleInput.value,
            description: descriptionInput.value
        };
        
        const isEditing = taskIdInput.value !== '';
        const url = isEditing ? `${API_URL}/${taskIdInput.value}` : API_URL;
        const method = isEditing ? 'PUT' : 'POST';
        
        fetch(url, {
            method: method,
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(task)
        })
        .then(response => {
            if (!response.ok) {
                throw new Error('Failed to save task');
            }
            resetForm();
            fetchTasks();
        })
        .catch(error => {
            console.error('Error saving task:', error);
            alert('Failed to save task. Please try again.');
        });
    }

    function handleEdit(event) {
        const taskId = event.target.dataset.id;
        
        fetch(`${API_URL}/${taskId}`)
            .then(response => response.json())
            .then(task => {
                titleInput.value = task.title;
                descriptionInput.value = task.description || '';
<<<<<<< HEAD
                taskIdInput.value = task._id;
=======
                taskIdInput.value = task.id;
>>>>>>> 3fb89c6 (izmjena)
                submitBtn.textContent = 'Update Task';
                cancelBtn.style.display = 'inline-block';
            })
            .catch(error => {
                console.error('Error fetching task details:', error);
                alert('Failed to load task details. Please try again.');
            });
    }

    function handleDelete(event) {
        if (!confirm('Are you sure you want to delete this task?')) {
            return;
        }
        
        const taskId = event.target.dataset.id;
        
        fetch(`${API_URL}/${taskId}`, {
            method: 'DELETE'
        })
        .then(response => {
            if (!response.ok) {
                throw new Error('Failed to delete task');
            }
            fetchTasks();
        })
        .catch(error => {
            console.error('Error deleting task:', error);
            alert('Failed to delete task. Please try again.');
        });
    }

    function resetForm() {
        taskForm.reset();
        taskIdInput.value = '';
        submitBtn.textContent = 'Add Task';
        cancelBtn.style.display = 'none';
    }

    taskForm.addEventListener('submit', handleSubmit);
    cancelBtn.addEventListener('click', resetForm);
    
    fetchTasks();
<<<<<<< HEAD
});
=======
});
>>>>>>> 3fb89c6 (izmjena)
