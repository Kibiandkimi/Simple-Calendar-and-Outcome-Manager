
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'database_bindings_generated.dart';

const String _libName = 'database';

final _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

final DatabaseBindings _bindings = DatabaseBindings(_dylib);

final initDatabaseC = _bindings.Dart_init;
final preGetTaskListC = _bindings.Dart_get_list_pre;
final getTaskListC =  _bindings.Dart_get_list;
final preGetTaskC = _bindings.Dart_get_task_pre;
final getTaskC =  _bindings.Dart_get_task;
final addTaskListC =  _bindings.Dart_create_tasklist;
final addTaskC =  _bindings.Dart_create_task;
final updateTaskC =  _bindings.Dart_update_task;
final deleteTaskC =  _bindings.Dart_delete_task;
final deleteTaskListC =  _bindings.Dart_delete_tasklist;

@Deprecated('No need to query num after init')
final queryTaskListNum =  _bindings.Dart_query_tasklist_num;

@Deprecated('Use Dart_get_list')
final queryTaskListId = _bindings.Dart_query_tasklist_id;

@Deprecated('Use Dart_get_list')
final queryTaskListName =  _bindings.Dart_query_tasklist_name;

@Deprecated('No need to query task num after init.')
final queryTaskNum =  _bindings.Dart_query_task_num;

@Deprecated('Use Dart_update_task')
final updateStatTaskC =  _bindings.Dart_update_task_stat;

@Deprecated('Use Dart_update_task')
final moveTaskC =  _bindings.Dart_move_task;