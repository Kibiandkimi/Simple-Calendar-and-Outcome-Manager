import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart';

DynamicLibrary _lib = Platform.isLinux ?
  DynamicLibrary.open('database.so') :
  DynamicLibrary.open('database.dll');

final initDatabaseC = _lib
    .lookupFunction<Int32 Function(), int Function()>
  ('Dart_init');

final queryTaskListNum = _lib
    .lookupFunction<Int32 Function(), int Function()>
  ('Dart_query_tasklist_num');

final queryTaskNum = _lib
    .lookupFunction<Int32 Function(Int32 listId), int Function(int listID)>
  ('Dart_query_task_num');

final getTaskC = _lib
    .lookupFunction<TaskC Function(Int32 listId, Int32 taskId), TaskC Function(int listId, int taskId)>
  ('Dart_get_task');

final addTaskC = _lib
    .lookupFunction<Int32 Function(Int32, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32), int Function(int, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int)>
  ('Dart_create_task');

final updateStatTaskC = _lib
    .lookupFunction<Int32 Function(Int32, Int32, Int32), int Function(int, int, int)>
  ('Dart_update_task_stat');

final testDll = _lib
    .lookupFunction<Int32 Function(), int Function()>
  ('Dart_test');

final test1 = _lib
    .lookupFunction<Int32 Function(), int Function()>
  ('Dart_test_f1');

final test2 = _lib
    .lookupFunction<Void Function(), void Function()>
  ('Dart_test_f2');

final test3 = _lib
    .lookupFunction<Int32 Function(Int32 val), int Function(int val)>
  ('Dart_test_f3');

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: "SCOM",
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var todoList = <TodoList>[];
  var initialized = false;
  var addTaskPage = false;

  void init() {
    if (!initialized) {
      initDatabaseC();
      // print("${queryTaskNum(0)}");
      var listNum = queryTaskListNum();
      print("listNum: $listNum");
      // print("${queryTaskNum(100)}");
      for (var i = 0; i < listNum; i++) {
        var list = TodoList();
        list.id = i;
        var taskNum = queryTaskNum(i);
        // print("1");
        print("List$i, taskNum: $taskNum");
        for (var j = 0; j < taskNum; j++) {
          var taskC = getTaskC(i, j);
          print(1);
          var task = changeTaskCtoTask(taskC);
          print(2);
          list.taskList.add(task);
          print(3);
        }
        todoList.add(list);
      }
      initialized = true;
      // notifyListeners();
    }
  }

  void intoAddTaskPage() {
    addTaskPage = true;
    notifyListeners();
  }

  void addTask(int listIndex, String title, String description, DateTime startTime, DateTime endTime, int status) {
    var newTask = Task(listIndex, 0, title, description, startTime, endTime, status);
    var newTaskId = addTaskC(listIndex, newTask.title.toNativeUtf8(), newTask.description.toNativeUtf8(), newTask.startTime.toIso8601String().toNativeUtf8(), newTask.endTime.toIso8601String().toNativeUtf8(), newTask.stat);
    print("$newTaskId");
    print("listIndex: $listIndex, title: $title, description: $description, startTime: $startTime, endTime: $endTime, status: $status");
    newTask.id = newTaskId;
    todoList[listIndex].taskList.add(newTask);
    notifyListeners();
  }

  void updateTaskStatus(int listIndex, int taskIndex, int status) {
    print("update list$listIndex task$taskIndex stat:$status");
    updateStatTaskC(listIndex, taskIndex, status);
    todoList[listIndex].taskList[taskIndex].stat = status;
    notifyListeners();
  }

  void changeStatus() {
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;

    switch (selectedIndex) {
      case 0:
        page = TodoPage();
        break;
      case 1:
        page = CalendarPage();
        break;
      case 2:
        page = SettingPage();
        break;
      default :
        throw UnimplementedError('no widget for $selectedIndex');
    }

    IconData calendarIcon = Icons.calendar_month;

    var appState = context.watch<MyAppState>();

    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        body: Row (
          children: [
            SafeArea(
              child:
                NavigationRail(
                  extended: constraints.maxWidth >= 800,
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(Icons.checklist),
                      label: Text('SCOM'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(calendarIcon),
                      label: Text('Calendar'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value){
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
            ),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child : page,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class TodoPage extends StatefulWidget {
  @override
  State<TodoPage> createState() => _TodoPageState();
}

final class TaskC extends Struct {
  @Int32()
  external int listId, id;

  external Pointer<Utf8> title, description, startTime, endTime;

  @Int32()
  external int status;
}

class Task {
  var listId = 0;
  var id = 0;
  var title = 'Task 1';
  var description = 'Task description.';
  var startTime = DateTime.now();
  var endTime = DateTime.now();
  var stat = 0;

  Task(this.listId, this.id, this.title, this.description, this.startTime, this.endTime, this.stat);
}

Task changeTaskCtoTask(TaskC task) {
  return Task(task.listId, task.id, task.title.toDartString(), task.description.toDartString(), DateTime.parse(task.startTime.toDartString()), DateTime.parse(task.endTime.toDartString()), task.status);
}

// TaskC changeTaskCtoTask(Task task) {
//   return TaskC(task.title.toNativeUtf8(), task.description.toNativeUtf8(), task.startTime.toIso8601String().toNativeUtf8(), task.endTime.toIso8601String().toNativeUtf8(), task.stat);
// }

int getTodoListNum() {
  return 0;
}

int getTask(int listId) {
  return 0;
}

class TodoList {
  var id = 0;
  var taskList = <Task>[];
}

class _TodoPageState extends State<TodoPage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    appState.init();

    Widget page;

    // print("${appState.todoList}");

    var destination = appState.todoList.map((list) => NavigationRailDestination(
        icon: Icon(Icons.star),
        label: Text("Todo List ${list.id + 1}"),
    )).toList();

    // print("$destination");

    page = GeneratorTodoPage(listIndex: selectedIndex);

    // var destination = todoList[selectedIndex].taskList.map((task) => )

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child:
            NavigationRail(
              backgroundColor: Color.lerp(Colors.white, Theme.of(context).colorScheme.primaryContainer, 0.5),
              extended: true,
              destinations: destination,
              selectedIndex: selectedIndex,
              onDestinationSelected: (value){
                setState(() {
                  selectedIndex = value;
                });
              },
            ),
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              child : page,
            ),
          ),
        ],
      ),
    );
  }
}

class GeneratorTodoPage extends StatefulWidget {
  GeneratorTodoPage({
    super.key,
    required this.listIndex,
    // required this.pop,
  });

  final int listIndex;
  // final bool pop;

  @override
  State<GeneratorTodoPage> createState() => _GeneratorTodoPageState();
}

class _GeneratorTodoPageState extends State<GeneratorTodoPage> {
  @override build(BuildContext context) {
    // widget.list.taskList.add(Task(1, 'eltiT', 'Todo2', DateTime.now(), DateTime.now(), 1));
    var appState = context.watch<MyAppState>();

    // var addTaskPage = GeneratorAddTaskPage(child: Text('???'));

    // if (widget.pop) {
    //   return addTaskPage;
    // }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          setState(() {
            Navigator.of(context).push(
              DismissibleDialog<void>()
            );
            appState.addTask(widget.listIndex, 'eltiT', 'Todo2', DateTime.now(), DateTime.now(), 1);
          });
        },
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 5),
            Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  SizedBox(width: 10),
                  Icon(Icons.star),
                  SizedBox(width: 10),
                  Text("Todo List ${widget.listIndex + 1}"),
                ],
              ),
            ),
            SizedBox(height: 5),
            Expanded(
              child: Container(
                color: Colors.white,
                child: Row(
                  children: [
                    SizedBox(width: 15),
                    Expanded(
                      child: ListView(
                        children: appState.todoList[widget.listIndex].taskList.map((task) => Container(
                          // color: task.stat != 2 ? Theme.of(context).colorScheme.primaryContainer : Colors.deepOrange[300],
                          margin: EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            color: task.stat != 2 ? Theme.of(context).colorScheme.primaryContainer : Colors.deepOrange[300],
                            border: Border.all(
                              color: Colors.black,
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: (){
                                  setState((){
                                    task.stat = task.stat == 1 ? 0 : 1;
                                    print('changed task${task.id}');
                                    appState.updateTaskStatus(widget.listIndex, task.id, task.stat);
                                  });
                                },
                                icon: Icon(task.stat == 1 ? Icons.task_alt : Icons.circle),
                                label: SizedBox(),
                              ),
                              SizedBox(width: 10),
                              Text('Task ${task.title}'),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                    SizedBox(width: 15),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class DismissibleDialog<T> extends PopupRoute<T> {
  @override
  Color? get barrierColor => Colors.black.withAlpha(0x50);

  // This allows the popup to be dismissed by tapping the scrim or by pressing
  // the escape key on the keyboard.
  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Add Todo Task';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return Center(
      // Provide DefaultTextStyle to ensure that the dialog's text style
      // matches the rest of the text in the app.
      // child: DefaultTextStyle(
      //   style: Theme.of(context).textTheme.bodyMedium!,
      //   // UnconstrainedBox is used to make the dialog size itself
      //   // to fit to the size of the content.
      //   child: UnconstrainedBox(
      //     child: Container(
      //       padding: const EdgeInsets.all(100.0),
      //       decoration: BoxDecoration(
      //         borderRadius: BorderRadius.circular(10),
      //         color: Colors.white,
      //       ),
      //       child: Column(
      //         children: <Widget>[
      //           Text('Dismissible Dialog',
      //               style: Theme.of(context).textTheme.headlineSmall),
      //           const SizedBox(height: 20),
      //           const Text('Tap in the scrim or press escape key to dismiss.'),
      //         ],
      //       ),
      //     ),
      //   ),
      // ),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyMedium!,
        child: Container(
          margin: EdgeInsets.all(40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: Expanded(
            child: Column(
              children: [
                SizedBox(height: 10.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Add Todo Task',
                    style: Theme.of(context).textTheme.headlineLarge),
                  ],
                ),
                SizedBox(height: 10.0),
                Expanded(
                  // padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      SizedBox(width: 10.0),
                      Expanded(
                        // padding: const EdgeInsets.all(8.0),
                        child: Scaffold(
                          body: TextField(
                            decoration: InputDecoration(
                              labelText: 'Task Title',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.0),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// class generatorAddTaskPage extends PopupRoute<void> {
//   @override
//   Color get barrierColor => Colors.black.withOpacity(0.5);
//
//   @override
//   // TODO: implement barrierDismissible
//   bool get barrierDismissible => throw UnimplementedError();
//
//   @override
//   // TODO: implement barrierLabel
//   String? get barrierLabel => throw UnimplementedError();
//
//   @override
//   Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
//     // TODO: implement buildPage
//
//     return Center(
//       child: Container(
//         height: 200,
//         width: 200,
//         color: Colors.white,
//         child: Column(
//           children: [
//             Text('Add Task'),
//             TextField(
//               decoration: InputDecoration(
//                 hintText: 'Task Name',
//               ),
//             ),
//             TextField(
//               decoration: InputDecoration(
//                 hintText: 'Task Description',
//               ),
//             ),
//             ElevatedButton(
//               onPressed: (){
//                 Navigator.of(context).pop();
//               },
//               child: Text('Add Task'),
//             ),
//           ],
//         ),
//       ),
//     );
//
//     throw UnimplementedError();
//   }
//
//   @override
//   // TODO: implement transitionDuration
//   Duration get transitionDuration => throw UnimplementedError();
//
//
// }

// class GeneratorAddTaskHolePage extends PopupMenuEntry<void> {
//   @override
//   Widget build(BuildContext context) {
//     return Text('Add Task');
//   }
//
//   @override
//   State<StatefulWidget> createState() {
//     // TODO: implement createState
//     throw UnimplementedError();
//   }
//
//   @override
//   // TODO: implement height
//   double get height => throw UnimplementedError();
//
//   @override
//   bool represents(void value) {
//     // TODO: implement represents
//     throw UnimplementedError();
//   }
// }

// class GeneratorAddTaskPage extends PopupMenuItem {
//   GeneratorAddTaskPage({required super.child});
//
//   @override
//   Widget build(BuildContext context) {
//     return Text('Add Task');
//   }
// }

class CalendarPage extends StatefulWidget {
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    appState.init();

    // var calendarState = context.watch<CalendarState>();

    Widget page;

    switch (selectedIndex) {
      case 0:
        page = GeneratorHourPage();
        break;
      case 1:
        page = GeneratorWeekPage();
        break;
      case 2:
        page = GeneratorMonthPage();
        break;
      default:
        throw UnimplementedError("No implemented for ${selectedIndex}");
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                backgroundColor: Color.lerp(Colors.white, Theme.of(context).colorScheme.primaryContainer, 0.5),
                extended: constraints.maxWidth >= 600,
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Icons.calendar_view_day),
                    label: Text('Hours'),
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
                selectedIndex: selectedIndex,
                onDestinationSelected: (value){
                  setState((){
                    selectedIndex = value;
                  });
                },
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: page,
              ),
            ),
          ],
        ),
      );
    });

  }
}

class GeneratorHourPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var begin_time = DateTime.now().add(Duration(hours: -1));
    var end_time = begin_time.add(Duration(hours: 12));



    return Row(
      children: [
        SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              Container(
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Text(begin_time.toString()),
              ),
              Container(
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Text(begin_time.add(Duration(hours: 1)).toString()),
              ),
              Container(
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Text(begin_time.add(Duration(hours: 2)).toString()),
              ),
              Container(
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Text(begin_time.add(Duration(hours: 3)).toString()),
              ),
              Container(
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Text(begin_time.add(Duration(hours: 4)).toString()),
              ),
              Container(
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Text(begin_time.add(Duration(hours: 5)).toString()),
              ),
              Container(
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Text(begin_time.add(Duration(hours: 6)).toString()),
              ),
              Container(
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Text(begin_time.add(Duration(hours: 7)).toString()),
              ),
              Container(
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Text(begin_time.add(Duration(hours: 8)).toString()),
              ),
              Container(
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Text(begin_time.add(Duration(hours: 9)).toString()),
              ),
              Container(
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Text(begin_time.add(Duration(hours: 10)).toString()),
              ),
              Container(
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Text(begin_time.add(Duration(hours: 11)).toString()),
              ),
            ],
          ),
        ),
        SizedBox(width: 20),
      ],
    );
  }
}

class CalendarHourPageContainer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            alignment: Alignment.center,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: SizedBox(height: 30, width: 100),
          ),
          Container(
            alignment: Alignment.center,
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Text(""),
          ),
        ],
      ),
    );
  }
}

class GeneratorWeekPage extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold();
  }
}

class GeneratorMonthPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold();
  }
}

class SettingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold();
  }
}

// Failed assertion: line 115 pos 16: 'destinations.length >= 2': is not true.
// must have at least 2 destinations