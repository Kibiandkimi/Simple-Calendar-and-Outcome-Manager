import 'dart:developer' as developer;
import 'dart:math';
import 'package:database/database_bindings_generated.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ffi/ffi.dart';
import 'package:database/database.dart' as database;
import 'package:table_calendar/table_calendar.dart';

// ========================== Models ==========================

class Task {
  int listId;
  int id;
  String title;
  String description;
  DateTime startTime;
  DateTime endTime;
  int status;

  Task({
    required this.listId,
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.status = 0,
  });

  factory Task.fromDartTask(Dart_Task task) {
    return Task(
      listId: task.list_id,
      id: task.id,
      title: task.title.toDartString(),
      description: task.description.toDartString(),
      startTime: DateTime.parse(task.startDate.toDartString()),
      endTime: DateTime.parse(task.endDate.toDartString()),
      status: task.status,
    );
  }

  bool get isCompleted => status == 1;
  bool get isOverdue => status == 2;
  bool get isDeleted => status == 4;
}

class TaskList {
  int id;
  String title;
  Map<int, Task> tasks;

  TaskList({
    required this.id,
    required this.title,
    Map<int, Task>? tasks,
  }) : tasks = tasks ?? {};

  factory TaskList.fromDartTaskList(Dart_TaskList list) {
    return TaskList(
      id: list.id,
      title: list.title.toDartString(),
    );
  }

  List<Task> get activeTasks =>
      tasks.values.where((task) => !task.isDeleted).toList();
}

// ========================== Services ==========================

class DatabaseService {
  static bool _initialized = false;
  static final Map<int, TaskList> _taskLists = {};

  static Map<int, TaskList> get taskLists => _taskLists;

  static void initialize() {
    if (_initialized) {
      developer.log('Database already initialized', level: 900);
      return;
    }

    database.initDatabaseC();
    _loadTaskLists();
    _loadTasks();
    _initialized = true;
    developer.log('Database initialized successfully', level: 800);
  }

  static void _loadTaskLists() {
    final listNum = database.preGetTaskListC();
    for (int i = 0; i < listNum; i++) {
      final listC = database.getTaskListC();
      final taskList = TaskList.fromDartTaskList(listC);
      _taskLists[taskList.id] = taskList;
    }
  }

  static void _loadTasks() {
    final taskNum = database.preGetTaskC();
    for (int i = 0; i < taskNum; i++) {
      final taskC = database.getTaskC();
      final task = Task.fromDartTask(taskC);

      if (_taskLists[task.listId] != null) {
        _taskLists[task.listId]!.tasks[task.id] = task;
      } else {
        developer.log('No list found for task ${task.id}', level: 1000);
      }
    }
  }

  static int addTaskList(String title) {
    final id = database.addTaskListC(title.toNativeUtf8());
    _taskLists[id] = TaskList(id: id, title: title);
    return id;
  }

  static int addTask(Task task) {
    final id = database.addTaskC(
      task.listId,
      task.title.toNativeUtf8(),
      task.description.toNativeUtf8(),
      task.startTime.toString().toNativeUtf8(),
      task.endTime.toString().toNativeUtf8(),
      task.status,
    );

    task.id = id;
    _taskLists[task.listId]?.tasks[id] = task;
    return id;
  }

  static void updateTask(Task task) {
    database.updateTaskC(
      task.listId,
      task.id,
      task.title.toNativeUtf8(),
      task.description.toNativeUtf8(),
      task.startTime.toString().toNativeUtf8(),
      task.endTime.toString().toNativeUtf8(),
      task.status,
    );
    _taskLists[task.listId]?.tasks[task.id] = task;
  }

  static void deleteTask(int taskId, int listId) {
    database.deleteTaskC(taskId);
    _taskLists[listId]?.tasks.remove(taskId);
  }

  static void deleteTaskList(int listId) {
    database.deleteTaskListC(listId);
    _taskLists.remove(listId);
  }

  static void moveTask(int taskId, int fromListId, int toListId) {
    final task = _taskLists[fromListId]?.tasks[taskId];
    if (task != null && _taskLists[toListId] != null) {
      task.listId = toListId;
      updateTask(task);
      _taskLists[fromListId]?.tasks.remove(taskId);
      _taskLists[toListId]?.tasks[taskId] = task;
    }
  }
}

// ========================== State Management ==========================

class AppState extends ChangeNotifier {
  void refresh() => notifyListeners();
}

// ========================== Main App ==========================

void main() {
  DatabaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp(
        title: "SCOM",
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

// ========================== Home Page ==========================

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static const List<({IconData icon, String label})> _destinations = [
    (icon: Icons.checklist, label: 'SCOM'),
    (icon: Icons.calendar_month, label: 'Calendar'),
    (icon: Icons.settings, label: 'Settings'),
  ];

  Widget _getPage(int index) {
    switch (index) {
      case 0: return const TodoPage();
      case 1: return const CalendarPage();
      case 2: return const SettingsPage();
      default: throw UnimplementedError('No widget for $_selectedIndex');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 800;
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Scaffold(
            body: _getPage(_selectedIndex),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              items: _destinations.map((dest) =>
                BottomNavigationBarItem(
                  icon: Icon(dest.icon),
                  label: dest.label,
                )
              ).toList(),
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: isWideScreen,
                  destinations: _destinations.map((dest) =>
                    NavigationRailDestination(
                      icon: Icon(dest.icon),
                      label: Text(dest.label),
                    )
                  ).toList(),
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: _getPage(_selectedIndex),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========================== Todo Page ==========================

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  int? _selectedListId;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final taskLists = DatabaseService.taskLists;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            if (isMobile) {
              return _buildMobileLayout(taskLists);
            }
            return _buildDesktopLayout(taskLists);
          },
        );
      },
    );
  }

  Widget _buildMobileLayout(Map<int, TaskList> taskLists) {
    return _buildTaskListSelector(taskLists, true);
  }

  Widget _buildDesktopLayout(Map<int, TaskList> taskLists) {
    return Row(
      children: [
        SizedBox(
          width: 250,
          child: _buildTaskListSelector(taskLists, false),
        ),
        Expanded(
          child: _selectedListId != null && taskLists.containsKey(_selectedListId)
              ? _buildTaskListView(_selectedListId!, false)
              : const Center(child: Text('Select a task list')),
        ),
      ],
    );
  }

  Widget _buildTaskListSelector(Map<int, TaskList> taskLists, bool isMobile) {
    return Scaffold(
      appBar: isMobile ? AppBar(
        title: const Text('Task Lists'),
        leading: _selectedListId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedListId = null),
              )
            : null,
      ) : null,
      floatingActionButton: FloatingActionButton(
        mini: !isMobile,
        onPressed: _showAddTaskListDialog,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: taskLists.length,
        itemBuilder: (context, index) {
          final taskList = taskLists.values.elementAt(index);
          return _buildTaskListTile(taskList, isMobile);
        },
      ),
    );
  }

  Widget _buildTaskListTile(TaskList taskList, bool isMobile) {
    final taskCount = taskList.activeTasks.length;

    return ListTile(
      leading: const Icon(Icons.list),
      title: Text(taskList.title),
      subtitle: Text('$taskCount tasks'),
      trailing: PopupMenuButton<String>(
        onSelected: (String value) {
          if (value == 'delete') {
            _deleteTaskList(taskList.id);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'delete',
            child: const Row(
              children: [Icon(Icons.delete), SizedBox(width: 8), Text('Delete')],
            ),
          ),
        ],
      ),
      onTap: () {
        if (isMobile) {
          // Use proper navigation for mobile
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskListDetailPage(taskList: taskList),
            ),
          );
        } else {
          // Keep the existing behavior for desktop
          setState(() => _selectedListId = taskList.id);
        }
      },
      selected: _selectedListId == taskList.id,
    );
  }

  Widget _buildTaskListView(int listId, bool isMobile) {
    final taskList = DatabaseService.taskLists[listId]!;
    final tasks = taskList.activeTasks;

    return Scaffold(
      appBar: isMobile ? AppBar(
        title: Text(taskList.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _selectedListId = null),
        ),
      ) : AppBar(
        title: Text(taskList.title),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(listId),
        child: const Icon(Icons.add),
      ),
      body: tasks.isEmpty
          ? const Center(child: Text('No tasks yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) => _buildTaskTile(tasks[index]),
            ),
    );
  }

  Widget _buildTaskTile(Task task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: task.isOverdue ? Colors.deepOrange[300] : null,
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (value) => _toggleTaskStatus(task),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: task.description.isNotEmpty ? Text(task.description) : null,
        trailing: PopupMenuButton<String>(
          onSelected: (String value) {
            switch (value) {
              case 'edit':
                _showEditTaskDialog(task);
                break;
              case 'move':
                _showMoveTaskDialog(task);
                break;
              case 'delete':
                _deleteTask(task);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'move',
              child: Row(
                children: [Icon(Icons.move_to_inbox), SizedBox(width: 8), Text('Move')],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [Icon(Icons.delete), SizedBox(width: 8), Text('Delete')],
              ),
            ),
          ],
        ),
        onTap: () => _showEditTaskDialog(task),
      ),
    );
  }

  void _toggleTaskStatus(Task task) {
    task.status = task.isCompleted ? 0 : 1;
    DatabaseService.updateTask(task);
    context.read<AppState>().refresh();
  }

  void _deleteTask(Task task) {
    DatabaseService.deleteTask(task.id, task.listId);
    context.read<AppState>().refresh();
  }

  void _deleteTaskList(int listId) {
    DatabaseService.deleteTaskList(listId);
    if (_selectedListId == listId) {
      _selectedListId = null;
    }
    context.read<AppState>().refresh();
  }

  void _showAddTaskListDialog() {
    showDialog(
      context: context,
      builder: (context) => AddTaskListDialog(
        onAdd: (title) {
          DatabaseService.addTaskList(title);
          context.read<AppState>().refresh();
        },
      ),
    );
  }

  void _showAddTaskDialog(int listId) {
    showDialog(
      context: context,
      builder: (context) => AddTaskDialog(
        listId: listId,
        onAdd: (task) {
          DatabaseService.addTask(task);
          context.read<AppState>().refresh();
        },
      ),
    );
  }

  void _showEditTaskDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => EditTaskDialog(
        task: task,
        onSave: (updatedTask) {
          DatabaseService.updateTask(updatedTask);
          context.read<AppState>().refresh();
        },
        onDelete: () {
          DatabaseService.deleteTask(task.id, task.listId);
          context.read<AppState>().refresh();
        },
      ),
    );
  }

  void _showMoveTaskDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => MoveTaskDialog(
        task: task,
        availableLists: DatabaseService.taskLists.values
            .where((list) => list.id != task.listId)
            .toList(),
        onMove: (targetListId) {
          DatabaseService.moveTask(task.id, task.listId, targetListId);
          context.read<AppState>().refresh();
        },
      ),
    );
  }
}

class TaskListDetailPage extends StatelessWidget {
  final TaskList taskList;

  const TaskListDetailPage({super.key, required this.taskList});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final tasks = taskList.activeTasks;

        return Scaffold(
          appBar: AppBar(
            title: Text(taskList.title),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddTaskDialog(context, taskList.id),
            child: const Icon(Icons.add),
          ),
          body: tasks.isEmpty
              ? const Center(child: Text('No tasks yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) => _buildTaskTile(context, tasks[index]),
                ),
        );
      },
    );
  }

  Widget _buildTaskTile(BuildContext context, Task task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: task.isOverdue ? Colors.deepOrange[300] : null,
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (value) => _toggleTaskStatus(context, task),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: task.description.isNotEmpty ? Text(task.description) : null,
        trailing: PopupMenuButton<String>(
          onSelected: (String value) {
            switch (value) {
              case 'edit':
                _showEditTaskDialog(context, task);
                break;
              case 'move':
                _showMoveTaskDialog(context, task);
                break;
              case 'delete':
                _deleteTask(context, task);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'move',
              child: Row(
                children: [Icon(Icons.move_to_inbox), SizedBox(width: 8), Text('Move')],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [Icon(Icons.delete), SizedBox(width: 8), Text('Delete')],
              ),
            ),
          ],
        ),
        onTap: () => _showEditTaskDialog(context, task),
      ),
    );
  }

  // Add the helper methods here...
  void _toggleTaskStatus(BuildContext context, Task task) {
    task.status = task.isCompleted ? 0 : 1;
    DatabaseService.updateTask(task);
    context.read<AppState>().refresh();
  }

  void _deleteTask(BuildContext context, Task task) {
    DatabaseService.deleteTask(task.id, task.listId);
    context.read<AppState>().refresh();
  }

  void _showAddTaskDialog(BuildContext context, int listId) {
    showDialog(
      context: context,
      builder: (context) => AddTaskDialog(
        listId: listId,
        onAdd: (task) {
          DatabaseService.addTask(task);
          context.read<AppState>().refresh();
        },
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => EditTaskDialog(
        task: task,
        onSave: (updatedTask) {
          DatabaseService.updateTask(updatedTask);
          context.read<AppState>().refresh();
        },
        onDelete: () {
          DatabaseService.deleteTask(task.id, task.listId);
          context.read<AppState>().refresh();
        },
      ),
    );
  }

  void _showMoveTaskDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => MoveTaskDialog(
        task: task,
        availableLists: DatabaseService.taskLists.values
            .where((list) => list.id != task.listId)
            .toList(),
        onMove: (targetListId) {
          DatabaseService.moveTask(task.id, task.listId, targetListId);
          context.read<AppState>().refresh();
        },
      ),
    );
  }
}


// ========================== Dialogs ==========================

class AddTaskListDialog extends StatefulWidget {
  final Function(String) onAdd;

  const AddTaskListDialog({super.key, required this.onAdd});

  @override
  State<AddTaskListDialog> createState() => _AddTaskListDialogState();
}

class _AddTaskListDialogState extends State<AddTaskListDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Task List'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'List Title',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              widget.onAdd(_controller.text.trim());
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class AddTaskDialog extends StatefulWidget {
  final int listId;
  final Function(Task) onAdd;

  const AddTaskDialog({super.key, required this.listId, required this.onAdd});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Task Title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildDateTimeSelector(
              'Start',
              _startDate,
              _startTime,
              (date) => setState(() => _startDate = date),
              (time) => setState(() => _startTime = time),
            ),
            const SizedBox(height: 16),
            _buildDateTimeSelector(
              'End',
              _endDate,
              _endTime,
              (date) => setState(() => _endDate = date),
              (time) => setState(() => _endTime = time),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _addTask,
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildDateTimeSelector(
    String label,
    DateTime date,
    TimeOfDay time,
    Function(DateTime) onDateChanged,
    Function(TimeOfDay) onTimeChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label Time', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) onDateChanged(picked);
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(DateFormat('MMM d, yyyy').format(date)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: time,
                  );
                  if (picked != null) onTimeChanged(picked);
                },
                icon: const Icon(Icons.access_time),
                label: Text(time.format(context)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _addTask() {
    if (_titleController.text.trim().isEmpty) return;

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    final task = Task(
      listId: widget.listId,
      id: 0,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      startTime: startDateTime,
      endTime: endDateTime,
    );

    widget.onAdd(task);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class EditTaskDialog extends StatefulWidget {
  final Task task;
  final Function(Task) onSave;
  final VoidCallback onDelete;

  const EditTaskDialog({
    super.key,
    required this.task,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description);
    _startDate = widget.task.startTime;
    _startTime = TimeOfDay.fromDateTime(widget.task.startTime);
    _endDate = widget.task.endTime;
    _endTime = TimeOfDay.fromDateTime(widget.task.endTime);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Task Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildDateTimeSelector(
              'Start',
              _startDate,
              _startTime,
              (date) => setState(() => _startDate = date),
              (time) => setState(() => _startTime = time),
            ),
            const SizedBox(height: 16),
            _buildDateTimeSelector(
              'End',
              _endDate,
              _endTime,
              (date) => setState(() => _endDate = date),
              (time) => setState(() => _endTime = time),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onDelete();
            Navigator.pop(context);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveTask,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildDateTimeSelector(
    String label,
    DateTime date,
    TimeOfDay time,
    Function(DateTime) onDateChanged,
    Function(TimeOfDay) onTimeChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label Time', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) onDateChanged(picked);
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(DateFormat('MMM d, yyyy').format(date)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: time,
                  );
                  if (picked != null) onTimeChanged(picked);
                },
                icon: const Icon(Icons.access_time),
                label: Text(time.format(context)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _saveTask() {
    if (_titleController.text.trim().isEmpty) return;

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    final updatedTask = Task(
      listId: widget.task.listId,
      id: widget.task.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      startTime: startDateTime,
      endTime: endDateTime,
      status: widget.task.status,
    );

    widget.onSave(updatedTask);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class MoveTaskDialog extends StatelessWidget {
  final Task task;
  final List<TaskList> availableLists;
  final Function(int) onMove;

  const MoveTaskDialog({
    super.key,
    required this.task,
    required this.availableLists,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Move "${task.title}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: availableLists.map((list) =>
          ListTile(
            title: Text(list.title),
            onTap: () {
              onMove(list.id);
              Navigator.pop(context);
            },
          ),
        ).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class TaskDetailsDialog extends StatelessWidget {
  final Task task;
  final VoidCallback onEdit;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;

  const TaskDetailsDialog({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onToggleComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.description.isNotEmpty) ...[
            const Text(
              'Description:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(task.description),
            const SizedBox(height: 16),
          ],
          const Text(
            'Time:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('MMM d, yyyy').format(task.startTime)}',
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            '${DateFormat.jm().format(task.startTime)} - ${DateFormat.jm().format(task.endTime)}',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                task.isCompleted
                    ? Icons.check_circle
                    : task.isOverdue
                        ? Icons.warning
                        : Icons.radio_button_unchecked,
                color: task.isCompleted
                    ? Colors.green
                    : task.isOverdue
                        ? Colors.red
                        : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                task.isCompleted
                    ? 'Completed'
                    : task.isOverdue
                        ? 'Overdue'
                        : 'Pending',
                style: TextStyle(
                  color: task.isCompleted
                      ? Colors.green
                      : task.isOverdue
                          ? Colors.red
                          : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: onToggleComplete,
          icon: Icon(task.isCompleted ? Icons.undo : Icons.check),
          label: Text(task.isCompleted ? 'Mark Incomplete' : 'Mark Complete'),
        ),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit),
          label: const Text('Edit'),
        ),
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _showDeleteConfirmation(context);
          },
          icon: const Icon(Icons.delete, color: Colors.red),
          label: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ========================== Calendar Page ==========================

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        Widget page;
        switch (_selectedIndex) {
          case 0:
            page = Consumer<AppState>(
              builder: (context, appState, child) {
                return HourlyView(tasks: _getAllTasks());
              }
            );
            break;
          case 1:
            page = Consumer<AppState>(
              builder: (context, appState, child) {
                return WeeklyView(tasks: _getAllTasks());
              }
            );
            break;
          case 2:
            page = Consumer<AppState>(
              builder: (context, appState, child) {
                return MonthlyView(tasks: _getAllTasks());
              }
            );
            break;
          default:
            throw UnimplementedError('No page for $_selectedIndex');
        }

        if (isMobile) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Calendar'),
              bottom: TabBar(
                controller: TabController(
                  length: 3,
                  vsync: Scaffold.of(context),
                  initialIndex: _selectedIndex,
                ),
                onTap: (index) => setState(() => _selectedIndex = index),
                tabs: const [
                  Tab(text: 'Day', icon: Icon(Icons.calendar_view_day)),
                  Tab(text: 'Week', icon: Icon(Icons.calendar_view_week)),
                  Tab(text: 'Month', icon: Icon(Icons.calendar_view_month)),
                ],
              ),
            ),
            body: page,
          );
        }

        return Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.calendar_view_day),
                  label: Text('Day'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.calendar_view_week),
                  label: Text('Week'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.calendar_view_month),
                  label: Text('Month'),
                ),
              ],
            ),
            Expanded(child: page),
          ],
        );
      },
    );
  }

  List<Task> _getAllTasks() {
    return DatabaseService.taskLists.values
        .expand((list) => list.activeTasks)
        .toList();
  }
}

// ========================== Calendar Views ==========================

class HourlyView extends StatefulWidget {
  final List<Task> tasks;
  const HourlyView({super.key, required this.tasks});

  @override
  State<HourlyView> createState() => _HourlyViewState();
}

class _HourlyViewState extends State<HourlyView> {
  DateTime _selectedDate = DateTime.now();
  // CHANGE 1: Two separate ScrollControllers
  late ScrollController _taskScrollController;
  late ScrollController _timeScrollController;

  // Flag to prevent feedback loops when programmatically scrolling
  bool _isProgrammaticScroll = false;

  static const double _pixelsPerHour = 60.0;
  // ... (other constants remain the same)
  static const double _hourLabelWidth = 60.0;
  static const double _timeColumnHeaderHeight = 8.0;
  static const double _taskMinHeight = 20.0;
  static const double _taskColumnGapFactor = 0.05;
  static const double _currentTimeIndicatorLineHeight = 2.0;
  static const double _currentTimeIndicatorCircleRadius = 4.0;


  @override
  void initState() {
    super.initState();
    // CHANGE 2: Initialize both controllers
    _taskScrollController = ScrollController();
    _timeScrollController = ScrollController();

    // CHANGE 3: Add listener to the primary scroller (task area)
    _taskScrollController.addListener(_syncScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentHour(animate: true);
    });
  }

  // CHANGE 4: Scroll synchronization logic
  void _syncScroll() {
    if (!_isProgrammaticScroll && // Prevent sync if we are programmatically scrolling
        _timeScrollController.hasClients &&
        _taskScrollController.hasClients &&
        _timeScrollController.offset != _taskScrollController.offset) {
      _isProgrammaticScroll = true; // Set flag
      _timeScrollController.jumpTo(_taskScrollController.offset);
      // Use a short delay to reset the flag, allowing the jumpTo to complete
      Future.delayed(const Duration(milliseconds: 50), () { // Adjusted delay
         _isProgrammaticScroll = false; // Reset flag
      });
    }
  }

  void _scrollToCurrentHour({bool animate = false}) {
    if (_isToday(_selectedDate) && _taskScrollController.hasClients && _timeScrollController.hasClients) {
      final currentHour = DateTime.now().hour;
      final offset = currentHour * _pixelsPerHour;
      print("Scrolling to hour: $currentHour, offset: $offset");

      _isProgrammaticScroll = true; // Set flag

      if (animate) {
        Future.wait([
          _taskScrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          ),
          _timeScrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          ),
        ]).whenComplete(() {
            _isProgrammaticScroll = false; // Reset flag
        });
      } else {
        _taskScrollController.jumpTo(offset);
        _timeScrollController.jumpTo(offset);
        // Ensure the flag is reset after jumpTo as well
        Future.delayed(const Duration(milliseconds: 50), () {
            _isProgrammaticScroll = false; // Reset flag
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final dayTasks = widget.tasks.where((task) {
          final taskDate = task.startTime;
          return taskDate.year == _selectedDate.year &&
              taskDate.month == _selectedDate.month &&
              taskDate.day == _selectedDate.day;
        }).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        return Scaffold(
          appBar: AppBar(
            // ... (AppBar code is fine)
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _selectedDate =
                      _selectedDate.subtract(const Duration(days: 1))),
                ),
                GestureDetector(
                  onTap: _selectDate,
                  child: Text(
                    DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() =>
                      _selectedDate = _selectedDate.add(const Duration(days: 1))),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.today),
                onPressed: () {
                  final now = DateTime.now();
                  setState(() => _selectedDate = now);
                  _scrollToCurrentHour(animate: true);
                },
                tooltip: 'Go to today',
              ),
            ],
          ),
          // No ScrollConfiguration needed for this approach
          body: Row(
            children: [
              // Time labels column
              SizedBox(
                width: _hourLabelWidth,
                child: Column(
                  children: [
                    const SizedBox(height: _timeColumnHeaderHeight),
                    Expanded(
                      // CHANGE: Wrap with ScrollConfiguration to hide scrollbar for this specific SingleChildScrollView
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          scrollbars: false, // This explicitly tells it not to build scrollbars
                        ),
                        child: SingleChildScrollView(
                          controller: _timeScrollController,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            children: List.generate(24, (index) {
                              return Container(
                                height: _pixelsPerHour,
                                alignment: Alignment.topCenter,
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${index.toString().padLeft(2, '0')}:00',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, color: Colors.grey[300]),
              // Tasks column
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: _timeColumnHeaderHeight),
                    Expanded(
                      child: SingleChildScrollView(
                        // CHANGE 6: Assign _taskScrollController
                        controller: _taskScrollController, // This is the one the user scrolls
                        child: Container(
                          height: 24 * _pixelsPerHour,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double taskAreaWidth = constraints.maxWidth;
                              return Stack(
                                children: [
                                  ..._buildHourGridLines(context),
                                  ..._buildTaskBlocks(dayTasks, taskAreaWidth),
                                  if (_isToday(_selectedDate))
                                    _buildCurrentTimeIndicator(),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ... (_buildHourGridLines, _buildTaskBlocks, _tasksOverlap, _buildTaskBlock, _getTaskColor, _getTaskBorderColor, _buildCurrentTimeIndicator, _isToday are fine)
  // Make sure _getTaskColor and _getTaskBorderColor use task.color if available
   List<Widget> _buildHourGridLines(BuildContext context) {
    return List.generate(24, (index) {
      final isCurrentHour = DateTime.now().hour == index && _isToday(_selectedDate);
      return Positioned(
        top: index * _pixelsPerHour,
        left: 0,
        right: 0,
        height: _pixelsPerHour,
        child: Container(
          decoration: BoxDecoration(
            color: isCurrentHour
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : null,
            border: Border(
              top: BorderSide(
                color: Colors.grey[200]!,
                width: 0.5,
              ),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildTaskBlocks(List<Task> tasks, double availableWidth) {
    if (tasks.isEmpty) return [];

    final List<List<Task>> taskColumns = [];
    for (final task in tasks) {
      bool addedToColumn = false;
      for (final column in taskColumns) {
        if (!column.any((columnTask) => _tasksOverlap(task, columnTask))) {
          column.add(task);
          addedToColumn = true;
          break;
        }
      }
      if (!addedToColumn) {
        taskColumns.add([task]);
      }
    }

    final List<Widget> taskWidgets = [];
    final totalColumns = taskColumns.length;
    if (totalColumns == 0) return [];

    for (int columnIndex = 0; columnIndex < taskColumns.length; columnIndex++) {
      final column = taskColumns[columnIndex];
      for (final task in column) {
        taskWidgets.add(_buildTaskBlock(
          task,
          totalColumns,
          columnIndex,
          availableWidth,
        ));
      }
    }
    return taskWidgets;
  }

  bool _tasksOverlap(Task task1, Task task2) {
    return task1.startTime.isBefore(task2.endTime) &&
        task2.startTime.isBefore(task1.endTime);
  }

  Widget _buildTaskBlock(
      Task task, int totalColumns, int columnIndex, double availableWidth) {
    final startHour = task.startTime.hour;
    final startMinute = task.startTime.minute;
    final endHour = task.endTime.hour;
    final endMinute = task.endTime.minute;

    final startPosition = (startHour * _pixelsPerHour) + (startMinute / 60.0 * _pixelsPerHour);
    final endPosition = (endHour * _pixelsPerHour) + (endMinute / 60.0 * _pixelsPerHour);
    final durationInPixels = endPosition - startPosition;

    final double columnWidthFull = availableWidth / totalColumns;
    final double gapPerSide = columnWidthFull * _taskColumnGapFactor / 2.0;
    final double taskActualWidth = columnWidthFull - (gapPerSide * 2.0);
    final double taskLeftOffset = (columnIndex * columnWidthFull) + gapPerSide;

    return Positioned(
      top: startPosition.toDouble(),
      left: taskLeftOffset,
      width: taskActualWidth,
      height: max(durationInPixels, _taskMinHeight),
      child: GestureDetector(
        onTap: () => _showTaskDetails(task),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: _getTaskColor(task),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _getTaskBorderColor(task),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                task.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (durationInPixels > 30)
                Text(
                  '${DateFormat.jm().format(task.startTime)} - ${DateFormat.jm().format(task.endTime)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (task.description.isNotEmpty && durationInPixels > 50)
                Expanded(
                  child: Text(
                    task.description,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                    maxLines: (durationInPixels / 18).floor().clamp(1,3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTaskColor(Task task) {
    if (task.isCompleted) {
      return Colors.green.withOpacity(0.8);
    } else if (task.isOverdue) {
      return Colors.red.withOpacity(0.8);
    } else {
      return Theme.of(context).colorScheme.primary.withOpacity(0.8);
    }
  }

  Color _getTaskBorderColor(Task task) {
    if (task.isCompleted) {
      return Colors.green;
    } else if (task.isOverdue) {
      return Colors.red;
    } else {
      return Theme.of(context).colorScheme.primary;
    }
  }

 Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final currentMinuteOfTheDay = (now.hour * 60) + now.minute;
    final currentPosition = currentMinuteOfTheDay / 60.0 * _pixelsPerHour;

    return Positioned(
      top: currentPosition.toDouble() - (_currentTimeIndicatorLineHeight / 2),
      left: 0,
      right: 0,
      height: _currentTimeIndicatorCircleRadius * 2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: _currentTimeIndicatorCircleRadius * 2,
            height: _currentTimeIndicatorCircleRadius * 2,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: _currentTimeIndicatorLineHeight,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // --- Dialog and DB methods ---
  // Ensure these use `mounted` checks and `context.read<AppState>().refresh()`
  // and pop dialogs correctly as in previous good versions.

  void _showTaskDetails(Task task) {
    showDialog(
      context: context,
      builder: (dialogContext) => TaskDetailsDialog(
        task: task,
        onEdit: () {
          Navigator.pop(dialogContext);
          _showEditTaskDialog(task);
        },
        onToggleComplete: () {
          _toggleTaskStatus(task); // async
          Navigator.pop(dialogContext);
        },
        onDelete: () {
          _deleteTask(task); // async
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  void _showEditTaskDialog(Task task) {
    showDialog(
      context: context,
      builder: (dialogContext) => EditTaskDialog(
        task: task,
        onSave: (updatedTask) {
          // Navigator.pop(dialogContext); // 先关编辑框
          DatabaseService.updateTask(updatedTask);
          // ✅ 触发 Provider 刷新（修复：编辑后小时视图与日历不同步/空白）
          context.read<AppState>().refresh();
        },
        onDelete: () {
          // Navigator.pop(dialogContext); // 先关编辑框
          DatabaseService.deleteTask(task.id, task.listId);
          // ✅ 删除后刷新
          context.read<AppState>().refresh();
        },
      ),
    );
  }

  void _toggleTaskStatus(Task task) {
    final updatedTask = Task(
      id: task.id,
      listId: task.listId,
      title: task.title,
      description: task.description,
      startTime: task.startTime,
      endTime: task.endTime,
      status: task.isCompleted ? 0 : 1,
    );
    DatabaseService.updateTask(updatedTask);
    // ✅ 切换状态后刷新（修复：小时视图不更新）
    context.read<AppState>().refresh();
  }

  // HourlyView 内部
  void _deleteTask(Task task) {
    DatabaseService.deleteTask(task.id, task.listId);
    // ✅ 删除后刷新（确保小时视图/周视图/月视图一致）
    context.read<AppState>().refresh();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      // Optionally, re-evaluate if you need to scroll to top/current hour on date change
      // _scrollToCurrentHour(animate: false); // Example: if you want to scroll on date change
    }
  }

  @override
  void dispose() {
    // CHANGE 7: Remove listener and dispose both controllers
    _taskScrollController.removeListener(_syncScroll);
    _taskScrollController.dispose();
    _timeScrollController.dispose();
    super.dispose();
  }
}

class WeeklyView extends StatefulWidget {
  final List<Task> tasks;
  const WeeklyView({super.key, required this.tasks});

  @override
  State<WeeklyView> createState() => _WeeklyViewState();
}

class _WeeklyViewState extends State<WeeklyView> {
  DateTime _currentWeek = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final startOfWeek = _currentWeek.subtract(Duration(days: _currentWeek.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() =>
                      _currentWeek = _currentWeek.subtract(const Duration(days: 7))),
                ),
                Text(
                  '${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d, yyyy').format(endOfWeek)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() =>
                      _currentWeek = _currentWeek.add(const Duration(days: 7))),
                ),
              ],
            ),
          ),
          body: Row(
            children: List.generate(7, (index) {
              final day = startOfWeek.add(Duration(days: index));
              final dayTasks = widget.tasks.where((task) {
                final taskDate = task.startTime;
                return taskDate.year == day.year &&
                       taskDate.month == day.month &&
                       taskDate.day == day.day;
              }).toList();

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: DateTime.now().day == day.day &&
                               DateTime.now().month == day.month &&
                               DateTime.now().year == day.year
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                            : null,
                        border: Border(
                          right: index < 6
                              ? BorderSide(color: Colors.grey.shade300)
                              : BorderSide.none,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('EEE').format(day),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(DateFormat('d').format(day)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            right: index < 6
                                ? BorderSide(color: Colors.grey.shade300)
                                : BorderSide.none,
                          ),
                        ),
                        child: ListView.builder(
                          itemCount: dayTasks.length,
                          itemBuilder: (context, taskIndex) {
                            final task = dayTasks[taskIndex];
                            return GestureDetector(
                              onTap: () => _showTaskDetails(task),
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: task.isCompleted
                                      ? Colors.green.withOpacity(0.7)
                                      : task.isOverdue
                                          ? Colors.red.withOpacity(0.7)
                                          : Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  task.title,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      }
    );

  }

  void _showTaskDetails(Task task) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailsDialog(
        task: task,
        onEdit: () {
          Navigator.pop(context);
          _showEditTaskDialog(task);
        },
        onToggleComplete: () {
          _toggleTaskStatus(task);
          Navigator.pop(context);
        },
        onDelete: () {
          _deleteTask(task);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditTaskDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => EditTaskDialog(
        task: task,
        onSave: (updatedTask) {
          DatabaseService.updateTask(updatedTask);
          context.read<AppState>().refresh();
        },
        onDelete: () {
          DatabaseService.deleteTask(task.id, task.listId);
          context.read<AppState>().refresh();
        },
      ),
    );
  }

  void _toggleTaskStatus(Task task) {
    task.status = task.isCompleted ? 0 : 1;
    DatabaseService.updateTask(task);
    context.read<AppState>().refresh();
  }

  void _deleteTask(Task task) {
    DatabaseService.deleteTask(task.id, task.listId);
    context.read<AppState>().refresh();
  }
}

class MonthlyView extends StatefulWidget {
  final List<Task> tasks;

  const MonthlyView({super.key, required this.tasks});

  @override
  State<MonthlyView> createState() => _MonthlyViewState();
}

class _MonthlyViewState extends State<MonthlyView> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          body: Column(
            children: [
              TableCalendar<Task>(
                firstDay: DateTime.utc(2010, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                eventLoader: _getTasksForDay,
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  setState(() => _focusedDay = focusedDay);
                },
              ),
              if (_selectedDay != null) ...[
                const Divider(),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _selectedDay != null
                              ? 'Tasks for ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!)}'
                              : 'Select a day to view tasks',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _selectedDay != null
                            ? ListView.builder(
                                itemCount: _getTasksForDay(_selectedDay!).length,
                                itemBuilder: (context, index) {
                                  final task = _getTasksForDay(_selectedDay!)[index];
                                  return ListTile(
                                    leading: Icon(
                                      task.isCompleted
                                          ? Icons.check_circle
                                          : task.isOverdue
                                              ? Icons.warning
                                              : Icons.radio_button_unchecked,
                                      color: task.isCompleted
                                          ? Colors.green
                                          : task.isOverdue
                                              ? Colors.red
                                              : Colors.grey,
                                    ),
                                    title: Text(
                                      task.title,
                                      style: TextStyle(
                                        decoration: task.isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${DateFormat.jm().format(task.startTime)} - ${DateFormat.jm().format(task.endTime)}',
                                    ),
                                    onTap: () => _showTaskDetails(task),
                                  );
                                },
                              )
                            : const Center(
                                child: Text('Select a day to view tasks'),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }
    );
  }

  List<Task> _getTasksForDay(DateTime day) {
    return widget.tasks.where((task) {
      final taskDate = task.startTime;
      return taskDate.year == day.year &&
             taskDate.month == day.month &&
             taskDate.day == day.day;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  void _showTaskDetails(Task task) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailsDialog(
        task: task,
        onEdit: () {
          Navigator.pop(context);
          _showEditTaskDialog(task);
        },
        onToggleComplete: () {
          _toggleTaskStatus(task);
          Navigator.pop(context);
        },
        onDelete: () {
          _deleteTask(task);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditTaskDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => EditTaskDialog(
        task: task,
        onSave: (updatedTask) {
          DatabaseService.updateTask(updatedTask);
          context.read<AppState>().refresh();
        },
        onDelete: () {
          DatabaseService.deleteTask(task.id, task.listId);
          context.read<AppState>().refresh();
        },
      ),
    );
  }

  void _toggleTaskStatus(Task task) {
    task.status = task.isCompleted ? 0 : 1;
    DatabaseService.updateTask(task);
    context.read<AppState>().refresh();
  }

  void _deleteTask(Task task) {
    DatabaseService.deleteTask(task.id, task.listId);
    context.read<AppState>().refresh();
  }
}

// ========================== Settings Page ==========================

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkModeEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Coming soon'),
            value: _darkModeEnabled,
            onChanged: null, // Disabled for now
          ),
          ListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Configure notification settings'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Implement notification settings
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('About SCOM'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'SCOM',
                applicationVersion: '0.1.0',
                applicationLegalese: '©2025 SCOM Team',
                children: const [
                  Text('A simple and efficient task management application.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}